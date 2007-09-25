//
//  YLView.m
//  MacBlueTelnet
//
//  Created by Yung-Luen Lan on 2006/6/9.
//  Copyright 2006 yllan. All rights reserved.
//

#import "YLView.h"
#import "YLTerminal.h"
#import "encoding.h"
#import "YLTelnet.h"
#import "YLLGLobalConfig.h"

static YLLGlobalConfig *gConfig;
static int gRow;
static int gColumn;
static NSImage *gLeftImage;
static CGSize *gSingleAdvance;
static CGSize *gDoubleAdvance;

BOOL isSpecialSymbol(unichar ch) {
	if (ch == 0x25FC)  // ◼ BLACK SQUARE
		return YES;
	if (ch >= 0x2581 && ch <= 0x2588) // BLOCK ▁▂▃▄▅▆▇█
		return YES;
	if (ch >= 0x2589 && ch <= 0x258F) // BLOCK ▉▊▋▌▍▎▏
		return YES;
	if (ch >= 0x25E2 && ch <= 0x25E5) // TRIANGLE ◢◣◤◥
		return YES;
	return NO;
}

@implementation YLView

- (id)initWithFrame:(NSRect)frame {
	if (!gConfig) gConfig = [YLLGlobalConfig sharedInstance];
	gColumn = [gConfig column];
	gRow = [gConfig row];
	
	frame.size = NSMakeSize(gColumn * [gConfig cellWidth], gRow * [gConfig cellHeight]);
    self = [super initWithFrame: frame];
    if (self) {
		_fontWidth = [gConfig cellWidth];
		_fontHeight = [gConfig cellHeight];
		
		
		_backedImage = [[NSImage alloc] initWithSize: frame.size];
		[_backedImage setFlipped: NO];
		[_backedImage lockFocus];
		[[gConfig colorAtIndex: 9 hilite: NO] set];
		[NSBezierPath fillRect: NSMakeRect(0, 0, frame.size.width, frame.size.height)];
		[_backedImage unlockFocus];

		if (!gLeftImage) {
			gLeftImage = [[NSImage alloc] initWithSize: NSMakeSize(_fontWidth, _fontHeight)];
			[gLeftImage setFlipped: YES];			
		}
		gSingleAdvance = (CGSize *) malloc(sizeof(CGSize) * gColumn);
		gDoubleAdvance = (CGSize *) malloc(sizeof(CGSize) * gColumn);
		int i;
		for (i = 0; i < gColumn; i++) {
			gSingleAdvance[i] = CGSizeMake(_fontWidth * 1.0, 0.0);
			gDoubleAdvance[i] = CGSizeMake(_fontWidth * 2.0, 0.0);
		}
		
    }
    return self;
}

- (void) dealloc {
	[_backedImage release];
	[super dealloc];
}

#pragma mark -
#pragma mark Event Handling
- (void) mouseDown: (NSEvent *) e {
	NSLog(@"%X %d %d", [_dataSource charAtRow: 1 column: 78], [_dataSource isDoubleByteAtRow: 1 column: 78], [_dataSource isDoubleByteAtRow: 1 column: 79]);
}

- (void) keyDown: (NSEvent *) e {
	unichar c = [[e charactersIgnoringModifiers] characterAtIndex: 0];
	unsigned char arrow[3] = {0x1B, 0x4F, 0x00};
	
	if (c == NSUpArrowFunctionKey) arrow[2] = 'A';
	if (c == NSDownArrowFunctionKey) arrow[2] = 'B';
	if (c == NSRightArrowFunctionKey) arrow[2] = 'C';
	if (c == NSLeftArrowFunctionKey) arrow[2] = 'D';
	if (c == NSUpArrowFunctionKey || c == NSDownArrowFunctionKey || c == NSRightArrowFunctionKey || c == NSLeftArrowFunctionKey) {
		[_telnet sendBytes: arrow length: 3];
		return;
	}
	
	unsigned char ch = (unsigned char) c;
	[_telnet sendBytes: &ch length: 1];		
}

#pragma mark -
#pragma mark Drawing

- (NSRect) cellRectForRect: (NSRect) r {
	int originx = r.origin.x / _fontWidth;
	int originy = r.origin.y / _fontHeight;
	int width = ((r.size.width + r.origin.x) / _fontWidth) - originx + 1;
	int height = ((r.size.height + r.origin.y) / _fontHeight) - originy + 1;
	return NSMakeRect(originx, originy, width, height);
}

- (void)drawRect:(NSRect)rect {
	NSRect imgRect = rect;
	imgRect.origin.y = (_fontHeight * gRow) - rect.origin.y - rect.size.height;
	[_backedImage compositeToPoint: rect.origin
						  fromRect: rect
						 operation: NSCompositeCopy];
//	int x, y;
//	[[NSColor whiteColor] set];
//	for (y = 0; y < gRow; y++) 
//		[NSBezierPath strokeLineFromPoint: NSMakePoint(0, y * _fontHeight + 0.5) toPoint: NSMakePoint(gColumn * _fontWidth, y * _fontHeight + 0.5)];
//	for (x = 0; x < gColumn; x++) 
//		[NSBezierPath strokeLineFromPoint: NSMakePoint(x * _fontWidth + 0.5, 0) toPoint: NSMakePoint(x * _fontWidth + 0.5, gRow * _fontHeight)];	

}

- (void) clearScreen: (int) opt atRow: (int) r column: (int) c {
	
}

/* 
	Extend Bottom:
 
		AAAAAAAAAAA			BBBBBBBBBBB
		BBBBBBBBBBB			CCCCCCCCCCC
		CCCCCCCCCCC   ->	DDDDDDDDDDD
		DDDDDDDDDDD			...........
 
 */
- (void) extendBottom {
	[_backedImage lockFocus];
	[_backedImage compositeToPoint: NSMakePoint(0, _fontHeight) 
						  fromRect: NSMakeRect(0, 0, gColumn * _fontWidth, (gRow - 1) * _fontHeight) 
						 operation: NSCompositeCopy];

	[gConfig->_colorTable[0][NUM_COLOR - 1] set];
	[NSBezierPath fillRect: NSMakeRect(0, 0, gColumn * _fontWidth, _fontHeight)];
	[_backedImage unlockFocus];
	
	[self setNeedsDisplay: YES];
}


/* 
	Extend Top:
 
		AAAAAAAAAAA			...........
		BBBBBBBBBBB			AAAAAAAAAAA
		CCCCCCCCCCC   ->	BBBBBBBBBBB
		DDDDDDDDDDD			CCCCCCCCCCC
 */
- (void) extendTop {
	[_backedImage lockFocus];
	[_backedImage compositeToPoint: NSMakePoint(0, 0) 
						  fromRect: NSMakeRect(0, _fontHeight, gColumn * _fontWidth, (gRow - 1) * _fontHeight) 
						 operation: NSCompositeCopy];
	
	[gConfig->_colorTable[0][NUM_COLOR - 1] set];
	[NSBezierPath fillRect: NSMakeRect(0, (gRow - 1) * _fontHeight, gColumn * _fontWidth, _fontHeight)];
	[_backedImage unlockFocus];
	
	[self setNeedsDisplay: YES];
}

- (void) update {
	int x, y;
	[_backedImage lockFocus];
	CGContextRef myCGContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	puts("update");
	
	/* Draw Background */
	for (y = 0; y < gRow; y++) {
		for (x = 0; x < gColumn; x++) {
			if ([_dataSource isDirtyAtRow: y column: x]) {
				int startx = x;
				for (; x < gColumn && [_dataSource isDirtyAtRow:y column:x]; x++) ;
				[self updateBackgroundForRow: y from: startx to: x];
			}
		}
	}
	CGContextSaveGState(myCGContext);
	CGContextSetShouldSmoothFonts(myCGContext, NO);

	/* Draw String row by row */
	for (y = 0; y < gRow; y++) {
		[_dataSource updateDoubleByteStateForRow: y];
		[self drawStringForRow: y context: myCGContext];
	}		
	CGContextRestoreGState(myCGContext);
	
	for (y = 0; y < gRow; y++) {
		for (x = 0; x < gColumn; x++) {
			[_dataSource setDirty: NO atRow: y column: x];
		}
	}

	[_backedImage unlockFocus];
}

- (void) drawStringForRow: (int) r context: (CGContextRef) myCGContext {
	int i, c, x;
	int start, end;
	unichar textBuf[gColumn];
	BOOL isDoubleByte[gColumn];
	int bufIndex[gColumn];
	int runLength[gColumn];
	CGPoint position[gColumn];
	int bufLength = 0;

	cell *currRow = [_dataSource cellsOfRow: r];

	for (i = 0; i < gColumn; i++) 
		isDoubleByte[i] = textBuf[i] = runLength[i] = 0;

	for (x = 0; x < gColumn && ![_dataSource isDirtyAtRow: r column: x]; x++) ;
	start = x;
	if (start == gColumn) return;
	
	for (x = start; x < gColumn; x++) {
		if (![_dataSource isDirtyAtRow: r column: x]) continue;
		end = x;
		int db = (currRow + x)->attr.f.doubleByte;

		if (db == 0) {
			isDoubleByte[bufLength] = NO;
			textBuf[bufLength] = 0x0000 + (currRow + x)->byte;
			bufIndex[bufLength] = x;
			position[bufLength] = CGPointMake(x * _fontWidth + 1.0, (gRow - 1 - r) * _fontHeight + CTFontGetDescent(gConfig->_eCTFont) + 2.0);
			bufLength++;
		} else if (db == 1) {
			continue;
		} else if (db == 2) {
			unichar ch = B2U[(((currRow + x - 1)->byte) << 8) + ((currRow + x)->byte) - 0x8000];
			if (isSpecialSymbol(ch)) {
				[self drawSpecialSymbol: ch forRow: r column: (x - 1) leftAttribute: (currRow + x - 1)->attr rightAttribute: (currRow + x)->attr];
				isDoubleByte[bufLength] = NO;
				isDoubleByte[bufLength + 1] = NO;
				textBuf[bufLength] = 0x3000;
				position[bufLength] = CGPointMake((x - 1) * _fontWidth + 2.0, (gRow - 1 - r) * _fontHeight + CTFontGetDescent(gConfig->_cCTFont) + 1.0);
				bufIndex[bufLength] = x;
				bufLength ++;
			} else {
				isDoubleByte[bufLength] = YES;
				textBuf[bufLength] = ch;
				bufIndex[bufLength] = x;
				position[bufLength] = CGPointMake((x - 1) * _fontWidth + 2.0, (gRow - 1 - r) * _fontHeight + CTFontGetDescent(gConfig->_cCTFont) + 2.0);
				bufLength++;
			}
			if (x == start)
				[self setNeedsDisplayInRect: NSMakeRect((x - 1) * _fontWidth, (gRow - 1 - r) * _fontHeight, _fontWidth, _fontHeight)];				
		}
	}
	
	CFStringRef str = CFStringCreateWithCharacters(kCFAllocatorDefault, textBuf, bufLength);
	CFAttributedStringRef attributedString = CFAttributedStringCreate(kCFAllocatorDefault, str, NULL);
	CFMutableAttributedStringRef mutableAttributedString = CFAttributedStringCreateMutableCopy(kCFAllocatorDefault, 0, attributedString);
	CFRelease(str);
	CFRelease(attributedString);
		
	/* Run-length of the style */
	c = 0;
	while (c < bufLength) {
		int location = c;
		int length = 0;
		BOOL db = isDoubleByte[c];

		attribute currAttr, lastAttr = (currRow + bufIndex[c])->attr;
		for (; c < bufLength; c++) {
			currAttr = (currRow + bufIndex[c])->attr;
			if (currAttr.v != lastAttr.v || isDoubleByte[c] != db) break;
		}
		length = c - location;
		
		CFDictionaryRef attr;
		if (db) 
			attr = gConfig->_cCTAttribute[lastAttr.f.bold][lastAttr.f.reverse ? lastAttr.f.bgColor : lastAttr.f.fgColor];
		else
			attr = gConfig->_eCTAttribute[lastAttr.f.bold][lastAttr.f.reverse ? lastAttr.f.bgColor : lastAttr.f.fgColor];
		
		CFAttributedStringSetAttributes(mutableAttributedString, CFRangeMake(location, length), attr, YES);
	}
	
	CTLineRef line = CTLineCreateWithAttributedString(mutableAttributedString);
	CFRelease(mutableAttributedString);
	
	CFIndex glyphCount = CTLineGetGlyphCount(line);
	if (glyphCount == 0) {
		CFRelease(line);
		return;
	}
	
	CFArrayRef runArray = CTLineGetGlyphRuns(line);
	CFIndex runCount = CFArrayGetCount(runArray);
	CFIndex glyphOffset = 0;
	
	CFIndex runIndex = 0;

	for (; runIndex < runCount; runIndex++) {
		CTRunRef run = (CTRunRef) CFArrayGetValueAtIndex(runArray,  runIndex);
		CFIndex runGlyphCount = CTRunGetGlyphCount(run);
		CFIndex runGlyphIndex = 0;

		CFDictionaryRef attrDict = CTRunGetAttributes(run);
		CTFontRef runFont = (CTFontRef)CFDictionaryGetValue(attrDict,  kCTFontAttributeName);
		CGFontRef cgFont = CTFontCopyGraphicsFont(runFont, NULL);
		NSColor *runColor = (NSColor *) CFDictionaryGetValue(attrDict, kCTForegroundColorAttributeName);
		
		CGContextSetFont(myCGContext, cgFont);
		CGContextSetFontSize(myCGContext, CTFontGetSize(runFont));
		CGContextSetRGBFillColor(myCGContext, 
								 [runColor redComponent], 
								 [runColor greenComponent], 
								 [runColor blueComponent], 
								 1.0);
		
		CGGlyph glyph[gColumn];
		CFRange glyphRange = CFRangeMake(runGlyphIndex, runGlyphCount);
		CTRunGetGlyphs(run, glyphRange, glyph);

		CGAffineTransform textMatrix = CTRunGetTextMatrix(run);
		textMatrix.tx = position[glyphOffset].x;
		textMatrix.ty = position[glyphOffset].y;
		CGContextSetTextMatrix(myCGContext, textMatrix);
		
		CGContextShowGlyphsWithAdvances(myCGContext, glyph, isDoubleByte[glyphOffset] ? gDoubleAdvance : gSingleAdvance, runGlyphCount);
		
/*		for (; runGlyphIndex < runGlyphCount; runGlyphIndex++) {
			CFRange glyphRange = CFRangeMake(runGlyphIndex, 1);
			CGGlyph glyph;
			CTRunGetGlyphs(run, glyphRange, &glyph);
			CGContextShowGlyphsAtPoint(myCGContext, position[runGlyphIndex + glyphOffset].x, position[runGlyphIndex + glyphOffset].y, &glyph, 1);
		}*/
		glyphOffset += runGlyphCount;
		CFRelease(cgFont);
	}
	
	CFRelease(line);
}

- (void) updateBackgroundForRow: (int) r from: (int) start to: (int) end {
	int c;
	cell *currRow = [_dataSource cellsOfRow: r];
	NSRect rowRect = NSMakeRect(start * _fontWidth, (gRow - 1 - r) * _fontHeight, (end - start) * _fontWidth, _fontHeight);

	attribute currAttr, lastAttr = (currRow + start)->attr;
	int length = 0;
	unsigned int currentBackgroundColor;
	unsigned int lastBackgroundColor = lastAttr.f.reverse ? lastAttr.f.fgColor : lastAttr.f.bgColor;
	
	/* TODO: optimize the number of fillRect method. */
	/* 
		for example: 
		
		  BBBBBBBBBBBWWWWWWWWWWBBBBBBBBBBB
		
		currently, we draw each color segment one by one, like this:
		
		1. BBBBBBBBBBB
		2. BBBBBBBBBBBWWWWWWWWWW
		3. BBBBBBBBBBBWWWWWWWWWWBBBBBBBBBBB
		
		but we can use only two fillRect:
	 
		1. BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
		2. BBBBBBBBBBBWWWWWWWWWWBBBBBBBBBBB
	 
		If further optimization of background drawing is needed, consider the 2D reduction.
	 */
	for (c = start; c <= end; c++) {
		if (c < end) {
			currAttr = (currRow + c)->attr;
			currentBackgroundColor = currAttr.f.reverse ? currAttr.f.fgColor : currAttr.f.bgColor;
		}
		
		if (currentBackgroundColor != lastBackgroundColor || c == end) {
			/* Draw Background */
			NSRect rect = NSMakeRect((c - length) * _fontWidth, (gRow - 1 - r) * _fontHeight,
								  _fontWidth * length, _fontHeight);
			[[gConfig colorAtIndex: lastBackgroundColor hilite: NO] set];
			[NSBezierPath fillRect: rect];
			
			/* finish this segment */
			length = 1;
			lastAttr.v = currAttr.v;
			lastBackgroundColor = currentBackgroundColor;
		} else {
			length++;
		}
	}
	
	[self setNeedsDisplayInRect: rowRect];
}

- (void) drawSpecialSymbol: (unichar) ch forRow: (int) r column: (int) c leftAttribute: (attribute) attr1 rightAttribute: (attribute) attr2 {
	int colorIndex1 = attr1.f.reverse ? attr1.f.bgColor : attr1.f.fgColor;
	int colorIndex2 = attr2.f.reverse ? attr2.f.bgColor : attr2.f.fgColor;
	NSPoint origin = NSMakePoint(c * _fontWidth, (gRow - 1 - r) * _fontHeight);

	NSAffineTransform *xform = [NSAffineTransform transform]; 
	[xform translateXBy: origin.x yBy: origin.y];
	[xform concat];
	
	if (YES) {//colorIndex1 == colorIndex2 && attr1.f.bold == attr2.f.bold) {
		NSColor *color = [gConfig colorAtIndex: colorIndex1 hilite: attr1.f.bold];
		
		if (ch == 0x25FC) { // ◼ BLACK SQUARE
			
		} else if (ch >= 0x2581 && ch <= 0x2588) { // BLOCK ▁▂▃▄▅▆▇█
			NSRect rect = NSMakeRect(0.0, 0.0, 2 * _fontWidth, _fontHeight * (ch - 0x2580) / 8);
			[color set];
			[NSBezierPath fillRect: rect];
		} else if (ch >= 0x2589 && ch <= 0x258F) { // BLOCK ▉▊▋▌▍▎▏
			NSRect rect = NSMakeRect(0.0, 0.0, 2 * _fontWidth * (0x2590 - ch) / 8, _fontHeight);
			[color set];
			[NSBezierPath fillRect: rect];		
		} else if (ch >= 0x25E2 && ch <= 0x25E5) { // TRIANGLE ◢◣◤◥
			NSPoint pts[4] = {	
				NSMakePoint(2 * _fontWidth, _fontHeight), 
				NSMakePoint(2 * _fontWidth, 0.0), 
				NSMakePoint(0.0, 0.0), 
				NSMakePoint(0.0, _fontHeight)
			};
			int base = ch - 0x25E2;
			NSBezierPath *bp = [[NSBezierPath alloc] init];
			[bp moveToPoint: pts[base]];
			int i;
			for (i = 1; i < 3; i++)	
				[bp lineToPoint: pts[(base + i) % 4]];
			[bp closePath];
			[color set];
			[bp fill];
			[bp release];
		} else if (ch == 0x0) {
		}
	} else { // double color
		
	}
	[xform invert];
	[xform concat];
}


#pragma mark -
#pragma mark Override

- (BOOL) isFlipped {
	return NO;
}

- (BOOL) isOpaque {
	return YES;
}

- (BOOL) acceptsFirstResponder {
	return YES;
}

#pragma mark -
#pragma mark Accessor

- (id)dataSource {
    return [[_dataSource retain] autorelease];
}

- (void)setDataSource:(id)value {
    if (_dataSource != value) {
        [_dataSource release];
        _dataSource = [value retain];
    }
}

- (YLTelnet *)telnet {
    return [[_telnet retain] autorelease];
}

- (void)setTelnet:(YLTelnet *)value {
    if (_telnet != value) {
        [_telnet release];
        _telnet = [value retain];
    }
}

@end
