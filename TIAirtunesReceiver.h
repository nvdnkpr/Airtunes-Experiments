//
//  TIAirtunesReceiver.h
//  TIAirtunesReceiver
//
//  Created by Tom Irving on 01/03/2012.
//  Copyright 2012 Tom Irving. All rights reserved.
//
//	Redistribution and use in source and binary forms, with or without modification,
//	are permitted provided that the following conditions are met:
//
//		1. Redistributions of source code must retain the above copyright notice, this list of
//		   conditions and the following disclaimer.
//
//		2. Redistributions in binary form must reproduce the above copyright notice, this list
//         of conditions and the following disclaimer in the documentation and/or other materials
//         provided with the distribution.
//
//	THIS SOFTWARE IS PROVIDED BY TOM IRVING "AS IS" AND ANY EXPRESS OR IMPLIED
//	WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//	FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL TOM IRVING OR
//	CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//	SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//	ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//	NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
//	ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <Foundation/Foundation.h>

//==========================================================
#pragma mark - TIAirtunesReceiver -
//==========================================================

extern NSString * const TIAirtunesReceiverErrorDomain;

typedef enum {
	TIAirtunesReceiverErrorCodeUnauthorized = 0,
	TIAirtunesReceiverErrorCodeAudioJackUnplugged = -1,
	TIAirtunesReceiverErrorCodeReceiverInUse = -2,
	TIAirtunesReceiverErrorCodeUnknown = -3,
} TIAirtunesReceiverErrorCode;

typedef enum {
	TIAirtunesReceiverAudioJackTypeUnplugged = 0,
	TIAirtunesReceiverAudioJackTypeAnalog,
	TIAirtunesReceiverAudioJackTypeDigital,
} TIAirtunesReceiverAudioJackType;

typedef void (^TIAirtunesReceiverConnectionCallback)(NSError * error);
typedef void (^TIAirtunesReceiverDisconnectionCallback)();

@class TIAirtunesEncryptor;

@interface TIAirtunesReceiver : NSObject <NSStreamDelegate> {
	
	TIAirtunesEncryptor * encryptor;
	
	NSNetService * associatedService;
	
	NSString * name;
	NSString * address;
	NSString * password;
	BOOL passwordProtected;
	
	NSString * RTSPURL;
	NSString * session;
	NSInteger cSeq;
	
	// The a is for audio
	unsigned short aSeq;
	unsigned long aTimestamp;
	
	NSInputStream * controlInputStream;
	NSOutputStream * controlOutputStream;
	NSMutableData * controlInputBuffer;
	NSMutableData * controlOutputBuffer;
	
	NSInteger audioServerPort;
	NSOutputStream * audioOutputStream;
	NSMutableData * audioOuputBuffer;
	
	NSMutableDictionary * commandsAwaitingResponse;
	
	BOOL announcing;
	BOOL connected;
	BOOL recording;
	
	TIAirtunesReceiverConnectionCallback connectionCallback;
	TIAirtunesReceiverDisconnectionCallback disconnectionCallback;
	
	TIAirtunesReceiverAudioJackType audioJackType;
}

@property (nonatomic, readonly) NSNetService * associatedService;
@property (nonatomic, readonly) NSString * name;
@property (nonatomic, readonly) NSString * address;
@property (nonatomic, readonly) BOOL passwordProtected;
@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, copy) TIAirtunesReceiverDisconnectionCallback disconnectionCallback;
@property (nonatomic, readonly) TIAirtunesReceiverAudioJackType audioJackType;

- (id)initWithNetService:(NSNetService *)netService;

- (void)connectWithPassword:(NSString *)aPassword callback:(TIAirtunesReceiverConnectionCallback)callback;
- (void)setVolume:(NSInteger)volume;
- (void)playAudioData:(NSData *)data;

- (void)disconnect;

@end