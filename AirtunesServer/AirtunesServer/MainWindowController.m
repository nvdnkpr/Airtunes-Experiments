//
//  MainWindowController.m
//  AirtunesServer
//
//  Created by Tom Irving on 01/03/2012.
//  Copyright (c) 2012 Tom Irving. All rights reserved.
//

#import "MainWindowController.h"
#import "TIAirtunesReceiver.h"
#import "TIAirtunesDiscovery.h"

@implementation MainWindowController

- (id)init {
	
	if ((self = [super init])){
		
		NSRect windowRect = NSMakeRect(200, 200, 400, 250);
		NSWindow * daWindow = [[NSWindow alloc] initWithContentRect:windowRect styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask) 
															backing:NSBackingStoreBuffered defer:YES];
		[daWindow setTitle:@"AirTunes Streaming (up in this bitch)"];
		[daWindow setReleasedWhenClosed:NO];
		
		receiversPopupButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(10, windowRect.size.height - 36, windowRect.size.width - 115, 26) pullsDown:NO];
		[receiversPopupButton setTarget:self];
		[receiversPopupButton setAction:@selector(receiversPopUpDidChange:)];
		[receiversPopupButton setAutoenablesItems:NO];
		[daWindow.contentView addSubview:receiversPopupButton];
		[receiversPopupButton release];
		
		connectButton = [[NSButton alloc] initWithFrame:NSMakeRect(windowRect.size.width - 110, windowRect.size.height - 37, 100, 26)];
		[connectButton setTitle:@"Connect"];
		[connectButton setEnabled:NO];
		[connectButton setAlignment:NSCenterTextAlignment];
		[connectButton setButtonType:NSMomentaryPushInButton];
		[connectButton setBezelStyle:NSRoundedBezelStyle];
		[connectButton.cell setControlSize:NSRegularControlSize];
		[connectButton setFont:[NSFont systemFontOfSize:13]];
		[connectButton setTarget:self];
		[connectButton setAction:@selector(connectButtonWasPushed:)];
		[daWindow.contentView addSubview:connectButton];
		[connectButton release];
		
		statusField = [[NSTextField alloc] initWithFrame:NSMakeRect(10, (windowRect.size.height / 2) - 10, windowRect.size.width - 20, 20)];
		[statusField setStringValue:@"Disconnected"];
		[statusField setAlignment:NSCenterTextAlignment];
		[statusField setEditable:NO];
		[statusField setBackgroundColor:[NSColor controlColor]];
		[statusField setBezeled:NO];
		[statusField setSelectable:NO];
		[statusField setFont:[NSFont systemFontOfSize:13]];
		[daWindow.contentView addSubview:statusField];
		[statusField release];
		
		[self setWindow:daWindow];
		[daWindow release];
		
		receivers = [[NSMutableArray alloc] init];
		
		[[TIAirtunesDiscovery sharedDiscovery] searchForAirtunesReceivers:^(TIAirtunesReceiver * airplayReceiver){
			
			// If you wanna use the receiver, you should hold on to it.
			[receivers addObject:airplayReceiver];
			
			[airplayReceiver setDisconnectionCallback:^{
				[statusField setStringValue:@"Disconnected"];
				[connectButton setTitle:@"Connect"];
			}];
			
			[receiversPopupButton addItemWithTitle:airplayReceiver.name];
			[connectButton setEnabled:YES];
		}];
	}
	
	return self;
}

- (void)receiversPopUpDidChange:(id)sender {
	
	TIAirtunesReceiver * receiver = [receivers objectAtIndex:receiversPopupButton.indexOfSelectedItem];
	[connectButton setTitle:(receiver.connected ? @"Disconnect" : @"Connect")];
}

- (void)connectButtonWasPushed:(id)sender {
	
	TIAirtunesReceiver * receiver = [receivers objectAtIndex:receiversPopupButton.indexOfSelectedItem];
	
	if (!receiver.connected){
		__block TIAirtunesReceiver * weakRec = receiver;
		[receiver connectWithPassword:nil callback:^(NSError * error){
			
			[statusField setStringValue:(error ? error.localizedDescription : [NSString stringWithFormat:@"Connected to %@", weakRec.name])];
			[connectButton setTitle:(error ? @"Connect" : @"Disconnect")];
			
			if (!error) [weakRec playAudioData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"sound" ofType:@"m4a"]]];
		}];
	}
	else
	{
		[receiver disconnect];
	}
}

- (void)dealloc {
	[receivers release];
	[super dealloc];
}

@end
