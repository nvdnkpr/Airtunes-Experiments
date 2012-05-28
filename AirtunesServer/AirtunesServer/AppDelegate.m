//
//  AppDelegate.m
//  AirtunesServer
//
//  Created by Tom Irving on 01/03/2012.
//  Copyright (c) 2012 Tom Irving. All rights reserved.
//

#import "AppDelegate.h"
#import "MainWindowController.h"
#import "TIAirtunesEncryptor.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	
	// Wish there was an easy way to set up the app without a XIB at all, like on iOS.
	// Fuck you, MainMenu.xib
	mainWindowController = [[MainWindowController alloc] init];
	[mainWindowController showWindow:self];
}

- (void)dealloc {
	[mainWindowController release];
	[super dealloc];
}

@end
