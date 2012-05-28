//
//  MainWindowController.h
//  AirtunesServer
//
//  Created by Tom Irving on 01/03/2012.
//  Copyright (c) 2012 Tom Irving. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MainWindowController : NSWindowController {
	
	NSMutableArray * receivers;
	
	NSButton * connectButton;
	NSPopUpButton * receiversPopupButton;
	NSTextField * statusField;
}

@end
