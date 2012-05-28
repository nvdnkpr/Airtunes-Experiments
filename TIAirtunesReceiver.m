//
//  TIAirtunesReceiver.m
//  TIAirtunesReceiver
//
//  Created by Tom Irving on 01/03/2012.
//  Copyright 2012 Tom Irving. All rights reserved.
//

#import "TIAirtunesReceiver.h"
#import <Security/SecRandom.h>
#import <CommonCrypto/CommonCryptor.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#import "TIAirtunesEncryptor.h"
#import "TIAirtunesAdditions.h"

//==========================================================
// Trying to follow what's described here: 
// http://git.zx2c4.com/Airtunes2/about/
//==========================================================

//==========================================================
#pragma mark - TIAirtunesReceiver -
//==========================================================

NSString * const TIAirtunesReceiverErrorDomain = @"TIAirtunesReceiverErrorDomain";

NSString * const TIAirtunesReceiverCommandAnnounce = @"ANNOUNCE";
NSString * const TIAirtunesReceiverCommandSetup = @"SETUP";
NSString * const TIAirtunesReceiverCommandRecord = @"RECORD";
NSString * const TIAirtunesReceiverCommandFlush = @"FLUSH";
NSString * const TIAirtunesReceiverCommandSetParameter = @"SET_PARAMETER";
NSString * const TIAirtunesReceiverCommandTeardown = @"TEARDOWN";

NSInteger const kTIAirtunesReceiverFramesPerPacket = 352;
NSInteger const kTIAirtunesReceiverDefaultVolume = 0;

@interface TIAirtunesReceiver ()
@property (nonatomic, readonly) NSString * localAddress;
@end

@interface TIAirtunesReceiver (Private)
- (void)annouce;
- (void)record;
- (void)flush;
- (NSInteger)sendCommand:(NSString *)command headers:(NSDictionary *)headers contentType:(NSString *)contentType body:(NSString *)body;
- (void)sendControlPayload:(NSData *)payload;
- (void)processResponse:(NSString *)response;

- (void)openControlStreams;
- (void)closeControlStreams;
- (void)openAudioStream;
- (void)closeAudioStream;
- (void)bufferOutgoingControlData;

- (NSError *)errorForCode:(NSInteger)code;
- (NSDictionary *)dictionaryFromResponse:(NSString *)response;
@end

@implementation TIAirtunesReceiver
@synthesize associatedService;
@synthesize name;
@synthesize address;
@synthesize passwordProtected;
@synthesize connected;
@synthesize disconnectionCallback;
@synthesize audioJackType;

- (id)initWithNetService:(NSNetService *)netService {
	
	if ((self = [super init])){
		
		encryptor = [[TIAirtunesEncryptor alloc] init];
		
		associatedService = [netService retain];
		name = [netService.friendlyName copy];
		
		struct sockaddr_in  * socketAddress = (struct sockaddr_in *)[[associatedService.addresses objectAtIndex:0] bytes];
		address = [[NSString alloc] initWithFormat:@"%s", inet_ntoa(socketAddress->sin_addr)];
		
		password = nil;
		passwordProtected = [[netService.TXTRecordDictionary objectForKey:@"pw"] isEqualToString:@"true"];
		
		RTSPURL = nil;
		session = nil;
		cSeq = 0;
		
		controlInputStream = nil;
		controlOutputStream = nil;
		controlInputBuffer = [[NSMutableData alloc] init];
		controlOutputBuffer = [[NSMutableData alloc] init];
		
		audioServerPort = 6000; // Default
		audioOutputStream = nil;
		audioOuputBuffer = [[NSMutableData alloc] init];
		aSeq = 0;
		aTimestamp = 0;
		
		connectionCallback = nil;
		connected = NO;
		announcing = NO;
		recording = NO;
		
		commandsAwaitingResponse = [[NSMutableDictionary alloc] init];
		
		audioJackType = TIAirtunesReceiverAudioJackTypeUnplugged;
	}
	
	return self;
}

#pragma mark - Communication, yo

- (void)connectWithPassword:(NSString *)aPassword callback:(TIAirtunesReceiverConnectionCallback)callback {
	
	if (!connected){
		
		// Need to actually implement authentication.
		// For now, make sure your Airport express isn't protected.
		
		[password release];
		password = [aPassword copy];
		
		if (callback){
			[connectionCallback release];
			connectionCallback = [callback copy];
		}
		
		if (controlInputStream || controlOutputStream) [self closeControlStreams];
		
		if ([associatedService getInputStream:&controlInputStream outputStream:&controlOutputStream]){
			[self openControlStreams];
		}
	}
}

- (void)announce {
	
	if (!announcing){
		announcing = YES;
		
		NSString * announceBody = [[NSString alloc] initWithFormat:@"v=0\r\n"
								   "o=iTunes %d O IN IP4 %@\r\n"
								   "s=iTunes\r\n"
								   "c=IN IP4 %@\r\n"
								   "t=0 0\r\n"
								   "m=audio 0 RTP/AVP 96\r\n"
								   "a=rtpmap:96 AppleLossless\r\n"
								   "a=fmtp:96 %ld 0 16 40 10 14 2 255 0 0 44100\r\n"
								   "a=rsaaeskey:%@\r\n"
								   "a=aesiv:%@\r\n"
								   "\r\n", 
								   encryptor.sID, self.localAddress, address, kTIAirtunesReceiverFramesPerPacket, 
								   encryptor.encodedAESKey, encryptor.encodedAESIV];
		
		[self sendCommand:TIAirtunesReceiverCommandAnnounce headers:nil contentType:@"application/sdp" body:announceBody];
		[announceBody release];
	}
}

- (void)record {
	
	if (!recording && session){
		recording = YES;
		
		NSDictionary * headers = [[NSDictionary alloc] initWithObjectsAndKeys:@"npt=0-", @"Range", @"seq=0;rtptime=0", @"RTP-Info", nil];
		[self sendCommand:TIAirtunesReceiverCommandRecord headers:headers contentType:nil body:nil];
		[headers release];
	}
}

- (void)flush {
	
	if (recording){
		recording = NO;
		
		NSDictionary * headers = [[NSDictionary alloc] initWithObjectsAndKeys:@"seq=0;rtptime=0", @"RTP-Info", nil];
		[self sendCommand:TIAirtunesReceiverCommandFlush headers:headers contentType:nil body:nil];
		[headers release];
	}
}

- (void)setVolume:(NSInteger)volume {
	
	NSString * volumeBody = [[NSString alloc] initWithFormat:@"volume: %ld", volume];
	[self sendCommand:TIAirtunesReceiverCommandSetParameter headers:nil contentType:@"text/parameters" body:volumeBody];
	[volumeBody release];
}

- (void)playAudioData:(NSData *)data {
	
	if (!connected) [self connectWithPassword:password callback:nil];
	
	// When audio works just playing a small sample, we should be able to get it working with a continuous stream.
	// So you can just keep feeding in data to be played.
	// if (data) [audioOuputBuffer appendData:data];
	
	if (data) [audioOuputBuffer setData:data];
	if (audioOutputStream.hasSpaceAvailable) [self bufferOutgoingAudio];
}

- (void)disconnect {
	
	[self sendCommand:TIAirtunesReceiverCommandTeardown headers:nil contentType:nil body:nil];
	[self closeControlStreams];
	
	[RTSPURL release];
	RTSPURL = nil;
	
	[session release];
	session = nil;
	
	cSeq = 0;
}

- (void)processResponse:(NSString *)response {
	
	NSDictionary * responseDict = [self dictionaryFromResponse:response];
	NSInteger responseCSeq = [[responseDict objectForKey:@"CSeq"] integerValue];
	NSNumber * numberKey = [NSNumber numberWithInteger:responseCSeq];
	NSString * messageType = [commandsAwaitingResponse objectForKey:numberKey];
	
	if ([messageType isEqualToString:TIAirtunesReceiverCommandAnnounce]){
		announcing = NO;
		
		if ([response contains:@"RTSP/1.0 200"]){
			
			NSDictionary * headers = [[NSDictionary alloc] initWithObjectsAndKeys:@"RTP/AVP/TCP;unicast;interleaved=0-1;mode=record", @"Transport", nil];
			[self sendCommand:TIAirtunesReceiverCommandSetup headers:headers contentType:nil body:nil];
			[headers release];
		}
		else
		{
			NSInteger code = ([response contains:@"RTSP/1.0 401"] ? TIAirtunesReceiverErrorCodeUnauthorized :TIAirtunesReceiverErrorCodeReceiverInUse);
			if (connectionCallback) connectionCallback([self errorForCode:code]);
		}
	}
	else if ([messageType isEqualToString:TIAirtunesReceiverCommandSetup]){
		
		NSString * transportString = [responseDict objectForKey:@"Transport"];
		NSRange serverPortRange = [transportString rangeOfString:@"server_port="];
		audioServerPort = [[transportString substringFromIndex:NSMaxRange(serverPortRange)] intValue];
		
		NSString * jackStatus = [responseDict objectForKey:@"Audio-Jack-Status"];
		BOOL jackConnected = !([jackStatus isEqualToString:@"disconnected"]);
		
		audioJackType = TIAirtunesReceiverAudioJackTypeUnplugged;
		if (jackConnected) audioJackType = ([jackStatus contains:@"digital"] ? TIAirtunesReceiverAudioJackTypeDigital : 
											TIAirtunesReceiverAudioJackTypeAnalog);
		
		if (!connected){
			[session release];
			session = [[responseDict objectForKey:@"Session"] copy];
			[self record];
		}
	}
	else if ([messageType isEqualToString:TIAirtunesReceiverCommandRecord]){
		
		aSeq = 0;
		aTimestamp = 0;
		
		if (!connected){
			
			[self setVolume:kTIAirtunesReceiverDefaultVolume];
			[self openAudioStream];
			
			connected = YES;
			if (connectionCallback) connectionCallback(audioJackType == TIAirtunesReceiverAudioJackTypeUnplugged ? 
													   [self errorForCode:TIAirtunesReceiverErrorCodeAudioJackUnplugged] : nil);
		}
	}
	else if ([messageType isEqualToString:TIAirtunesReceiverCommandSetParameter]){
		
	}
	else if ([messageType isEqualToString:TIAirtunesReceiverCommandFlush]){
		aSeq = 0;
		aTimestamp = 0;
	}
	
	[commandsAwaitingResponse removeObjectForKey:numberKey];
}

- (NSInteger)sendCommand:(NSString *)command headers:(NSDictionary *)headers contentType:(NSString *)contentType body:(NSString *)body {
	
	if (!RTSPURL) RTSPURL = [[NSString alloc] initWithFormat:@"rtsp://%@/%d", self.localAddress, encryptor.sID];
	
	NSMutableString * request = [[NSMutableString alloc] init];
	[request appendFormat:@"%@ %@ RTSP/1.0\r\n", command, RTSPURL];
	[request appendFormat:@"cSeq: %d\r\n", ++cSeq];
	
	if (session) [request appendFormat:@"Session: %@\r\n", session];
	if (contentType && body) [request appendFormat:@"Content-Type: %@\r\n"
							  "Content-Length: %d\r\n", contentType, body.length];
	
	[request appendFormat:@"User-Agent: AirplayServer/1.0\r\n"];
	[request appendFormat:@"Client-Instance: %@\r\n", encryptor.sCI];
	
	for (NSString * key in headers){
		[request appendFormat:@"%@: %@\r\n", key, [headers objectForKey:key]];
	}
	
	[request appendString:@"\r\n"];
	if (body)[request appendString:body];
	
	[self sendControlPayload:[request dataUsingEncoding:NSASCIIStringEncoding]];
	[request release];
	
	[commandsAwaitingResponse setObject:command forKey:[NSNumber numberWithInteger:cSeq]];
	return cSeq;
}

- (void)sendControlPayload:(NSData *)payload {
	
	if (payload) [controlOutputBuffer appendData:payload];
	if (controlOutputStream.hasSpaceAvailable) [self bufferOutgoingControlData];
}

#pragma mark - Stream stuff

- (void)openControlStreams {
	[controlInputStream setDelegate:self];
	[controlOutputStream setDelegate:self];
	[controlInputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[controlOutputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[controlInputStream open];
	[controlOutputStream open];
}

- (void)closeControlStreams {
	
	[controlInputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[controlOutputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[controlInputStream release];
	[controlOutputStream release];
	controlInputStream = nil;
	controlOutputStream = nil;
	
	[self closeAudioStream];
	
	connected = NO;
	recording = NO;
	announcing = NO;
	disconnectionCallback();
}

- (void)openAudioStream {
	[self closeAudioStream];
	
	[NSStream getStreamsToHost:[NSHost hostWithAddress:address] port:audioServerPort inputStream:NULL outputStream:&audioOutputStream];
	[audioOutputStream retain];
	[audioOutputStream setDelegate:self];
	[audioOutputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[audioOutputStream open];
}

- (void)closeAudioStream {
	
	[audioOutputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[audioOutputStream release];
	audioOutputStream = nil;
}

- (void)bufferOutgoingControlData {
	
	if (controlOutputBuffer.length){
		
		NSInteger length = 0;
		if ((length = [controlOutputStream write:controlOutputBuffer.bytes maxLength:controlOutputBuffer.length]) > 0){
			[controlOutputBuffer replaceBytesInRange:NSMakeRange(0, length) withBytes:NULL length:0];
		}
		else
		{
			[controlOutputBuffer setLength:0];
			[self disconnect];
		}
	}
}

- (void)bufferOutgoingAudio {
	
	if (audioOuputBuffer.length){
		
		NSInteger audioLength = MIN(kTIAirtunesReceiverFramesPerPacket * 4, audioOuputBuffer.length);
		unsigned char audioBuffer[audioLength];
		[audioOuputBuffer getBytes:audioBuffer length:audioLength];
		
		// This should work, right? The sound.m4a is ALAC encoded, so don't need to do that ourselves, or do we?
		// The header follows the pattern described in the protocol.
		// Maybe the encryptor isn't working, but I'm unsure how to test it.
		
		NSMutableData * headerData = [[NSMutableData alloc] initWithLength:12];
		[headerData	replaceBytesInRange:NSMakeRange(0, 2) withBytes:(unsigned char[2]){0x80, (aSeq ? 0xe0 : 0x60)}];
		[headerData replaceBytesInRange:NSMakeRange(2, 2) withBytes:(unsigned char[2]){((aSeq >> 8) & 0xFF), (aSeq & 0xFF)}];
		[headerData replaceBytesInRange:NSMakeRange(4, 4) withBytes:(unsigned char[4]){((aTimestamp >> 24) & 0xFF), ((aTimestamp >> 16) & 0xFF), 
			((aTimestamp >> 8) & 0xFF), (aTimestamp & 0xFF)}];
		[headerData replaceBytesInRange:NSMakeRange(8, 4) withBytes:(unsigned char[4]){0x30, 0x9f, 0xdc, 0x88}];
		
		NSData * encryptedBytes = [encryptor encryptData:[NSData dataWithBytes:audioBuffer length:audioLength]];
		
		NSMutableData * encodedData = [[NSMutableData alloc] initWithLength:(headerData.length + encryptedBytes.length)];
		[encodedData setLength:(headerData.length + encryptedBytes.length)];
		[encodedData replaceBytesInRange:NSMakeRange(0, headerData.length) withBytes:headerData.bytes];
		[encodedData replaceBytesInRange:NSMakeRange(headerData.length, encryptedBytes.length) withBytes:encryptedBytes.bytes];
		
		NSInteger length = 0;
		if ((length = [audioOutputStream write:encodedData.bytes maxLength:encodedData.length]) > 0){
			[audioOuputBuffer replaceBytesInRange:NSMakeRange(0, audioLength) withBytes:NULL length:0];
			aSeq++;
			aTimestamp += kTIAirtunesReceiverFramesPerPacket;
		}
		else
		{
			[audioOuputBuffer setLength:0];
			[self disconnect];
		}
		
		[encodedData release];
	}
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
	
	if (eventCode == NSStreamEventOpenCompleted){
		
		if (aStream != audioOutputStream){
			if (!connected) [self announce];
		}
	}
	
	if (eventCode == NSStreamEventHasBytesAvailable){
		
		if (aStream == controlInputStream){
			
			uint8_t buffer[1024];
			while (controlInputStream.hasBytesAvailable){
				
				NSInteger length = 0;
				if ((length = [controlInputStream read:buffer maxLength:sizeof(buffer)])){
					[controlInputBuffer appendData:[NSData dataWithBytes:buffer length:length]];
				}
				else
				{
					[controlInputBuffer setLength:0];
					[self closeControlStreams];
				}
			}
			
			NSString * response = [[NSString alloc] initWithData:controlInputBuffer encoding:NSUTF8StringEncoding];
			[controlInputBuffer setLength:0];
			[self processResponse:response];
			[response release];
		}
	}
	
	if (eventCode == NSStreamEventHasSpaceAvailable){
		if (aStream == controlOutputStream) [self bufferOutgoingControlData];
		if (aStream == audioOutputStream) [self bufferOutgoingAudio];
	}
	
	if (eventCode == NSStreamEventEndEncountered){
		[self closeControlStreams]; // Easier to close everything
	}
}

#pragma mark - Getters and that
- (NSString *)localAddress {
	// Could make this return the real address, but it's not really used.
	return @"192.168.1.2";
}

- (NSError *)errorForCode:(NSInteger)code {
	
	NSString * message = @"An unknown error occured";
	if (code == TIAirtunesReceiverErrorCodeAudioJackUnplugged) message = @"The Audio Jack is unplugged.";
	if (code == TIAirtunesReceiverErrorCodeUnauthorized) message = @"The password was rejected.";
	if (code == TIAirtunesReceiverErrorCodeReceiverInUse) message = @"This receiver is in use by another application.";
	
	NSDictionary * userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
	NSError * error = [NSError errorWithDomain:TIAirtunesReceiverErrorDomain code:TIAirtunesReceiverErrorCodeAudioJackUnplugged userInfo:userInfo];
	[userInfo release];
	
	return error;
}

- (NSDictionary *)dictionaryFromResponse:(NSString *)response {
	
	NSMutableDictionary * dictionary = [[NSMutableDictionary alloc] init];
	
	NSArray * lines = [response componentsSeparatedByString:@"\r\n"];
	for (int i = 0; i < lines.count; i++){
		
		NSArray * keyObjectPair = [[lines objectAtIndex:i] componentsSeparatedByString:@":"];
		if (keyObjectPair.count > 1){
			NSString * trimmedObject = [[keyObjectPair objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			[dictionary setObject:trimmedObject forKey:[keyObjectPair objectAtIndex:0]];
		}
	}
	
	return [dictionary autorelease];
}

#pragma mark - Other Shit
- (NSString *)description {
	return [NSString stringWithFormat:@"<TIAirtunesReceiver %p; name: %@; passwordProtected: %@>", 
			self, name, (passwordProtected ? @"YES" : @"NO")];
}

- (void)dealloc {
	[self disconnect];
	[associatedService release];
	[name release];
	[address release];
	[password release];
	[controlInputBuffer release];
	[controlOutputBuffer release];
	[audioOuputBuffer release];
	[connectionCallback release];
	[disconnectionCallback release];
	[encryptor release];
	[super dealloc];
}

@end