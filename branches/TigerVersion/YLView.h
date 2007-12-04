//
//  YLView.h
//  MacBlueTelnet
//
//  Created by Yung-Luen Lan on 2006/6/9.
//  Copyright 2006 yllan. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CommonType.h"

@class YLTerminal;
@class YLTelnet;

@interface YLView : NSView {	
	int _fontWidth;
	int _fontHeight;
	
	NSImage *_backedImage;
	
	YLTerminal *_dataSource;
	YLTelnet *_telnet;
}

- (void) drawStringForRow: (int) r context: (CGContextRef) myCGContext ;
- (void) updateBackgroundForRow: (int) r from: (int) start to: (int) end ;
- (void)drawChar: (unichar) ch atPoint: (NSPoint) origin withAttribute: (attribute) attr ;
- (id)dataSource;
- (void)setDataSource:(id)value;
- (YLTelnet *)telnet;
- (void)setTelnet:(YLTelnet *)value;
- (void) extendBottom ;
- (void) extendTop ;
//- (void) clearScreen: (int) opt ;
@end