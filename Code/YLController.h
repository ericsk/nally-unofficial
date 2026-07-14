//
//  YLController.h
//  Nally
//
//  Created by Yung-Luen Lan on 9/11/07.
//  Copyright 2007 yllan.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "YLView.h"
#import <PSMTabBarControl/PSMTabBarControl.h>
#import "YLSite.h"
@class YLPluginLoader;

@class YLTerminal;
@class YLExifController;

@interface YLController : NSObject <PSMTabBarControlDelegate> {
    IBOutlet NSWindow *_mainWindow;
	IBOutlet id _telnetView;
	IBOutlet id _addressBar;
    IBOutlet id _detectDoubleByteButton;
    
    IBOutlet PSMTabBarControl *_tab;
    IBOutlet NSMenuItem *_detectDoubleByteMenuItem;
    IBOutlet NSMenuItem *_closeWindowMenuItem;
    IBOutlet NSMenuItem *_closeTabMenuItem;
    NSMutableArray *_sites;
    IBOutlet NSMenuItem *_sitesMenu;
    IBOutlet NSMenuItem *_showHiddenTextMenuItem;
    IBOutlet NSMenuItem *_encodingMenuItem;
    IBOutlet YLExifController *_exifController;

    YLPluginLoader *_pluginLoader;
}

- (void) updateSitesMenu;
- (void) loadSites;
- (void) saveSites;
- (void) loadLastConnections;

- (IBAction) setEncoding: (id)sender;
- (IBAction) setDetectDoubleByteAction: (id)sender;

- (IBAction) newTab: (id)sender;
- (IBAction) connect: (id)sender;
- (IBAction) openLocation: (id)sender;
- (IBAction) selectNextTab: (id)sender;
- (IBAction) selectPrevTab: (id)sender;
- (IBAction) selectTabNumber: (int)index;
- (IBAction) closeTab: (id)sender;
- (IBAction) openSites: (id)sender;
- (IBAction) editSites: (id)sender;
- (IBAction) closeSites: (id)sender;
- (IBAction) autoLogin: (id)sender;
- (IBAction) showHiddenText: (id)sender;
- (IBAction) openPreferencesWindow: (id)sender;
- (void) newConnectionWithSite: (YLSite *)site;
- (void) setupAfterSwiftUI;
- (void)setAddressBar:(id)addressBar;
- (void)setDetectDoubleByteButton:(id)detectDoubleByteButton;



- (YLExifController *) exifController;
- (id) telnetView;

- (NSArray *) sites;
- (unsigned) countOfSites;
- (id) objectInSitesAtIndex: (unsigned)theIndex;
- (void) getSites: (id *)objsPtr range: (NSRange)range;
- (void) insertObject: (id)obj inSitesAtIndex: (unsigned)theIndex;
- (void) removeObjectFromSitesAtIndex: (unsigned)theIndex;
- (void) replaceObjectInSitesAtIndex: (unsigned)theIndex withObject: (id)obj;

- (void) refreshTabLabelNumber: (NSTabView *)tabView;



@end
