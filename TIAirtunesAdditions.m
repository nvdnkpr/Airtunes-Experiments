//
//  TIAirtunesAdditions.m
//  AirtunesServer
//
//  Created by Tom Irving on 28/05/2012.
//  Copyright (c) 2012 Tom Irving. All rights reserved.
//

#import "TIAirtunesAdditions.h"
#import <Security/Security.h>

@implementation NSData (Base64Additions)

- (NSString *)base64EncodedString {
	
	SecTransformRef base64Transform = SecEncodeTransformCreate(kSecBase64Encoding, NULL);
	if (base64Transform){
		
		SecTransformSetAttribute(base64Transform, kSecTransformInputAttributeName, (CFDataRef)self, NULL);
		
		CFDataRef output = SecTransformExecute(base64Transform, NULL);
		CFRelease(base64Transform);
		
		return [[[NSString alloc] initWithData:(NSData *)output encoding:NSUTF8StringEncoding] autorelease];
	}
	
	return nil;
}

@end

@implementation NSString (Base64Additions)

- (NSData *)base64DecodedData {
	
	SecTransformRef base64Transform = SecDecodeTransformCreate(kSecBase64Encoding, NULL);
	if (base64Transform){
		
		SecTransformSetAttribute(base64Transform, kSecTransformInputAttributeName, (CFDataRef)[self dataUsingEncoding:NSUTF8StringEncoding], NULL);
		CFDataRef output = SecTransformExecute(base64Transform, NULL);
		CFRelease(base64Transform);
		
		return (NSData *)output;
	}
	
	return nil;
}

@end

@implementation NSString (TIAirtunesAdditions)

- (BOOL)contains:(NSString *)substring {
	return ([self rangeOfString:substring].location != NSNotFound);
}

@end

@implementation NSNetService (TIAirtunesAdditions)

- (NSString *)friendlyName {
	
	NSRange atRange = [self.name rangeOfString:@"@"];
	if (atRange.location != NSNotFound)
		return [self.name substringWithRange:NSMakeRange(atRange.location + 1, self.name.length - NSMaxRange(atRange))];
	
	return self.name;
}

- (NSDictionary *)TXTRecordDictionary {
	
	NSMutableDictionary * friendlyDict = [[NSMutableDictionary alloc] init];
	NSDictionary * TXTRecord = [NSNetService dictionaryFromTXTRecordData:self.TXTRecordData];
	
	for (id key in TXTRecord){
		NSString * stringRep = [[NSString alloc] initWithData:[TXTRecord objectForKey:key] 
													 encoding:NSUTF8StringEncoding];
		[friendlyDict setObject:stringRep forKey:key];
		[stringRep release];
	}
	
	return [friendlyDict autorelease];
}

@end