//
//  YLController.m
//  MacBlueTelnet
//
//  Created by Yung-Luen Lan on 9/11/07.
//  Copyright 2007 yllan.org. All rights reserved.
//

#import "YLController.h"
#import "YLTelnet.h"
#import "YLTerminal.h"
#import "YLLGlobalConfig.h"
#import "DBPrefsWindowController.h"
#import "YLEmoticon.h"

@interface YLController (Private)
- (BOOL)tabView:(NSTabView *)tabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem ;
- (void)tabView:(NSTabView *)tabView willCloseTabViewItem:(NSTabViewItem *)tabViewItem ;
- (void)tabView:(NSTabView *)tabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem ;
@end

@implementation YLController

- (void) awakeFromNib {
    // Register URL
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(getUrl:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
    
    NSArray *observeKeys = [NSArray arrayWithObjects: @"shouldSmoothFonts", @"showHiddenText", @"messageCount", @"cellWidth", @"cellHeight", 
                            @"chineseFontName", @"chineseFontSize", @"chineseFontPaddingLeft", @"chineseFontPaddingBottom",
                            @"englishFontName", @"englishFontSize", @"englishFontPaddingLeft", @"englishFontPaddingBottom", 
                            @"colorBlack", @"colorBlackHilite", @"colorRed", @"colorRedHilite", @"colorGreen", @"colorGreenHilite",
                            @"colorYellow", @"colorYellowHilite", @"colorBlue", @"colorBlueHilite", @"colorMagenta", @"colorMagentaHilite", 
                            @"colorCyan", @"colorCyanHilite", @"colorWhite", @"colorWhiteHilite", @"colorBG", @"colorBGHilite", nil];
    for (NSString *key in observeKeys)
        [[YLLGlobalConfig sharedInstance] addObserver: self
                                           forKeyPath: key
                                              options: (NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
                                              context: NULL];

    [_tab setCanCloseOnlyTab: YES];
    [[YLLGlobalConfig sharedInstance] setShowHiddenText: [[YLLGlobalConfig sharedInstance] showHiddenText]];
    
    [self loadSites];
    [self updateSitesMenu];
    [self loadEmoticons];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"RestoreConnection"]) 
        [self loadLastConnections];
    
    [NSTimer scheduledTimerWithTimeInterval: 120 target: self selector: @selector(antiIdle:) userInfo: nil repeats: YES];
    [NSTimer scheduledTimerWithTimeInterval: 1 target: self selector: @selector(updateBlinkTicker:) userInfo: nil repeats: YES];

    [self observeValueForKeyPath: @"cellWidth" ofObject: [YLLGlobalConfig sharedInstance]
                          change: [NSDictionary dictionary] context: NULL];
}

- (void) updateSitesMenu {
    int total = [[_sitesMenu submenu] numberOfItems] ;
    int i;
    for (i = 3; i < total; i++) {
        [[_sitesMenu submenu] removeItemAtIndex: 3];
    }
    
    for (YLSite *s in _sites) {
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle: [s name] ?: @"" action: @selector(openSiteMenu:) keyEquivalent: @""];
        [menuItem setRepresentedObject: s];
        [[_sitesMenu submenu] addItem: menuItem];
        [menuItem release];
    }
}

- (void) updateEncodingMenu {
    // Update encoding menu status
    NSMenu *m = [_encodingMenuItem submenu];
    int i;
    for (i = 0; i < [m numberOfItems]; i++) {
        NSMenuItem *item = [m itemAtIndex: i];
        [item setState: NSOffState];
        if ([_telnetView frontMostTerminal] && i == [[_telnetView frontMostTerminal] encoding])
            [item setState: NSOnState];
    }
}

- (void) updateBlinkTicker: (NSTimer *) t {
    [[YLLGlobalConfig sharedInstance] updateBlinkTicker];
    if ([_telnetView hasBlinkCell])
        [_telnetView setNeedsDisplay: YES];
}

- (void) antiIdle: (NSTimer *) t {
    if (![[NSUserDefaults standardUserDefaults] boolForKey: @"AntiIdle"]) return;
    NSArray *a = [_telnetView tabViewItems];
    for (NSTabViewItem *item in a) {
        id telnet = [item identifier];
        if ([telnet connected] && [telnet lastTouchDate] && [[NSDate date] timeIntervalSinceDate: [telnet lastTouchDate]] >= 119) {
//            unsigned char msg[] = {0x1B, 'O', 'A', 0x1B, 'O', 'B'};
            unsigned char msg[] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
            [telnet sendBytes:msg length:6];
        }
    }
}

- (void) newConnectionWithSite: (YLSite *) s {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
	id terminal = [YLTerminal new];
    YLConnection *connection = [YLConnection connectionWithAddress: [s address]];
    
    BOOL emptyTab = [_telnetView frontMostConnection] && ([_telnetView frontMostTerminal] == nil);
    
    [terminal setEncoding: [s encoding]];
	[connection setTerminal: terminal];
    [connection setConnectionName: [s name]];
    [connection setConnectionAddress: [s address]];
	[terminal setDelegate: _telnetView];
    
    NSTabViewItem *tabItem;
    
    if (emptyTab) {
        tabItem = [_telnetView selectedTabViewItem];
        [tabItem setIdentifier: connection];
    } else {
        tabItem = [[[NSTabViewItem alloc] initWithIdentifier: connection] autorelease];
        [_telnetView addTabViewItem: tabItem];
    }
    
    [tabItem setLabel: [s name]];
	
	[connection connectToSite: s];
    [_telnetView selectTabViewItem: tabItem];
    [terminal release];
    [self refreshTabLabelNumber: _telnetView];
    [self updateEncodingMenu];
    [_detectDoubleByteButton setState: [[[_telnetView frontMostConnection] site] detectDoubleByte] ? NSOnState : NSOffState];
    [_detectDoubleByteMenuItem setState: [[[_telnetView frontMostConnection] site] detectDoubleByte] ? NSOnState : NSOffState];
    [pool release];
}

#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString: @"showHiddenText"]) {
        if ([[YLLGlobalConfig sharedInstance] showHiddenText]) 
            [_showHiddenTextMenuItem setState: NSOnState];
        else
            [_showHiddenTextMenuItem setState: NSOffState];        
    } else if ([keyPath isEqualToString: @"messageCount"]) {
        NSDockTile *dockTile = [NSApp dockTile];
        if ([[YLLGlobalConfig sharedInstance] messageCount] == 0) {
            [dockTile setBadgeLabel: nil];
        } else {
            [dockTile setBadgeLabel: [NSString stringWithFormat: @"%d", [[YLLGlobalConfig sharedInstance] messageCount]]];
        }
        [dockTile display];
    } else if ([keyPath isEqualToString: @"shouldSmoothFonts"]) {
        [[[[_telnetView selectedTabViewItem] identifier] terminal] setAllDirty];
        [_telnetView updateBackedImage];
        [_telnetView setNeedsDisplay: YES];
    } else if ([keyPath hasPrefix: @"cell"]) {
        YLLGlobalConfig *config = [YLLGlobalConfig sharedInstance];
        NSRect r = [_mainWindow frame];
        CGFloat topLeftCorner = r.origin.y + r.size.height;

        CGFloat shift = 0.0;

        /* Calculate the toolbar height */
        shift = NSHeight([_mainWindow frame]) - NSHeight([[_mainWindow contentView] frame]) + 22;

        r.size.width = [config cellWidth] * [config column];
        r.size.height = [config cellHeight] * [config row] + shift;
        r.origin.y = topLeftCorner - r.size.height;
        [_mainWindow setFrame: r display: YES animate: NO];
        [_telnetView configure];
        [[[[_telnetView selectedTabViewItem] identifier] terminal] setAllDirty];
        [_telnetView updateBackedImage];
        [_telnetView setNeedsDisplay: YES];
        NSRect tabRect = [_tab frame];
        tabRect.size.width = r.size.width;
        [_tab setFrame: tabRect];
    } else if ([keyPath hasPrefix: @"chineseFont"] || [keyPath hasPrefix: @"englishFont"] || [keyPath hasPrefix: @"color"]) {
        [[YLLGlobalConfig sharedInstance] refreshFont];
        [[[[_telnetView selectedTabViewItem] identifier] terminal] setAllDirty];
        [_telnetView updateBackedImage];
        [_telnetView setNeedsDisplay: YES];
    }
}

#pragma mark -
#pragma mark User Defaults

- (void) loadSites {
    NSArray *array = [[NSUserDefaults standardUserDefaults] arrayForKey: @"Sites"];
    for (NSDictionary *d in array) 
        [self insertObject: [YLSite siteWithDictionary: d] inSitesAtIndex: [self countOfSites]];    
}

- (void) saveSites {
    NSMutableArray *a = [NSMutableArray array];
    for (YLSite *s in _sites) 
        [a addObject: [s dictionaryOfSite]];
    [[NSUserDefaults standardUserDefaults] setObject: a forKey: @"Sites"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateSitesMenu];
}

- (void) loadEmoticons {
    NSArray *a = [[NSUserDefaults standardUserDefaults] arrayForKey: @"Emoticons"];
    for (NSDictionary *d in a)
        [self insertObject: [YLEmoticon emoticonWithDictionary: d] inEmoticonsAtIndex: [self countOfEmoticons]];
}

- (void) saveEmoticons {
    NSMutableArray *a = [NSMutableArray array];
    for (YLEmoticon *e in _emoticons) 
        [a addObject: [e dictionaryOfEmoticon]];
    [[NSUserDefaults standardUserDefaults] setObject: a forKey: @"Emoticons"];    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) loadLastConnections {
    NSArray *a = [[NSUserDefaults standardUserDefaults] arrayForKey: @"LastConnections"];
    for (NSDictionary *d in a) {
        [self newConnectionWithSite: [YLSite siteWithDictionary: d]];
    }    
}

- (void) saveLastConnections {
    int tabNumber = [_telnetView numberOfTabViewItems];
    int i;
    NSMutableArray *a = [NSMutableArray array];
    for (i = 0; i < tabNumber; i++) {
        id connection = [[_telnetView tabViewItemAtIndex: i] identifier];
        if ([connection terminal]) // not empty tab
            [a addObject: [[connection site] dictionaryOfSite]];
    }
    [[NSUserDefaults standardUserDefaults] setObject: a forKey: @"LastConnections"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark -
#pragma mark Actions
- (IBAction) setDetectDoubleByteAction: (id) sender {
    BOOL ddb = [sender state];
    if ([sender isKindOfClass: [NSMenuItem class]])
        ddb = !ddb;
    [[[_telnetView frontMostConnection] site] setDetectDoubleByte: ddb];
    [_detectDoubleByteButton setState: ddb ? NSOnState : NSOffState];
    [_detectDoubleByteMenuItem setState: ddb ? NSOnState : NSOffState];
}

- (IBAction) setEncoding: (id) sender {
    int index = [[_encodingMenuItem submenu] indexOfItem: sender];
    if ([_telnetView frontMostTerminal]) {
        [[_telnetView frontMostTerminal] setEncoding: (YLEncoding)index];
        [[_telnetView frontMostTerminal] setAllDirty];
        [_telnetView updateBackedImage];
        [_telnetView setNeedsDisplay: YES];
        [self updateEncodingMenu];
    }
}

- (IBAction) newTab: (id) sender {
    YLConnection *connection = [YLConnection new];
    [connection setConnectionAddress: @""];
    [connection setConnectionName: @""];
    NSTabViewItem *tabItem = [[[NSTabViewItem alloc] initWithIdentifier: connection] autorelease];
    [_telnetView addTabViewItem: tabItem];
    [_telnetView selectTabViewItem: tabItem];
    YLSite *s = [YLSite site];
    [s setEncoding: [[YLLGlobalConfig sharedInstance] defaultEncoding]];
    [s setDetectDoubleByte: [[YLLGlobalConfig sharedInstance] detectDoubleByte]];
    
    [_mainWindow makeKeyAndOrderFront: self];
	[_telnetView resignFirstResponder];
	[_addressBar becomeFirstResponder];
    [connection release];
}

- (IBAction) connect: (id) sender {
	[sender abortEditing];
	[[_telnetView window] makeFirstResponder: _telnetView];

    NSString *name = [sender stringValue];
    if ([[name lowercaseString] hasPrefix: @"ssh://"])
        name = [name substringFromIndex: 6];
    if ([[name lowercaseString] hasPrefix: @"telnet://"])
        name = [name substringFromIndex: 9];
    if ([[name componentsSeparatedByString: @"@"] count] == 2)
        name = [[name componentsSeparatedByString: @"@"] objectAtIndex: 1];

    NSMutableArray *matchedSites = [NSMutableArray array];
    YLSite *s = [YLSite site];
    if ([name rangeOfString: @"."].location != NSNotFound) { /* Normal address */        
        for (YLSite *site in _sites) 
            if ([[site address] rangeOfString: name].location != NSNotFound) 
                [matchedSites addObject: site];
        
        if ([matchedSites count] > 0) {
            [matchedSites sortUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey:@"address.length" ascending:YES] autorelease]]];
            s = [[[matchedSites objectAtIndex: 0] copy] autorelease];
        } else {
            [s setAddress: [sender stringValue]];
            [s setName: name];
            [s setEncoding: [[YLLGlobalConfig sharedInstance] defaultEncoding]];
            [s setAnsiColorKey: [[YLLGlobalConfig sharedInstance] defaultANSIColorKey]];
            [s setDetectDoubleByte: [[YLLGlobalConfig sharedInstance] detectDoubleByte]];            
        }
    } else { /* Short Address? */
        for (YLSite *site in _sites) 
            if ([[site name] rangeOfString: name].location != NSNotFound) 
                [matchedSites addObject: site];
        [matchedSites sortUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey:@"name.length" ascending:YES] autorelease]]];
        if ([matchedSites count] == 0) {
            for (YLSite *site in _sites) 
                if ([[site address] rangeOfString: name].location != NSNotFound)
                    [matchedSites addObject: site];
            [matchedSites sortUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey:@"address.length" ascending:YES] autorelease]]];
        } 
        if ([matchedSites count] > 0) {
            s = [[[matchedSites objectAtIndex: 0] copy] autorelease];
        } else {
            [s setAddress: [sender stringValue]];
            [s setName: name];
            [s setEncoding: [[YLLGlobalConfig sharedInstance] defaultEncoding]];
            [s setAnsiColorKey: [[YLLGlobalConfig sharedInstance] defaultANSIColorKey]];
            [s setDetectDoubleByte: [[YLLGlobalConfig sharedInstance] detectDoubleByte]];
        }        
    }
    [self newConnectionWithSite: s];
    [sender setStringValue: [s address]];
}

- (IBAction) openLocation: (id) sender {
    [_mainWindow makeKeyAndOrderFront: self];
	[_telnetView resignFirstResponder];
	[_addressBar becomeFirstResponder];
}

- (IBAction) reconnect: (id) sender {
    [[_telnetView frontMostConnection] reconnect];
}

- (IBAction) selectNextTab: (id) sender {
    if ([_telnetView indexOfTabViewItem: [_telnetView selectedTabViewItem]] == [_telnetView numberOfTabViewItems] - 1)
        [_telnetView selectFirstTabViewItem: self];
    else
        [_telnetView selectNextTabViewItem: self];
}

- (IBAction) selectPrevTab: (id) sender {
    if ([_telnetView indexOfTabViewItem: [_telnetView selectedTabViewItem]] == 0)
        [_telnetView selectLastTabViewItem: self];
    else
        [_telnetView selectPreviousTabViewItem: self];
}

- (IBAction) selectTabNumber: (int) index {
    if (index <= [_telnetView numberOfTabViewItems]) {
        [_telnetView selectTabViewItemAtIndex: index - 1];
    }
}

- (IBAction) closeTab: (id) sender {
    if ([_telnetView numberOfTabViewItems] == 0) return;
    
    NSTabViewItem *tabItem = [_telnetView selectedTabViewItem];
    if ([self tabView: _telnetView shouldCloseTabViewItem: tabItem]) {
        [self tabView: _telnetView willCloseTabViewItem: tabItem];
        [[[tabItem identifier] terminal] setHasMessage: NO];
        [_telnetView removeTabViewItem: tabItem];
        [self tabView: _telnetView didCloseTabViewItem: tabItem];
    }
}

- (IBAction) editSites: (id) sender {
    [NSApp beginSheet: _sitesWindow
       modalForWindow: _mainWindow
        modalDelegate: nil
       didEndSelector: NULL
          contextInfo: nil];
}

- (IBAction) openSites: (id) sender {
    NSArray *a = [_sitesController selectedObjects];
    [self closeSites: sender];
    
    if ([a count] == 1) {
        YLSite *s = [a objectAtIndex: 0];
        [self newConnectionWithSite: [[s copy] autorelease]];
    }
}

- (IBAction) openSiteMenu: (id) sender {
    YLSite *s = [sender representedObject];
    [self newConnectionWithSite: s];
}

- (IBAction) closeSites: (id) sender {
    [_sitesWindow endEditingFor: nil];
    [NSApp endSheet: _sitesWindow];
    [_sitesWindow orderOut: self];
    [self saveSites];
}

- (IBAction) addSites: (id) sender {
    if ([_telnetView numberOfTabViewItems] == 0) return;
    NSString *address = [[_telnetView frontMostConnection] connectionAddress];
    
    for (YLSite *s in _sites) 
        if ([[s address] isEqualToString: address]) 
            return;
    
    YLSite *s = [[[[_telnetView frontMostConnection] site] copy] autorelease];
    [_sitesController addObject: s];
    [_sitesController setSelectedObjects: [NSArray arrayWithObject: s]];
    [self performSelector: @selector(editSites:) withObject: sender afterDelay: 0.1];
    NSLog(@"%d %d", [_siteNameField acceptsFirstResponder], [_sitesWindow makeFirstResponder: _siteNameField]);;
    ;
//    [_sitesTableView editColumn: 0 row: [_sitesTableView selectedRow] withEvent: nil select: YES];
//  FIXME: focus!
}



- (IBAction) showHiddenText: (id) sender {
    BOOL show = ([sender state] == NSOnState);
    if ([sender isKindOfClass: [NSMenuItem class]]) {
        show = !show;
    }

    [[YLLGlobalConfig sharedInstance] setShowHiddenText: show];
    [_telnetView refreshHiddenRegion];
    [_telnetView updateBackedImage];
    [_telnetView setNeedsDisplay: YES];
}

- (IBAction) openPreferencesWindow: (id) sender {
    [[DBPrefsWindowController sharedPrefsWindowController] showWindow:nil];
}

- (IBAction) openEmoticonsWindow: (id) sender {
    [_emoticonsWindow makeKeyAndOrderFront: self];
}

- (IBAction) closeEmoticons: (id) sender {
    [_emoticonsWindow endEditingFor: nil];
    [_emoticonsWindow makeFirstResponder: _emoticonsWindow];
    [_emoticonsWindow orderOut: self];
    [self saveEmoticons];
}

- (IBAction) inputEmoticons: (id) sender {
    [self closeEmoticons: sender];
    
    if ([[_telnetView frontMostConnection] connected]) {
        NSArray *a = [_emoticonsController selectedObjects];
        
        if ([a count] == 1) {
            YLEmoticon *e = [a objectAtIndex: 0];
            [_telnetView insertText: [e content]];
        }
    }
}

#pragma mark -
#pragma mark Accessor

- (NSArray *)sites {
    if (!_sites) {
        _sites = [[NSMutableArray alloc] init];
    }
    return [[_sites retain] autorelease];
}

- (unsigned)countOfSites {
    if (!_sites) {
        _sites = [[NSMutableArray alloc] init];
    }
    return [_sites count];
}

- (id)objectInSitesAtIndex:(unsigned)theIndex {
    if (!_sites) {
        _sites = [[NSMutableArray alloc] init];
    }
    return [_sites objectAtIndex:theIndex];
}

- (void)getSites:(id *)objsPtr range:(NSRange)range {
    if (!_sites) {
        _sites = [[NSMutableArray alloc] init];
    }
    [_sites getObjects:objsPtr range:range];
}

- (void)insertObject:(id)obj inSitesAtIndex:(unsigned)theIndex {
    if (!_sites) {
        _sites = [[NSMutableArray alloc] init];
    }
    [_sites insertObject:obj atIndex:theIndex];
}

- (void)removeObjectFromSitesAtIndex:(unsigned)theIndex {
    if (!_sites) {
        _sites = [[NSMutableArray alloc] init];
    }
    [_sites removeObjectAtIndex:theIndex];
}

- (void)replaceObjectInSitesAtIndex:(unsigned)theIndex withObject:(id)obj {
    if (!_sites) {
        _sites = [[NSMutableArray alloc] init];
    }
}

- (NSArray *)emoticons {
    if (!_emoticons) {
        _emoticons = [[NSMutableArray alloc] init];
    }
    return [[_emoticons retain] autorelease];
}

- (unsigned)countOfEmoticons {
    if (!_emoticons) {
        _emoticons = [[NSMutableArray alloc] init];
    }
    return [_emoticons count];
}

- (id)objectInEmoticonsAtIndex:(unsigned)theIndex {
    if (!_emoticons) {
        _emoticons = [[NSMutableArray alloc] init];
    }
    return [_emoticons objectAtIndex:theIndex];
}

- (void)getEmoticons:(id *)objsPtr range:(NSRange)range {
    if (!_emoticons) {
        _emoticons = [[NSMutableArray alloc] init];
    }
    [_emoticons getObjects:objsPtr range:range];
}

- (void)insertObject:(id)obj inEmoticonsAtIndex:(unsigned)theIndex {
    if (!_emoticons) {
        _emoticons = [[NSMutableArray alloc] init];
    }
    [_emoticons insertObject:obj atIndex:theIndex];
}

- (void)removeObjectFromEmoticonsAtIndex:(unsigned)theIndex {
    if (!_emoticons) {
        _emoticons = [[NSMutableArray alloc] init];
    }
    [_emoticons removeObjectAtIndex:theIndex];
}

- (void)replaceObjectInEmoticonsAtIndex:(unsigned)theIndex withObject:(id)obj {
    if (!_emoticons) {
        _emoticons = [[NSMutableArray alloc] init];
    }
    [_emoticons replaceObjectAtIndex:theIndex withObject:obj];
}

- (IBOutlet) view { return _telnetView; }
- (void) setView: (IBOutlet) o {}

#pragma mark -
#pragma mark Application Delegation
- (BOOL) validateMenuItem: (NSMenuItem *) item {
    SEL action = [item action];
    if ((action == @selector(addSites:) ||
         action == @selector(reconnect:) ||
         action == @selector(selectNextTab:) ||
         action == @selector(selectPrevTab:) )
        && [_telnetView numberOfTabViewItems] == 0) {
        return NO;
    } else if (action == @selector(setEncoding:) && [_telnetView numberOfTabViewItems] == 0) {
        return NO;
    }
    return YES;
}

- (BOOL) applicationShouldHandleReopen: (id) s hasVisibleWindows: (BOOL) b {
    [_mainWindow makeKeyAndOrderFront: self];
    return NO;
} 

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    int tabNumber = [_telnetView numberOfTabViewItems];
    int i;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"RestoreConnection"]) 
        [self saveLastConnections];
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey: @"ConfirmOnClose"]) 
        return YES;
    
    BOOL hasConnectedConnetion = NO;
    for (i = 0; i < tabNumber; i++) {
        id connection = [[_telnetView tabViewItemAtIndex: i] identifier];
        if ([connection connected]) 
            hasConnectedConnetion = YES;
    }
    if (!hasConnectedConnetion) return YES;
    NSBeginAlertSheet(NSLocalizedString(@"Are you sure you want to quit Nally?", @"Sheet Title"), 
                      NSLocalizedString(@"Quit", @"Default Button"), 
                      NSLocalizedString(@"Cancel", @"Cancel Button"), 
                      nil, 
                      _mainWindow, self, 
                      @selector(confirmSheetDidEnd:returnCode:contextInfo:), 
                      @selector(confirmSheetDidDismiss:returnCode:contextInfo:), nil, 
                      [NSString stringWithFormat: NSLocalizedString(@"There are %d tabs open in Nally. Do you want to quit anyway?", @"Sheet Message"),
                                tabNumber]);
    return NSTerminateLater;
}

- (void) confirmSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
    [[NSUserDefaults standardUserDefaults] synchronize];
    [NSApp replyToApplicationShouldTerminate: (returnCode == NSAlertDefaultReturn)];
}

- (void) confirmSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
    [[NSUserDefaults standardUserDefaults] synchronize];
    [NSApp replyToApplicationShouldTerminate: (returnCode == NSAlertDefaultReturn)];
}

#pragma mark -
#pragma mark Window Delegation

- (BOOL) windowShouldClose: (id) window {
    [_mainWindow orderOut: self];
    return NO;
}

- (BOOL) windowWillClose: (id) window {
//    [NSApp terminate: self];
//    NSLog(@"WILL");
    return NO;
}

- (void) windowDidBecomeKey: (NSNotification *) notification {
    [_closeWindowMenuItem setKeyEquivalentModifierMask: NSCommandKeyMask | NSShiftKeyMask];
    [_closeTabMenuItem setKeyEquivalent: @"w"];
}

- (void) windowDidResignKey: (NSNotification *) notification {
    [_closeWindowMenuItem setKeyEquivalentModifierMask: NSCommandKeyMask];
    [_closeTabMenuItem setKeyEquivalent: @""];
}

- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
	NSString *url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	// now you can create an NSURL and grab the necessary parts
    if ([[url lowercaseString] hasPrefix: @"bbs://"])
        url = [url substringFromIndex: 6];
    [_addressBar setStringValue: url];
    [self connect: _addressBar];
}

#pragma mark -
#pragma mark Tab Delegation

- (void) confirmTabSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
    if (returnCode == NSAlertDefaultReturn) {
        [[[(id)contextInfo identifier] terminal] setHasMessage: NO];
        [_telnetView removeTabViewItem: (id)contextInfo];
    }
}

- (BOOL)tabView:(NSTabView *)tabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem {
    if (![[tabViewItem identifier] connected]) return YES;
    if (![[NSUserDefaults standardUserDefaults] boolForKey: @"ConfirmOnClose"]) return YES;
    NSBeginAlertSheet(NSLocalizedString(@"Are you sure you want to close this tab?", @"Sheet Title"), 
                      NSLocalizedString(@"Close", @"Default Button"), 
                      NSLocalizedString(@"Cancel", @"Cancel Button"), 
                      nil, 
                      _mainWindow, self, 
                      @selector(confirmTabSheetDidEnd:returnCode:contextInfo:), 
                      NULL, 
                      tabViewItem, 
                      NSLocalizedString(@"The connection is still alive. If you close this tab, the connection will be lost. Do you want to close this tab anyway?", @"Sheet Message"));
    return NO;
}

- (void)tabView:(NSTabView *)tabView willCloseTabViewItem:(NSTabViewItem *)tabViewItem {
}

- (void)tabView:(NSTabView *)tabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem {
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    id identifier = [tabViewItem identifier];
    [_telnetView updateBackedImage];
    [_addressBar setStringValue: [identifier connectionAddress]];
    [_telnetView setNeedsDisplay: YES];
    [_mainWindow makeFirstResponder: _telnetView];
    [[[tabViewItem identifier] terminal] setHasMessage: NO];
    [self updateEncodingMenu];
    [_detectDoubleByteButton setState: [[[_telnetView frontMostConnection] site] detectDoubleByte] ? NSOnState : NSOffState];
    [_detectDoubleByteMenuItem setState: [[[_telnetView frontMostConnection] site] detectDoubleByte] ? NSOnState : NSOffState];
}

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    return YES;
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    id identifier = [tabViewItem identifier];
    [[identifier terminal] setAllDirty];
    [_telnetView clearSelection];
}

- (BOOL)tabView:(NSTabView*)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem fromTabBar:(PSMTabBarControl *)tabBarControl {
	return NO;
}

- (BOOL)tabView:(NSTabView*)aTabView shouldDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl {
	return YES;
}

- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl {
//    [self refreshTabLabelNumber: _telnetView];
}

- (NSImage *)tabView:(NSTabView *)aTabView imageForTabViewItem:(NSTabViewItem *)tabViewItem offset:(NSSize *)offset styleMask:(unsigned int *)styleMask {
    return nil;
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView {
    [self refreshTabLabelNumber: tabView];
}

- (void) refreshTabLabelNumber: (NSTabView *) tabView {
    int i, tabNumber;
    tabNumber = [tabView numberOfTabViewItems];
    for (i = 0; i < tabNumber; i++) {
        NSTabViewItem *item = [tabView tabViewItemAtIndex: i];
        [item setLabel: [NSString stringWithFormat: @"%d. %@", i + 1, [[item identifier] connectionName]]];
    }
    
}
@end
