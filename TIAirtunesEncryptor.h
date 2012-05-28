//
//  TIAirtunesEncryptor.h
//  AirtunesServer
//
//  Created by Tom Irving on 27/05/2012.
//  Copyright (c) 2012 Tom Irving. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TIAirtunesEncryptor : NSObject  {
	
	NSData * aesKey;
	NSData * aesIV;
	
	NSInteger sID;
	NSString * sCI;
	NSString * sAC;
	
	NSString * encodedAESKey;
	NSString * encodedAESIV;
}

@property (nonatomic, readonly) NSData * aesKey;
@property (nonatomic, readonly) NSData * aesIV;
@property (nonatomic, readonly) NSInteger sID;
@property (nonatomic, readonly) NSString * sCI;
@property (nonatomic, readonly) NSString * sAC;

@property (nonatomic, readonly) NSString * encodedAESKey;
@property (nonatomic, readonly) NSString * encodedAESIV;

- (NSData *)encryptData:(NSData *)data;

@end