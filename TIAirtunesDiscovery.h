//
//  TIAirtunesDiscovery.h
//  AirtunesServer
//
//  Created by Tom Irving on 01/03/2012.
//  Copyright 2012 Tom Irving. All rights reserved.
//

#import <Foundation/Foundation.h>

//==========================================================
#pragma mark - TIAirtunesDiscovery -
//==========================================================

@class TIAirtunesReceiver;

typedef void (^TIAirtunesDiscoveryFoundReceiverCallback)(TIAirtunesReceiver * receiver);
@interface TIAirtunesDiscovery : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
	
	NSNetServiceBrowser * serviceBrowser;
	NSMutableArray * potentialServices;
	TIAirtunesDiscoveryFoundReceiverCallback foundReceiverBlock;
}

+ (TIAirtunesDiscovery *)sharedDiscovery;
- (void)searchForAirtunesReceivers:(TIAirtunesDiscoveryFoundReceiverCallback)foundBlock;
- (void)stopSearching;

@end
