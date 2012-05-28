//
//  TIAirtunesEncryptor.m
//  AirtunesServer
//
//  Created by Tom Irving on 27/05/2012.
//  Copyright (c) 2012 Tom Irving. All rights reserved.
//

#import "TIAirtunesEncryptor.h"
#import <Security/SecRandom.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonCryptor.h>
#import <openssl/rsa.h>
#import "TIAirtunesAdditions.h"

@interface TIAirtunesEncryptor (Private)
- (NSData *)RSAEncryptData:(NSData *)data;
- (NSData *)randomDataWithLength:(NSUInteger)length;
- (NSString *)hexStringFromData:(NSData *)data;
@end

@implementation TIAirtunesEncryptor
@synthesize aesKey;
@synthesize aesIV;
@synthesize sID;
@synthesize sCI;
@synthesize sAC;
@synthesize encodedAESKey;
@synthesize encodedAESIV;

#pragma mark - Instance Methods
- (id)init {
	
	if ((self = [super init])){
		
		aesKey = [[self randomDataWithLength:kCCKeySizeAES128] retain];
		aesIV = [[self randomDataWithLength:kCCBlockSizeAES128] retain];
		
		sID = arc4random();
		sCI = [[self hexStringFromData:[self randomDataWithLength:64]] retain];
		sAC = [[[self randomDataWithLength:16] base64EncodedString] retain];
		
		encodedAESKey = [[[[self RSAEncryptData:aesKey] base64EncodedString] stringByReplacingOccurrencesOfString:@"=" withString:@""] retain];
		encodedAESIV = [[[aesIV base64EncodedString] stringByReplacingOccurrencesOfString:@"=" withString:@""] retain];
	}
	
	return self;
}

- (NSData *)encryptData:(NSData *)data {
	
    unsigned char cKey[kCCKeySizeAES128];
	bzero(cKey, sizeof(cKey));
    [aesKey getBytes:cKey length:kCCKeySizeAES128];
	
    char cIv[kCCBlockSizeAES128];
    bzero(cIv, kCCBlockSizeAES128);
	[aesIV getBytes:cIv length:kCCBlockSizeAES128];
	
	size_t bufferSize = data.length + kCCBlockSizeAES128;
	void *buffer = malloc(bufferSize);
	
	size_t encryptedSize = 0;
	CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          cKey, kCCKeySizeAES128, cIv,
                                          data.bytes, data.length,
                                          buffer, bufferSize, &encryptedSize);
	
	NSData * result = nil;
	if (cryptStatus == kCCSuccess) result = [NSData dataWithBytes:buffer length:encryptedSize];
	free(buffer);
	
	return result;
}

#pragma mark - Private Helpers
- (NSData *)RSAEncryptData:(NSData *)data {
	
	RSA * rsa = RSA_new();
	
	NSString * modulusString = (@"59dE8qLieItsH1WgjrcFRKj6eUWqi+bGLOX1HL3U3GhC/j0Qg90u3sG/1CUtwC"
								"5vOYvfDmFI6oSFXi5ELabWJmT2dKHzBJKa3k9ok+8t9ucRqMd6DZHJ2YCCLlDR"
								"KSKv6kDqnw4UwPdpOMXziC/AMj3Z/lUVX1G7WSHCAWKf1zNS1eLvqr+boEjXuB"
								"OitnZ/bDzPHrTOZz0Dew0uowxf/+sG+NCK3eQJVxqcaJ/vEHKIVd2M+5qL71yJ"
								"Q+87X6oV3eaYvt3zWZYD6z5vYTcrtij2VZ9Zmni/UAaHqn9JdsBWLUEpVviYnh"
								"imNVvYFZeCXg/IdTQ+x4IRdiXNv5hEew==");
	NSData * decodedModulus = [modulusString base64DecodedData];
	rsa->n = BN_bin2bn(decodedModulus.bytes, decodedModulus.length, NULL);
	
	NSData * decodedExponent = [@"AQAB" base64DecodedData];
	rsa->e = BN_bin2bn(decodedExponent.bytes, decodedExponent.length, NULL);
	
	NSMutableData * encrypted = [NSMutableData dataWithLength:256];
	RSA_public_encrypt(data.length, data.bytes, encrypted.mutableBytes, rsa, RSA_PKCS1_OAEP_PADDING);
	RSA_free(rsa);
	
	return encrypted;
}

- (NSData *)randomDataWithLength:(NSUInteger)length {
	
	NSMutableData * data = [NSMutableData dataWithLength:length];
	return (SecRandomCopyBytes(kSecRandomDefault, length, data.mutableBytes) == noErr ? data : nil);
}

- (NSString *)hexStringFromData:(NSData *)data {
	
	NSMutableString * hexString = [NSMutableString string];
	for (int i = 0; i < data.length; i++) {
		[hexString appendFormat:@"%02x", data.bytes[i]];
	}
	
	return hexString;
}

#pragma mark - Memory Management
- (void)dealloc {
	[aesKey release];
	[aesIV release];
	[sCI release];
	[sAC release];
	[encodedAESKey release];
	[encodedAESIV release];
	[super dealloc];
}

@end