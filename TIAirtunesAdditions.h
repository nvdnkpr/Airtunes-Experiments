//
//  TIAirtunesAdditions.h
//  AirtunesServer
//
//  Created by Tom Irving on 28/05/2012.
//  Copyright (c) 2012 Tom Irving. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Base64Additions)
- (NSString *)base64EncodedString;
@end

@interface NSString (Base64Additions)
- (NSData *)base64DecodedData;
@end

@interface NSString (TIAirtunesAdditions)
- (BOOL)contains:(NSString *)substring;
@end

@interface NSNetService (TIAirtunesAdditions)
@property (nonatomic, readonly) NSString * friendlyName;
@property (nonatomic, readonly) NSDictionary * TXTRecordDictionary;
@end