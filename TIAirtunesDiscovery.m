//
//  TIAirtunesDiscovery.m
//  AirtunesServer
//
//  Created by Tom Irving on 05/03/2012.
//  Copyright 2012 Tom Irving. All rights reserved.
//

#import "TIAirtunesDiscovery.h"
#import "TIAirtunesReceiver.h"

//==========================================================
#pragma mark - TIAirtunesDiscovery -
//==========================================================

@implementation TIAirtunesDiscovery

- (id)init {
	
	if ((self = [super init])){
		
		serviceBrowser = [[NSNetServiceBrowser alloc] init];
		[serviceBrowser setDelegate:self];
		
		foundReceiverBlock = nil;
		potentialServices = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)searchForAirtunesReceivers:(TIAirtunesDiscoveryFoundReceiverCallback)foundBlock {
	
	[foundReceiverBlock release];
	foundReceiverBlock = [foundBlock copy];
	
	[serviceBrowser searchForServicesOfType:@"_raop._tcp." inDomain:@"local"];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
	
	[potentialServices addObject:aNetService];
	[aNetService setDelegate:self];
	[aNetService resolveWithTimeout:0];
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
	
	TIAirtunesReceiver * receiver = [[TIAirtunesReceiver alloc] initWithNetService:sender];
	foundReceiverBlock(receiver);
	[receiver release];
	
	[potentialServices removeObject:sender];
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
	[potentialServices removeObject:sender];
}

- (void)stopSearching {
	[serviceBrowser stop];
}

#pragma mark Singleton Shit

+ (TIAirtunesDiscovery *)sharedDiscovery {
	
	static TIAirtunesDiscovery * shared = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{shared = [[self alloc] init];});
	
	return shared;
}

- (id)copyWithZone:(NSZone *)zone { 
	return self; 
} 

- (id)retain { 
	return self;
}

- (NSUInteger)retainCount {
	return NSUIntegerMax;
}

- (oneway void)release {}

- (id)autorelease {
	return self;
}

@end
