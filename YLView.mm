//
//  YLView.m
//  MacBlueTelnet
//
//  Created by Yung-Luen Lan on 2006/6/9.
//  Copyright 2006 yllan.org. All rights reserved.
//

#import "YLView.h"
#import "YLTerminal.h"
#import "YLTelnet.h"
#import "YLLGLobalConfig.h"
#import "YLMarkedTextView.h"
#import "YLContextualMenuManager.h"

#include <deque>
#include "encoding.h"

using namespace std;

static YLLGlobalConfig *gConfig;
static int gRow;
static int gColumn;
static NSImage *gLeftImage;
static CGSize *gSingleAdvance;
static CGSize *gDoubleAdvance;
static NSCharacterSet *gBopomofoCharSet = nil;
static NSCursor *gMoveCursor = nil;

NSString *ANSIColorPBoardType = @"ANSIColorPBoardType";

static NSRect gSymbolBlackSquareRect;
static NSRect gSymbolBlackSquareRect1;
static NSRect gSymbolBlackSquareRect2;
static NSRect gSymbolLowerBlockRect[8];
static NSRect gSymbolLowerBlockRect1[8];
static NSRect gSymbolLowerBlockRect2[8];
static NSRect gSymbolLeftBlockRect[7];
static NSRect gSymbolLeftBlockRect1[7];
static NSRect gSymbolLeftBlockRect2[7];
static NSBezierPath *gSymbolTrianglePath[4];
static NSBezierPath *gSymbolTrianglePath1[4];
static NSBezierPath *gSymbolTrianglePath2[4];

BOOL isEnglishNumberAlphabet(unsigned char c) {
    return ('0' <= c && c <= '9') || ('A' <= c && c <= 'Z') || ('a' <= c && c <= 'z');
}

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

BOOL isHiddenAttribute(attribute a) {
    return (!a.f.bold && ((a.f.fgColor == a.f.bgColor) ||
                          (a.f.fgColor == 0 && a.f.bgColor == NUM_COLOR - 1))); 
}

BOOL isBlinkCell(cell c) {
    if (c.attr.f.blink && (c.attr.f.doubleByte != 0 || (c.byte != ' ' && c.byte != '\0')))
        return YES;
    return NO;
}

@implementation YLView

+ (void) initialize {
    NSImage *cursorImage = [[NSImage alloc] initWithSize: NSMakeSize(11.0, 20.0)];
    [cursorImage lockFocus];
    [[NSColor clearColor] set];
    [NSBezierPath fillRect: NSMakeRect(0, 0, 11, 20)];
    [[NSColor whiteColor] set];
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setLineCapStyle: NSRoundLineCapStyle];
    [path moveToPoint: NSMakePoint(1.5, 1.5)];
    [path lineToPoint: NSMakePoint(2.5, 1.5)];
    [path lineToPoint: NSMakePoint(5.5, 4.5)];
    [path lineToPoint: NSMakePoint(8.5, 1.5)];
    [path lineToPoint: NSMakePoint(9.5, 1.5)];
    [path moveToPoint: NSMakePoint(5.5, 4.5)];
    [path lineToPoint: NSMakePoint(5.5, 15.5)];
    [path lineToPoint: NSMakePoint(2.5, 18.5)];
    [path lineToPoint: NSMakePoint(1.5, 18.5)];
    [path moveToPoint: NSMakePoint(5.5, 15.5)];
    [path lineToPoint: NSMakePoint(8.5, 18.5)];
    [path lineToPoint: NSMakePoint(9.5, 18.5)];
    [path moveToPoint: NSMakePoint(3.5, 9.5)];
    [path lineToPoint: NSMakePoint(7.5, 9.5)];
    [path setLineWidth: 3];
    [path stroke];
    [path setLineWidth: 1];
    [[NSColor blackColor] set];
    [path stroke];
        //		[NSBezierPath strokeRect: NSMakeRect(0.5, 0.5, 9, 19)];
    [cursorImage unlockFocus];
    gMoveCursor = [[NSCursor alloc] initWithImage: cursorImage hotSpot: NSMakePoint(5.5, 9.5)];
    [cursorImage release];
    
    gBopomofoCharSet = [[NSCharacterSet characterSetWithCharactersInString: 
                         [NSString stringWithUTF8String: "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙㄧㄨㄩㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ【】、"]] retain];

}

- (void) createSymbolPath {
	int i = 0;
	gSymbolBlackSquareRect = NSMakeRect(1.0, 1.0, _fontWidth * 2 - 2, _fontHeight - 2);
	gSymbolBlackSquareRect1 = NSMakeRect(1.0, 1.0, _fontWidth - 1, _fontHeight - 2); 
	gSymbolBlackSquareRect2 = NSMakeRect(_fontWidth, 1.0, _fontWidth - 1, _fontHeight - 2);
	
	for (i = 0; i < 8; i++) {
		gSymbolLowerBlockRect[i] = NSMakeRect(0.0, 0.0, _fontWidth * 2, _fontHeight * (i + 1) / 8);
        gSymbolLowerBlockRect1[i] = NSMakeRect(0.0, 0.0, _fontWidth, _fontHeight * (i + 1) / 8);
        gSymbolLowerBlockRect2[i] = NSMakeRect(_fontWidth, 0.0, _fontWidth, _fontHeight * (i + 1) / 8);
	}
    
    for (i = 0; i < 7; i++) {
        gSymbolLeftBlockRect[i] = NSMakeRect(0.0, 0.0, _fontWidth * (7 - i) / 4, _fontHeight);
        gSymbolLeftBlockRect1[i] = NSMakeRect(0.0, 0.0, (7 - i >= 4) ? _fontWidth : (_fontWidth * (7 - i) / 4), _fontHeight);
        gSymbolLeftBlockRect2[i] = NSMakeRect(_fontWidth, 0.0, (7 - i <= 4) ? 0.0 : (_fontWidth * (3 - i) / 4), _fontHeight);
    }
    
    NSPoint pts[6] = {
        NSMakePoint(_fontWidth, 0.0),
        NSMakePoint(0.0, 0.0),
        NSMakePoint(0.0, _fontHeight),
        NSMakePoint(_fontWidth, _fontHeight),
        NSMakePoint(_fontWidth * 2, _fontHeight),
        NSMakePoint(_fontWidth * 2, 0.0),
    };
    int triangleIndex[4][3] = { {1, 4, 5}, {1, 2, 5}, {1, 2, 4}, {2, 4, 5} };

    int triangleIndex1[4][3] = { {0, 1, -1}, {0, 1, 2}, {1, 2, 3}, {2, 3, -1} };
    int triangleIndex2[4][3] = { {4, 5, 0}, {5, 0, -1}, {3, 4, -1}, {3, 4, 5} };
    
    int base = 0;
    for (base = 0; base < 4; base++) {
        if (gSymbolTrianglePath[base]) 
            [gSymbolTrianglePath[base] release];
        gSymbolTrianglePath[base] = [[NSBezierPath alloc] init];
        [gSymbolTrianglePath[base] moveToPoint: pts[triangleIndex[base][0]]];
        for (i = 1; i < 3; i ++)
            [gSymbolTrianglePath[base] lineToPoint: pts[triangleIndex[base][i]]];
        [gSymbolTrianglePath[base] closePath];
        
        if (gSymbolTrianglePath1[base])
            [gSymbolTrianglePath1[base] release];
        gSymbolTrianglePath1[base] = [[NSBezierPath alloc] init];
        [gSymbolTrianglePath1[base] moveToPoint: NSMakePoint(_fontWidth, _fontHeight / 2)];
        for (i = 0; i < 3 && triangleIndex1[base][i] >= 0; i++)
            [gSymbolTrianglePath1[base] lineToPoint: pts[triangleIndex1[base][i]]];
        [gSymbolTrianglePath1[base] closePath];
        
        if (gSymbolTrianglePath2[base])
            [gSymbolTrianglePath2[base] release];
        gSymbolTrianglePath2[base] = [[NSBezierPath alloc] init];
        [gSymbolTrianglePath2[base] moveToPoint: NSMakePoint(_fontWidth, _fontHeight / 2)];
        for (i = 0; i < 3 && triangleIndex2[base][i] >= 0; i++)
            [gSymbolTrianglePath2[base] lineToPoint: pts[triangleIndex2[base][i]]];
        [gSymbolTrianglePath2[base] closePath];
    }
}

- (id)initWithFrame:(NSRect)frame {
	if (!gConfig) gConfig = [YLLGlobalConfig sharedInstance];
	gColumn = [gConfig column];
	gRow = [gConfig row];	
	
	frame.size = NSMakeSize(gColumn * [gConfig cellWidth], gRow * [gConfig cellHeight]);
    self = [super initWithFrame: frame];
    if (self) {
		_fontWidth = [gConfig cellWidth];
		_fontHeight = [gConfig cellHeight];
        [self createSymbolPath];
		
        _selectionLength = 0;
        _selectionLocation = 0;
        
		_backedImage = [[NSImage alloc] initWithSize: frame.size];
		[_backedImage setFlipped: NO];
		[_backedImage lockFocus];
		[[gConfig colorAtIndex: 9 hilite: NO] set];
		[NSBezierPath fillRect: NSMakeRect(0, 0, frame.size.width, frame.size.height)];
		[_backedImage unlockFocus];

		if (!gLeftImage) 
			gLeftImage = [[NSImage alloc] initWithSize: NSMakeSize(_fontWidth, _fontHeight)];			
		
		gSingleAdvance = (CGSize *) malloc(sizeof(CGSize) * gColumn);
		gDoubleAdvance = (CGSize *) malloc(sizeof(CGSize) * gColumn);
		int i;
		for (i = 0; i < gColumn; i++) {
			gSingleAdvance[i] = CGSizeMake(_fontWidth * 1.0, 0.0);
			gDoubleAdvance[i] = CGSizeMake(_fontWidth * 2.0, 0.0);
		}
		_markedText = nil;
		_selectedRange = NSMakeRange(NSNotFound, 0);
		_markedRange = NSMakeRange(NSNotFound, 0);
		[_textField setHidden: YES];
    }
    return self;
}

- (void) dealloc {
	[_backedImage release];
	[super dealloc];
}

#pragma mark -
#pragma mark Actions

- (void) copy: (id) sender {
    if (![self connected]) return;
    if (_selectionLength == 0) return;

    NSString *s = [self selectedPlainString];
    
    /* Color copy */
    int location, length;
    if (_selectionLength >= 0) {
        location = _selectionLocation;
        length = _selectionLength;
    } else {
        location = _selectionLocation + _selectionLength;
        length = 0 - (int)_selectionLength;
    }

    cell *buffer = (cell *) malloc((length + gRow + gColumn + 1) * sizeof(cell));
    int i;
    int bufferLength = 0;
    id ds = [self dataSource];

    for (i = 0; i < length; i++) {
        int index = location + i;
        cell *currentRow = [ds cellsOfRow: index / gColumn];
        
        if ((index % gColumn == 0) && (index != location)) {
            buffer[bufferLength].byte = '\n';
            buffer[bufferLength].attr = buffer[bufferLength - 1].attr;
            bufferLength++;
        }
        buffer[bufferLength] = currentRow[index % gColumn];
        if (buffer[bufferLength].byte == '\0') 
            buffer[bufferLength].byte = ' ';
        /* Clear non-ANSI related properties. */
        buffer[bufferLength].attr.f.doubleByte = 0;
        buffer[bufferLength].attr.f.url = 0;
        buffer[bufferLength].attr.f.nothing = 0;
        
        bufferLength++;
    }
    
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSMutableArray *types = [NSMutableArray arrayWithObjects: NSStringPboardType, ANSIColorPBoardType, nil];
    if (!s) s = @"";
    [pb declareTypes: types owner: self];
    [pb setString: s forType: NSStringPboardType];
    [pb setData: [NSData dataWithBytes: buffer length: bufferLength * sizeof(cell)] forType: ANSIColorPBoardType];
    free(buffer);
}

- (void) pasteColor: (id) sender {
    if (![self connected]) return;
    
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSArray *types = [pb types];
	if (![types containsObject: ANSIColorPBoardType]) {
		[self paste: self];
		return;
	}
	
	cell *buffer = (cell *) [[pb dataForType: ANSIColorPBoardType] bytes];
	int bufferLength = [[pb dataForType: ANSIColorPBoardType] length] / sizeof(cell);
		
	attribute defaultANSI;
	defaultANSI.f.bgColor = 0;
	defaultANSI.f.fgColor = 7;
	defaultANSI.f.blink = 0;
	defaultANSI.f.bold = 0;
	defaultANSI.f.underline = 0;
	defaultANSI.f.reverse = 0;
	
	attribute previousANSI = defaultANSI;
	NSMutableData *writeBuffer = [NSMutableData data];
	
	int i;
	for (i = 0; i < bufferLength; i++) {
		if (buffer[i].byte == '\n' ) {
			previousANSI = defaultANSI;
			[writeBuffer appendBytes: "\x15[m\n\r" length: 5];
			continue;
		}
		
		attribute currentANSI = buffer[i].attr;
		
		/* Unchanged */
		if ((currentANSI.f.blink == previousANSI.f.blink) &&
			(currentANSI.f.bold == previousANSI.f.bold) &&
			(currentANSI.f.underline == previousANSI.f.underline) &&
			(currentANSI.f.reverse == previousANSI.f.reverse) &&
			(currentANSI.f.bgColor == previousANSI.f.bgColor) &&
			(currentANSI.f.fgColor == previousANSI.f.fgColor)) {
			[writeBuffer appendBytes: &(buffer[i].byte) length: 1];
			continue;
		}
		
		/* Clear */
		if ((currentANSI.f.blink == 0 && previousANSI.f.blink == 1) ||
			(currentANSI.f.bold == 0 && previousANSI.f.bold == 1) ||
			(currentANSI.f.underline == 0 && previousANSI.f.underline == 1) ||
			(currentANSI.f.reverse == 0 && previousANSI.f.reverse == 1)) {
			char tmp[100];
			strcpy(tmp, "\x15[0");
			if (currentANSI.f.blink == 1) strcat(tmp, ";5");
			if (currentANSI.f.bold == 1) strcat(tmp, ";1");
			if (currentANSI.f.underline == 1) strcat(tmp, ";4");
			if (currentANSI.f.reverse == 1) strcat(tmp, ";7");
			if (currentANSI.f.fgColor != 7) sprintf(tmp, "%s;%d", tmp, currentANSI.f.fgColor + 30);
			if (currentANSI.f.bgColor != 0) sprintf(tmp, "%s;%d", tmp, currentANSI.f.bgColor + 40);
			strcat(tmp, "m");
			[writeBuffer appendBytes: tmp length: strlen(tmp)];
			[writeBuffer appendBytes: &(buffer[i].byte) length: 1];
			previousANSI = currentANSI;
			continue;
		}
		
		/* Add attribute */
		char tmp[100];
		strcpy(tmp, "\x15[");
		
		if (currentANSI.f.blink == 1 && previousANSI.f.blink == 0) strcat(tmp, "5;");
		if (currentANSI.f.bold == 1 && previousANSI.f.bold == 0) strcat(tmp, "1;");
		if (currentANSI.f.underline == 1 && previousANSI.f.underline == 0) strcat(tmp, "4;");
		if (currentANSI.f.reverse == 1 && previousANSI.f.reverse == 0) strcat(tmp, "7;");
		if (currentANSI.f.fgColor != previousANSI.f.fgColor) sprintf(tmp, "%s%d;", tmp, currentANSI.f.fgColor + 30);
		if (currentANSI.f.bgColor != previousANSI.f.bgColor) sprintf(tmp, "%s%d;", tmp, currentANSI.f.bgColor + 40);
		tmp[strlen(tmp) - 1] = 'm';
		sprintf(tmp, "%s%c", tmp, buffer[i].byte);
		[writeBuffer appendBytes: tmp length: strlen(tmp)];
		previousANSI = currentANSI;
		continue;
	}
	[writeBuffer appendBytes: "\x15[m" length: 3];
    [[self telnet] sendMessage: writeBuffer];
}

- (void) paste: (id) sender {
    if (![self connected]) return;
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSArray *types = [pb types];
    if ([types containsObject: NSStringPboardType]) {
        NSString *str = [pb stringForType: NSStringPboardType];
        [self insertText: str];
    }
}

- (void) pasteWrap: (id) sender {
    if (![self connected]) return;
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSArray *types = [pb types];
    if (![types containsObject: NSStringPboardType]) return;
    
    NSString *str = [pb stringForType: NSStringPboardType];
    int i, j, LINE_WIDTH = 66, LPADDING = 4;
    deque<unichar> word;
    deque<unichar> text;
    int word_width = 0, line_width = 0;
    text.push_back(0x000d);
    for (i = 0; i < LPADDING; i++)
        text.push_back(0x0020);
    line_width = LPADDING;
    for (i = 0; i < [str length]; i++) {
        unichar c = [str characterAtIndex: i];
        if (c == 0x0020 || c == 0x0009) { // space
            for (j = 0; j < word.size(); j++)
                text.push_back(word[j]);
            word.clear();
            line_width += word_width;
            word_width = 0;
            if (line_width >= LINE_WIDTH + LPADDING) {
                text.push_back(0x000d);
                for (j = 0; j < LPADDING; j++)
                    text.push_back(0x0020);
                line_width = LPADDING;
            }
            int repeat = (c == 0x0020) ? 1 : 4;
            for (j = 0; j < repeat ; j++)
                text.push_back(0x0020);
            line_width += repeat;
        } else if (c == 0x000a || c == 0x000d) {
            for (j = 0; j < word.size(); j++)
                text.push_back(word[j]);
            word.clear();
            text.push_back(0x000d);
//            text.push_back(0x000d);
            for (j = 0; j < LPADDING; j++)
                text.push_back(0x0020);
            line_width = LPADDING;
            word_width = 0;
        } else if (c > 0x0020 && c < 0x0100) {
            word.push_back(c);
            word_width++;
            if (c >= 0x0080) word_width++;
        } else if (c >= 0x1000){
            for (j = 0; j < word.size(); j++)
                text.push_back(word[j]);
            word.clear();
            line_width += word_width;
            word_width = 0;
            if (line_width >= LINE_WIDTH + LPADDING) {
                text.push_back(0x000d);
                for (j = 0; j < LPADDING; j++)
                    text.push_back(0x0020);
                line_width = LPADDING;
            }
            text.push_back(c);
            line_width += 2;
        } else {
            word.push_back(c);
        }
        if (line_width + word_width > LINE_WIDTH + LPADDING) {
            text.push_back(0x000d);
            for (j = 0; j < LPADDING; j++)
                text.push_back(0x0020);
            line_width = LPADDING;
        }
        if (word_width > LINE_WIDTH) {
            int acc_width = 0;
            while (!word.empty()) {
                int w = (word.front() < 0x0080) ? 1 : 2;
                if (acc_width + w <= LINE_WIDTH) {
                    text.push_back(word.front());
                    acc_width += w;
                    word.pop_front();
                } else {
                    text.push_back(0x000d);
                    for (j = 0; j < LPADDING; j++)
                        text.push_back(0x0020);
                    line_width = LPADDING;
                    word_width -= acc_width;
                }
            }
        }
    }
    while (!word.empty()) {
        text.push_back(word.front());
        word.pop_front();
    }
    unichar *carray = (unichar *)malloc(sizeof(unichar) * text.size());
    for (i = 0; i < text.size(); i++)
        carray[i] = text[i];
    NSString *mStr = [NSString stringWithCharacters: carray length: text.size()];
    free(carray);
    [self insertText: mStr];
}

- (void) selectAll: (id) sender {
    if (![self connected]) return;
    _selectionLocation = 0;
    _selectionLength = gRow * gColumn;
    [self setNeedsDisplay: YES];
}

- (BOOL) validateMenuItem: (NSMenuItem *) item {
    SEL action = [item action];
    if (action == @selector(copy:) && (![self connected] || _selectionLength == 0)) {
        return NO;
    } else if ((action == @selector(paste:) || 
                action == @selector(pasteWrap:) || 
                action == @selector(pasteColor:)) && ![self connected]) {
        return NO;
    } else if (action == @selector(selectAll:)  && ![self connected]) {
        return NO;
    } 
    return YES;
}

- (void) refreshHiddenRegion {
    if (![self connected]) return;
    int i, j;
    for (i = 0; i < gRow; i++) {
        cell *currRow = [[self dataSource] cellsOfRow: i];
        for (j = 0; j < gColumn; j++)
            if (isHiddenAttribute(currRow[j].attr)) 
                [[self dataSource] setDirty: YES atRow: i column: j];
    }
}

#pragma mark -
#pragma mark Conversion

- (int) convertIndexFromPoint: (NSPoint) p {
    if (p.x >= gColumn * _fontWidth) p.x = gColumn * _fontWidth - 0.001;
    if (p.y >= gRow * _fontHeight) p.y = gRow * _fontHeight - 0.001;
    if (p.x < 0) p.x = 0;
    if (p.y < 0) p.y = 0;
    int cx, cy = 0;
    cx = ((int)p.x) / _fontWidth;
    cy = gRow - (((int)p.y) / _fontHeight) - 1;
    return cy * gColumn + cx;
}


#pragma mark -
#pragma mark Event Handling
- (void) mouseDown: (NSEvent *) e {
    [[self window] makeFirstResponder: self];
    if (![self connected]) return;
    NSPoint p = [e locationInWindow];
    p = [self convertPoint: p toView: nil];
    _selectionLocation = [self convertIndexFromPoint: p];
    _selectionLength = 0;
    
    if (([e modifierFlags] & NSCommandKeyMask) == 0x00 &&
        [e clickCount] == 3) {
        _selectionLocation = _selectionLocation - (_selectionLocation % gColumn);
        _selectionLength = gColumn;
    } else if (([e modifierFlags] & NSCommandKeyMask) == 0x00 &&
               [e clickCount] == 2) {
        int r, c;
        r = _selectionLocation / gColumn;
        c = _selectionLocation % gColumn;
        cell *currRow = [[self dataSource] cellsOfRow: r];
        [[self dataSource] updateDoubleByteStateForRow: r];
        if (currRow[c].attr.f.doubleByte == 1) { // Double Byte
            _selectionLength = 2;
        } else if (currRow[c].attr.f.doubleByte == 2) {
            _selectionLocation--;
            _selectionLength = 2;
        } else if (isEnglishNumberAlphabet(currRow[c].byte)) {
            for (; c >= 0; c--) {                
                if (isEnglishNumberAlphabet(currRow[c].byte)) 
                    _selectionLocation = r * gColumn + c;
                else 
                    break;
            }
            for (c = c + 1; c < gColumn; c++) {
                if (isEnglishNumberAlphabet(currRow[c].byte)) 
                    _selectionLength++;
                else 
                    break;
            }
        } else {
            _selectionLength = 1;
        }
    }
    
    [self setNeedsDisplay: YES];
    
    if ([e modifierFlags] & NSCommandKeyMask) {
        unsigned char cmd[gRow * gColumn + 1];
        unsigned int cmdLength = 0;
        int moveToRow = _selectionLocation / gColumn;
        int moveToCol = _selectionLocation % gColumn;
        id ds = [self dataSource];
        BOOL home = NO;
		int i;
		if (moveToRow > [ds cursorRow]) {
			cmd[cmdLength++] = 0x01;
			home = YES;
			for (i = [ds cursorRow]; i < moveToRow; i++) {
				cmd[cmdLength++] = 0x1B;
				cmd[cmdLength++] = 0x4F;
				cmd[cmdLength++] = 0x42;
			} 
		} else if (moveToRow < [ds cursorRow]) {
			cmd[cmdLength++] = 0x01;
			home = YES;
			for (i = [ds cursorRow]; i > moveToRow; i--) {
				cmd[cmdLength++] = 0x1B;
				cmd[cmdLength++] = 0x4F;
				cmd[cmdLength++] = 0x41;
			} 			
		} 
		
		if (home) {
			for (i = 0; i < moveToCol; i++) {
				cmd[cmdLength++] = 0x1B;
				cmd[cmdLength++] = 0x4F;
				cmd[cmdLength++] = 0x43;
			}
		} else if (moveToCol > [ds cursorColumn]) {
			for (i = [ds cursorColumn]; i < moveToCol; i++) {
				cmd[cmdLength++] = 0x1B;
				cmd[cmdLength++] = 0x4F;
				cmd[cmdLength++] = 0x43;
			}
		} else if (moveToCol < [ds cursorColumn]) {
			for (i = [ds cursorColumn]; i > moveToCol; i--) {
				cmd[cmdLength++] = 0x1B;
				cmd[cmdLength++] = 0x4F;
				cmd[cmdLength++] = 0x44;
			}
		}
		if (cmdLength > 0) 
            [[self telnet] sendBytes: cmd length: cmdLength];
    }
    
    [super mouseDown: e];
}

- (void) mouseDragged: (NSEvent *) e {
    if (![self connected]) return;
    NSPoint p = [e locationInWindow];
    p = [self convertPoint: p toView: nil];
    int index = [self convertIndexFromPoint: p];
    int oldValue = _selectionLength;
    _selectionLength = index - _selectionLocation + 1;
    if (_selectionLength <= 0) _selectionLength--;
    if (oldValue != _selectionLength)
        [self setNeedsDisplay: YES];
}

- (void) mouseUp: (NSEvent *) e {
    if (![self connected]) return;
    if (_selectionLength == 0) {
        NSPoint p = [e locationInWindow];
        p = [self convertPoint: p toView: nil];
        int index = [self convertIndexFromPoint: p];
        int r = index / gColumn;
        int c = index % gColumn;
        cell *currRow = [[self dataSource] cellsOfRow: r];
        if (currRow[c].attr.f.url) {
            int start = c;
            for (start = c; start >= 0 && currRow[start].attr.f.url; start--) ;
            start++;
            int end = c;
            for (end = c; end < gColumn && currRow[end].attr.f.url; end++) ;

            NSMutableString *url = [NSMutableString string];
            for (c = start; c < end; c++)
                [url appendFormat: @"%c", currRow[c].byte];
//            NSLog(@"URL:%@", url);
            [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: url]];
        }
    }
}

- (void) keyDown: (NSEvent *) e {
	unichar c = [[e characters] characterAtIndex: 0];
	unsigned char arrow[6] = {0x1B, 0x4F, 0x00, 0x1B, 0x4F, 0x00};
	unsigned char buf[10];
//	NSLog(@"%02X %02X", [[e characters] characterAtIndex: 0], c);

	if ([e modifierFlags] & NSControlKeyMask) {
		buf[0] = c;
		[[self telnet] sendBytes: buf length: 1];
	}
	
	if (c == NSUpArrowFunctionKey) arrow[2] = arrow[5] = 'A';
	if (c == NSDownArrowFunctionKey) arrow[2] = arrow[5] = 'B';
	if (c == NSRightArrowFunctionKey) arrow[2] = arrow[5] = 'C';
	if (c == NSLeftArrowFunctionKey) arrow[2] = arrow[5] = 'D';

    YLTerminal *ds = [self dataSource];
	
	if (![self hasMarkedText] && 
		(c == NSUpArrowFunctionKey ||
		 c == NSDownArrowFunctionKey ||
		 c == NSRightArrowFunctionKey || 
		 c == NSLeftArrowFunctionKey)) {
        [ds updateDoubleByteStateForRow: [ds cursorRow]];
        if ((c == NSRightArrowFunctionKey && [ds attrAtRow: [ds cursorRow] column: [ds cursorColumn]].f.doubleByte == 1) || 
            (c == NSLeftArrowFunctionKey && [ds cursorColumn] > 0 && [ds attrAtRow: [ds cursorRow] column: [ds cursorColumn] - 1].f.doubleByte == 2))
            if ([[NSUserDefaults standardUserDefaults] boolForKey: @"DetectDoubleByte"]) {
                [[self telnet] sendBytes: arrow length: 6];
                return;
            }
        
		[[self telnet] sendBytes: arrow length: 3];
		return;
	}
	
	if (![self hasMarkedText] && (c == 0x7F || c == NSDeleteFunctionKey)) {
		buf[0] = buf[1] = 0x08;
        if ([[NSUserDefaults standardUserDefaults] boolForKey: @"DetectDoubleByte"] &&
            [ds cursorColumn] > 0 && [ds attrAtRow: [ds cursorRow] column: [ds cursorColumn] - 1].f.doubleByte == 2)
            [[self telnet] sendBytes: buf length: 2];
        else
            [[self telnet] sendBytes: buf length: 1];
        return;
	}
//	
//	unsigned char ch = (unsigned char) c;
//	[_telnet sendBytes: &ch length: 1];
	[self interpretKeyEvents: [NSArray arrayWithObject: e]];
}

- (void) flagsChanged: (NSEvent *) event {
	unsigned int currentFlags = [event modifierFlags];
	NSCursor *viewCursor = nil;
	if (currentFlags & NSCommandKeyMask) {
		viewCursor = gMoveCursor;
	} else {
		viewCursor = [NSCursor arrowCursor];
	}
	[viewCursor set];
	[super flagsChanged: event];
}

#pragma mark -
#pragma mark Drawing

- (void) tick: (NSTimer *) t {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
	[self update];
    YLTerminal *ds = [self dataSource];

	if (ds && (_x != ds->_cursorX || _y != ds->_cursorY)) {
		[self setNeedsDisplayInRect: NSMakeRect(_x * _fontWidth, (gRow - 1 - _y) * _fontHeight, _fontWidth, _fontHeight)];
		[self setNeedsDisplayInRect: NSMakeRect(ds->_cursorX * _fontWidth, (gRow - 1 - ds->_cursorY) * _fontHeight, _fontWidth, _fontHeight)];
		_x = ds->_cursorX;
		_y = ds->_cursorY;
	}
    [pool release];
}

- (NSRect) cellRectForRect: (NSRect) r {
	int originx = r.origin.x / _fontWidth;
	int originy = r.origin.y / _fontHeight;
	int width = ((r.size.width + r.origin.x) / _fontWidth) - originx + 1;
	int height = ((r.size.height + r.origin.y) / _fontHeight) - originy + 1;
	return NSMakeRect(originx, originy, width, height);
}

- (void)drawRect:(NSRect)rect {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    YLTerminal *ds = [self dataSource];
	if ([self connected]) {
		NSRect imgRect = rect;
		imgRect.origin.y = (_fontHeight * gRow) - rect.origin.y - rect.size.height;
		[_backedImage compositeToPoint: rect.origin
							  fromRect: rect
							 operation: NSCompositeCopy];

        [self drawBlink];
        int c, r;
        [[NSColor orangeColor] set];
        [NSBezierPath setDefaultLineWidth: 1.0];
        /* Draw the url underline */
        for (r = 0; r < gRow; r++) {
            [ds updateURLStateForRow: r];
            cell *currRow = [ds cellsOfRow: r];
            for (c = 0; c < gColumn; c++) {
                int start;
                for (start = c; currRow[c].attr.f.url && c < gColumn; c++) ;
                if (c != start) {
                    [NSBezierPath strokeLineFromPoint: NSMakePoint(start * _fontWidth, (gRow - r - 1) * _fontHeight + 0.5) 
                                              toPoint: NSMakePoint(c * _fontWidth, (gRow - r - 1) * _fontHeight + 0.5)];
                }
            }
        }
		/* Draw the cursor */
		
		[[NSColor whiteColor] set];
		[NSBezierPath setDefaultLineWidth: 2.0];
		[NSBezierPath strokeLineFromPoint: NSMakePoint(ds->_cursorX * _fontWidth, (gRow - 1 - ds->_cursorY) * _fontHeight + 1) 
								  toPoint: NSMakePoint((ds->_cursorX + 1) * _fontWidth, (gRow - 1 - ds->_cursorY) * _fontHeight + 1) ];
        [NSBezierPath setDefaultLineWidth: 1.0];
		/* Draw the input buffer */
		
        if (_selectionLength != 0) 
            [self drawSelection];
	} else {
		[[gConfig colorAtIndex: NUM_COLOR - 1 hilite: 0] set];
		[NSBezierPath fillRect: [self bounds]];
	}
	
//	int x, y;
//	[[NSColor whiteColor] set];
//	for (y = 0; y < gRow; y++) 
//		[NSBezierPath strokeLineFromPoint: NSMakePoint(0, y * _fontHeight + 0.5) toPoint: NSMakePoint(gColumn * _fontWidth, y * _fontHeight + 0.5)];
//	for (x = 0; x < gColumn; x++) 
//		[NSBezierPath strokeLineFromPoint: NSMakePoint(x * _fontWidth + 0.5, 0) toPoint: NSMakePoint(x * _fontWidth + 0.5, gRow * _fontHeight)];	
    [pool release];
}

- (void) drawBlink {
    int c, r;
    if (![gConfig blinkTicker]) return;
    id ds = [self dataSource];
    if (!ds) return;
    for (r = 0; r < gRow; r++) {
        cell *currRow = [ds cellsOfRow: r];
        for (c = 0; c < gColumn; c++) {
            if (isBlinkCell(currRow[c])) {
                int bgColorIndex = currRow[c].attr.f.reverse ? currRow[c].attr.f.fgColor : currRow[c].attr.f.bgColor;
                BOOL bold = currRow[c].attr.f.reverse ? currRow[c].attr.f.bold : NO;
                [[gConfig colorAtIndex: bgColorIndex hilite: bold] set];
                [NSBezierPath fillRect: NSMakeRect(c * _fontWidth, (gRow - r - 1) * _fontHeight, _fontWidth, _fontHeight)];
            }
        }
    }
    
}

- (void) drawSelection {
    int location, length;
    if (_selectionLength >= 0) {
        location = _selectionLocation;
        length = _selectionLength;
    } else {
        location = _selectionLocation + _selectionLength;
        length = 0 - (int)_selectionLength;
    }
    int x = location % gColumn;
    int y = location / gColumn;
    [[NSColor colorWithCalibratedRed: 0.6 green: 0.9 blue: 0.6 alpha: 0.4] set];

    while (length > 0) {
        if (x + length <= gColumn) { // one-line
            [NSBezierPath fillRect: NSMakeRect(x * _fontWidth, (gRow - y - 1) * _fontHeight, _fontWidth * length, _fontHeight)];
            length = 0;
        } else {
            [NSBezierPath fillRect: NSMakeRect(x * _fontWidth, (gRow - y - 1) * _fontHeight, _fontWidth * (gColumn - x), _fontHeight)];
            length -= (gColumn - x);
        }
        x = 0;
        y++;
    }
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
- (void) extendBottomFrom: (int) start to: (int) end {
	[_backedImage lockFocus];
	[_backedImage compositeToPoint: NSMakePoint(0, (gRow - end) * _fontHeight) 
						  fromRect: NSMakeRect(0, (gRow - end - 1) * _fontHeight, gColumn * _fontWidth, (end - start) * _fontHeight) 
						 operation: NSCompositeCopy];

	[gConfig->_colorTable[0][NUM_COLOR - 1] set];
	[NSBezierPath fillRect: NSMakeRect(0, (gRow - end - 1) * _fontHeight, gColumn * _fontWidth, _fontHeight)];
	[_backedImage unlockFocus];
}


/* 
	Extend Top:
 
		AAAAAAAAAAA			...........
		BBBBBBBBBBB			AAAAAAAAAAA
		CCCCCCCCCCC   ->	BBBBBBBBBBB
		DDDDDDDDDDD			CCCCCCCCCCC
 */
- (void) extendTopFrom: (int) start to: (int) end {
    [_backedImage lockFocus];
	[_backedImage compositeToPoint: NSMakePoint(0, (gRow - end - 1) * _fontHeight) 
						  fromRect: NSMakeRect(0, (gRow - end) * _fontHeight, gColumn * _fontWidth, (end - start) * _fontHeight) 
						 operation: NSCompositeCopy];
	
	[gConfig->_colorTable[0][NUM_COLOR - 1] set];
	[NSBezierPath fillRect: NSMakeRect(0, (gRow - start - 1) * _fontHeight, gColumn * _fontWidth, _fontHeight)];
	[_backedImage unlockFocus];
}

- (void) update {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
	int x, y;
    YLTerminal *ds = [self dataSource];
	[_backedImage lockFocus];
	CGContextRef myCGContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	if (ds) {
        /* Draw Background */
        for (y = 0; y < gRow; y++) {
            for (x = 0; x < gColumn; x++) {
                if ([ds isDirtyAtRow: y column: x]) {
                    int startx = x;
                    for (; x < gColumn && [ds isDirtyAtRow:y column:x]; x++) ;
                    [self updateBackgroundForRow: y from: startx to: x];
                }
            }
        }
        CGContextSaveGState(myCGContext);
        CGContextSetShouldSmoothFonts(myCGContext, false);
        
        /* Draw String row by row */
        for (y = 0; y < gRow; y++) {
            [self drawStringForRow: y context: myCGContext];
        }		
        CGContextRestoreGState(myCGContext);
        
        for (y = 0; y < gRow; y++) {
            for (x = 0; x < gColumn; x++) {
                [ds setDirty: NO atRow: y column: x];
            }
        }
        
    } else {
        CGContextFillRect(myCGContext, CGRectMake(0, 0, gColumn * _fontWidth, gRow * _fontHeight));
    }

	[_backedImage unlockFocus];
    [pool release];
}

- (void) drawStringForRow: (int) r context: (CGContextRef) myCGContext {
	int i, c, x;
	int start, end;
	unichar textBuf[gColumn];
	BOOL isDoubleByte[gColumn];
	BOOL isDoubleColor[gColumn];
	int bufIndex[gColumn];
	int runLength[gColumn];
	CGPoint position[gColumn];
	int bufLength = 0;
    
    CGFloat ePaddingLeft = 1.0, ePaddingBottom = 2.0;
    CGFloat cPaddingLeft = 1.0, cPaddingBottom = 1.0;
    
    YLTerminal *ds = [self dataSource];
    [ds updateDoubleByteStateForRow: r];
	
    cell *currRow = [ds cellsOfRow: r];

	for (i = 0; i < gColumn; i++) 
		isDoubleColor[i] = isDoubleByte[i] = textBuf[i] = runLength[i] = 0;

    // find the first non-dirty position in this row
	for (x = 0; x < gColumn && ![ds isDirtyAtRow: r column: x]; x++) ;
	start = x;
	if (start == gColumn) return;

    // update the information array
	for (x = start; x < gColumn; x++) {
		if (![ds isDirtyAtRow: r column: x]) continue;
		end = x;
		int db = (currRow + x)->attr.f.doubleByte;

		if (db == 0) {
			isDoubleByte[bufLength] = NO;
			textBuf[bufLength] = 0x0000 + (currRow + x)->byte;
			bufIndex[bufLength] = x;
			position[bufLength] = CGPointMake(x * _fontWidth + ePaddingLeft, (gRow - 1 - r) * _fontHeight + CTFontGetDescent(gConfig->_eCTFont) + ePaddingBottom);
            isDoubleColor[bufLength] = NO;
			bufLength++;
		} else if (db == 1) {
			continue;
		} else if (db == 2) {
			unsigned short code = (((currRow + x - 1)->byte) << 8) + ((currRow + x)->byte) - 0x8000;
			unichar ch = [ds encoding] == YLBig5Encoding ? B2U[code] : G2U[code];
			if (isSpecialSymbol(ch)) {
				[self drawSpecialSymbol: ch forRow: r column: (x - 1) leftAttribute: (currRow + x - 1)->attr rightAttribute: (currRow + x)->attr];
				isDoubleByte[bufLength] = isDoubleByte[bufLength + 1] = NO;
				textBuf[bufLength] = 0x3000; // full-width space
				position[bufLength] = CGPointMake((x - 1) * _fontWidth + cPaddingLeft, (gRow - 1 - r) * _fontHeight + CTFontGetDescent(gConfig->_cCTFont) + cPaddingBottom);
				bufIndex[bufLength] = x;
                isDoubleColor[bufLength] = NO;
				bufLength++;
			} else {
                unsigned int fgIndex1, fgIndex2;
                BOOL bold1, bold2;
                fgIndex1 = currRow[x - 1].attr.f.reverse ? currRow[x - 1].attr.f.bgColor : currRow[x - 1].attr.f.fgColor;
                fgIndex2 = currRow[x].attr.f.reverse ? currRow[x].attr.f.bgColor : currRow[x].attr.f.fgColor;
                bold1 = !currRow[x - 1].attr.f.reverse && currRow[x - 1].attr.f.bold;
                bold2 = !currRow[x].attr.f.reverse && currRow[x].attr.f.bold;
                if (fgIndex1 != fgIndex2 || bold1 != bold2) isDoubleColor[bufLength] = YES;
                else isDoubleColor[bufLength] = NO;
				isDoubleByte[bufLength] = YES;
				textBuf[bufLength] = ch;
				bufIndex[bufLength] = x;
				position[bufLength] = CGPointMake((x - 1) * _fontWidth + cPaddingLeft, (gRow - 1 - r) * _fontHeight + CTFontGetDescent(gConfig->_cCTFont) + cPaddingBottom);
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
			attr = gConfig->_cCTAttribute[!lastAttr.f.reverse && lastAttr.f.bold][lastAttr.f.reverse ? lastAttr.f.bgColor : lastAttr.f.fgColor];
		else
			attr = gConfig->_eCTAttribute[!lastAttr.f.reverse && lastAttr.f.bold][lastAttr.f.reverse ? lastAttr.f.bgColor : lastAttr.f.fgColor];
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
        CGContextSetRGBStrokeColor(myCGContext, 1.0, 1.0, 1.0, 1.0);
        CGContextSetLineWidth(myCGContext, 1.0);
        
        int location = runGlyphIndex = 0;
        int lastIndex = bufIndex[glyphOffset];
        BOOL hidden = isHiddenAttribute(currRow[lastIndex].attr);
        
        for (runGlyphIndex = 0; runGlyphIndex <= runGlyphCount; runGlyphIndex++) {
            int index = bufIndex[glyphOffset + runGlyphIndex];

            if (runGlyphIndex == runGlyphCount || 
                (gConfig->_showHiddenText && isHiddenAttribute(currRow[index].attr) != hidden) ||
                (isDoubleByte[runGlyphIndex] && index != lastIndex + 2) ||
                (!isDoubleByte[runGlyphIndex] && index != lastIndex + 1)) {
                int len = runGlyphIndex - location;
                
                if (gConfig->_showHiddenText && hidden) {
                    CGContextSetTextDrawingMode(myCGContext, kCGTextStroke);
                } else {
                    CGContextSetTextDrawingMode(myCGContext, kCGTextFill);                        
                }

                CGGlyph glyph[gColumn];
                CFRange glyphRange = CFRangeMake(location, len);
                CTRunGetGlyphs(run, glyphRange, glyph);
                
                CGAffineTransform textMatrix = CTRunGetTextMatrix(run);
                textMatrix.tx = position[glyphOffset + location].x;
                textMatrix.ty = position[glyphOffset + location].y;
                CGContextSetTextMatrix(myCGContext, textMatrix);
                
                CGContextShowGlyphsWithAdvances(myCGContext, glyph, isDoubleByte[glyphOffset + location] ? gDoubleAdvance : gSingleAdvance, len);
                
                location = runGlyphIndex;
                if (runGlyphIndex != runGlyphCount)
                    hidden = isHiddenAttribute(currRow[index].attr);
            }
            lastIndex = index;
        }
        
		/* Double Color */
		for (runGlyphIndex = 0; runGlyphIndex < runGlyphCount; runGlyphIndex++) {
            if (isDoubleColor[glyphOffset + runGlyphIndex]) {
                CFRange glyphRange = CFRangeMake(runGlyphIndex, 1);
                CGGlyph glyph;
                CTRunGetGlyphs(run, glyphRange, &glyph);
                
                int index = bufIndex[glyphOffset + runGlyphIndex] - 1;
                unsigned int bgColor = currRow[index].attr.f.reverse ? currRow[index].attr.f.fgColor : currRow[index].attr.f.bgColor;
                unsigned int fgColor = currRow[index].attr.f.reverse ? currRow[index].attr.f.bgColor : currRow[index].attr.f.fgColor;
                
                [gLeftImage lockFocus];
                [[gConfig colorAtIndex: bgColor hilite: currRow[index].attr.f.reverse && currRow[index].attr.f.bold] set];
                NSRect rect;
                rect.size = [gLeftImage size];
                rect.origin = NSZeroPoint;
                [NSBezierPath fillRect: rect];
                
                CGContextRef tempContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
                NSColor *tempColor = [gConfig colorAtIndex: fgColor hilite: !currRow[index].attr.f.reverse && currRow[index].attr.f.bold];
                CGContextSetFont(tempContext, cgFont);
                CGContextSetFontSize(tempContext, CTFontGetSize(runFont));
                CGContextSetRGBFillColor(tempContext, 
                                         [tempColor redComponent], 
                                         [tempColor greenComponent], 
                                         [tempColor blueComponent], 
                                         1.0);
//                CGContextSetAllowsAntialiasing(tempContext, false);
//                CGContextSetShouldSmoothFonts (tempContext, false);
//                CGContextSetShouldAntialias(tempContext, false);
                CGContextShowGlyphsAtPoint(tempContext, cPaddingLeft, CTFontGetDescent(gConfig->_cCTFont) + cPaddingBottom, &glyph, 1);
                [gLeftImage unlockFocus];
                [gLeftImage drawAtPoint: NSMakePoint(index * _fontWidth, (gRow - 1 - r) * _fontHeight) fromRect: rect operation: NSCompositeCopy fraction: 1.0];
            }
		}
		glyphOffset += runGlyphCount;
		CFRelease(cgFont);
	}
	
	CFRelease(line);
        
    /* underline */
    for (x = start; x <= end; x++) {
        if (currRow[x].attr.f.underline) {
            unsigned int beginColor = currRow[x].attr.f.reverse ? currRow[x].attr.f.bgColor : currRow[x].attr.f.fgColor;
            BOOL beginBold = !currRow[x].attr.f.reverse && currRow[x].attr.f.bold;
            int begin = x;
            for (; x <= end; x++) {
                unsigned int currentColor = currRow[x].attr.f.reverse ? currRow[x].attr.f.bgColor : currRow[x].attr.f.fgColor;
                BOOL currentBold = !currRow[x].attr.f.reverse && currRow[x].attr.f.bold;
                if (!currRow[x].attr.f.underline || currentColor != beginColor || currentBold != beginBold) 
                    break;
            }
            [[gConfig colorAtIndex: beginColor hilite: beginBold] set];
            [NSBezierPath strokeLineFromPoint: NSMakePoint(begin * _fontWidth, (gRow - 1 - r) * _fontHeight + 0.5) 
                                      toPoint: NSMakePoint(x * _fontWidth, (gRow - 1 - r) * _fontHeight + 0.5)];
            x--;
        }
    }
}

- (void) updateBackgroundForRow: (int) r from: (int) start to: (int) end {
	int c;
	cell *currRow = [[self dataSource] cellsOfRow: r];
	NSRect rowRect = NSMakeRect(start * _fontWidth, (gRow - 1 - r) * _fontHeight, (end - start) * _fontWidth, _fontHeight);

	attribute currAttr, lastAttr = (currRow + start)->attr;
	int length = 0;
	unsigned int currentBackgroundColor;
    BOOL currentBold;
	unsigned int lastBackgroundColor = lastAttr.f.reverse ? lastAttr.f.fgColor : lastAttr.f.bgColor;
	BOOL lastBold = (lastAttr.f.reverse && lastAttr.f.bold);
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
            currentBold = (currAttr.f.reverse && currAttr.f.bold);
		}
		
		if (currentBackgroundColor != lastBackgroundColor || currentBold != lastBold || c == end) {
			/* Draw Background */
			NSRect rect = NSMakeRect((c - length) * _fontWidth, (gRow - 1 - r) * _fontHeight,
								  _fontWidth * length, _fontHeight);
			[[gConfig colorAtIndex: lastBackgroundColor hilite: lastBold] set];
			[NSBezierPath fillRect: rect];
			
			/* finish this segment */
			length = 1;
			lastAttr.v = currAttr.v;
			lastBackgroundColor = currentBackgroundColor;
            lastBold = currentBold;
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
	
	if (colorIndex1 == colorIndex2 && attr1.f.bold == attr2.f.bold) {
		NSColor *color = [gConfig colorAtIndex: colorIndex1 hilite: attr1.f.bold];
		
		if (ch == 0x25FC) { // ◼ BLACK SQUARE
			[color set];
			[NSBezierPath fillRect: gSymbolBlackSquareRect];
		} else if (ch >= 0x2581 && ch <= 0x2588) { // BLOCK ▁▂▃▄▅▆▇█
			[color set];
			[NSBezierPath fillRect: gSymbolLowerBlockRect[ch - 0x2581]];
		} else if (ch >= 0x2589 && ch <= 0x258F) { // BLOCK ▉▊▋▌▍▎▏
			[color set];
			[NSBezierPath fillRect: gSymbolLeftBlockRect[ch - 0x2589]];		
		} else if (ch >= 0x25E2 && ch <= 0x25E5) { // TRIANGLE ◢◣◤◥
            [color set];
            [gSymbolTrianglePath[ch - 0x25E2] fill];
		} else if (ch == 0x0) {
		}
	} else { // double color
		NSColor *color1 = [gConfig colorAtIndex: colorIndex1 hilite: attr1.f.bold];
		NSColor *color2 = [gConfig colorAtIndex: colorIndex2 hilite: attr2.f.bold];
		if (ch == 0x25FC) { // ◼ BLACK SQUARE
			[color1 set];
			[NSBezierPath fillRect: gSymbolBlackSquareRect1];
			[color2 set];
			[NSBezierPath fillRect: gSymbolBlackSquareRect2];
		} else if (ch >= 0x2581 && ch <= 0x2588) { // BLOCK ▁▂▃▄▅▆▇█
			[color1 set];
			[NSBezierPath fillRect: gSymbolLowerBlockRect1[ch - 0x2581]];
			[color2 set];
            [NSBezierPath fillRect: gSymbolLowerBlockRect2[ch - 0x2581]];
		} else if (ch >= 0x2589 && ch <= 0x258F) { // BLOCK ▉▊▋▌▍▎▏
			[color1 set];
			[NSBezierPath fillRect: gSymbolLeftBlockRect1[ch - 0x2589]];
            if (ch <= 0x259B) {
                [color2 set];
                [NSBezierPath fillRect: gSymbolLeftBlockRect2[ch - 0x2589]];
            }
		} else if (ch >= 0x25E2 && ch <= 0x25E5) { // TRIANGLE ◢◣◤◥
            [color1 set];
            [gSymbolTrianglePath1[ch - 0x25E2] fill];
            [color2 set];
            [gSymbolTrianglePath2[ch - 0x25E2] fill];
		}
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

- (BOOL)canBecomeKeyView {
    return YES;
}

- (void)removeTabViewItem:(NSTabViewItem *)tabViewItem {
    [[tabViewItem identifier] close];
    [super removeTabViewItem: tabViewItem];
}

+ (NSMenu *) defaultMenu {
    return [[[NSMenu alloc] init] autorelease];
}

- (NSMenu *) menuForEvent: (NSEvent *) theEvent {
    NSMenu *menu = [[self class] defaultMenu];
    if (![self connected]) return menu;
    
    NSString *s = [self selectedPlainString];
    NSArray *a = [[YLContextualMenuManager sharedInstance] availableMenuItemForSelectionString: s];
    for(NSMenuItem *item in a) {
        [menu addItem: item];
    }
    return menu;
}

- (NSView *) hitTest: (NSPoint) p {
    return self;
}

#pragma mark -
#pragma mark Accessor

- (int)x {
    return _x;
}

- (void)setX:(int)value {
    _x = value;
}

- (int) y {
    return _y;
}

- (void) setY: (int) value {
    _y = value;
}

- (BOOL) connected {
	return [[self telnet] connected];
}

- (YLTerminal *) dataSource {
    return (YLTerminal *)[[self telnet] terminal];
}

- (YLTelnet *) telnet {
    id identifier = [[self selectedTabViewItem] identifier];
    return (YLTelnet *) identifier;
}

- (NSString *) selectedPlainString {
    if (_selectionLength == 0) return nil;
    int location, length;
    if (_selectionLength >= 0) {
        location = _selectionLocation;
        length = _selectionLength;
    } else {
        location = _selectionLocation + _selectionLength;
        length = 0 - (int)_selectionLength;
    }
    return [[self dataSource] stringFromIndex: location length: length];
}

- (BOOL) hasBlinkCell {
    int c, r;
    id ds = [self dataSource];
    if (!ds) return NO;
    for (r = 0; r < gRow; r++) {
        [ds updateDoubleByteStateForRow: r];
        cell *currRow = [ds cellsOfRow: r];
        for (c = 0; c < gColumn; c++) 
            if (isBlinkCell(currRow[c]))
                return YES;
    }
    return NO;
}

#pragma mark -
#pragma mark NSTextInput Protocol
/* NSTextInput protocol */
// instead of keyDown: aString can be NSString or NSAttributedString
- (void) insertText: (id) aString {
	[_textField setHidden: YES];
	[_markedText release];
	_markedText = nil;	
	
    NSMutableString *mStr = [NSMutableString stringWithString: aString];
    [mStr replaceOccurrencesOfString: @"\n"
                          withString: @"\r"
                             options: NSLiteralSearch
                               range: NSMakeRange(0, [aString length])];
    
	int i;
	NSMutableData *data = [NSMutableData data];
	for (i = 0; i < [mStr length]; i++) {
		unichar ch = [mStr characterAtIndex: i];
		unsigned char buf[2];
		if (ch < 0x007F) {
			buf[0] = ch;
			[data appendBytes: buf length: 1];
		} else {
            YLEncoding encoding = [[self dataSource] encoding];
            unichar code = (encoding == YLBig5Encoding ? U2B[ch] : U2G[ch]);
			buf[0] = code >> 8;
			buf[1] = code & 0xFF;
			[data appendBytes: buf length: 2];
		}
	}
	[[self telnet] sendMessage: data];
}

- (void) doCommandBySelector:(SEL)aSelector {
	unsigned char ch[10];
    
//    NSLog(@"%s", aSelector);
    
	if (strcmp((char *) aSelector, "insertNewline:") == 0) {
		ch[0] = 0x0D;
		[[self telnet] sendBytes: ch length: 1];
	} else if (strcmp((char *) aSelector, "cancelOperation:") == 0) {
	} else if (strcmp((char *) aSelector, "cancel:") == 0) {
	} else if (strcmp((char *) aSelector, "scrollToBeginningOfDocument:") == 0) {
        ch[0] = 0x1B; ch[1] = '['; ch[2] = '1'; ch[3] = '~';
		[[self telnet] sendBytes: ch length: 4];		
	} else if (strcmp((char *) aSelector, "scrollToEndOfDocument:") == 0) {
        ch[0] = 0x1B; ch[1] = '['; ch[2] = '4'; ch[3] = '~';
		[[self telnet] sendBytes: ch length: 4];		
	} else if (strcmp((char *) aSelector, "scrollPageUp:") == 0) {
		ch[0] = 0x1B; ch[1] = '['; ch[2] = '5'; ch[3] = '~';
		[[self telnet] sendBytes: ch length: 4];
	} else if (strcmp((char *) aSelector, "scrollPageDown:") == 0) {
		ch[0] = 0x1B; ch[1] = '['; ch[2] = '6'; ch[3] = '~';
		[[self telnet] sendBytes: ch length: 4];		
	} else if (strcmp((char *) aSelector, "insertTab:") == 0) {
        ch[0] = 0x09;
		[[self telnet] sendBytes: ch length: 1];
    }
}

// setMarkedText: cannot take a nil first argument. aString can be NSString or NSAttributedString
- (void) setMarkedText:(id)aString selectedRange:(NSRange)selRange {
    YLTerminal *ds = [self dataSource];
	if ([aString isKindOfClass: [NSString class]])
		aString = [[[NSAttributedString alloc] initWithString: aString] autorelease];

	if ([aString length] == 0) {
		[self unmarkText];
		return;
	}
	
	if (_markedText != aString) {
		[_markedText release];
		_markedText = [aString retain];
	}
	_selectedRange = selRange;
	_markedRange.location = 0;
	_markedRange.length = [aString length];
		
	[_textField setString: aString];
	[_textField setSelectedRange: selRange];
	[_textField setMarkedRange: _markedRange];

	NSPoint o = NSMakePoint(ds->_cursorX * _fontWidth, (gRow - 1 - ds->_cursorY) * _fontHeight + 5.0);
	CGFloat dy;
	if (o.x + [_textField frame].size.width > gColumn * _fontWidth) 
		o.x = gColumn * _fontWidth - [_textField frame].size.width;
	if (o.y + [_textField frame].size.height > gRow * _fontHeight) {
		o.y = (gRow - ds->_cursorY) * _fontHeight - 5.0 - [_textField frame].size.height;
		dy = o.y + [_textField frame].size.height;
	} else {
		dy = o.y;
	}
	[_textField setFrameOrigin: o];
	[_textField setDestination: [_textField convertPoint: NSMakePoint((ds->_cursorX + 0.5) * _fontWidth, dy)
												fromView: self]];
	[_textField setHidden: NO];
}

- (void) unmarkText {
	[_markedText release];
	_markedText = nil;
	[_textField setHidden: YES];
}

- (BOOL) hasMarkedText {
	return (_markedText != nil);
}

- (NSInteger) conversationIdentifier {
	return (NSInteger) self;
}

/* Returns attributed string at the range.  This allows input mangers to query any range in backing-store.  May return nil.
 */
- (NSAttributedString *) attributedSubstringFromRange:(NSRange)theRange {
	if (theRange.location < 0 || theRange.location >= [_markedText length]) return nil;
	if (theRange.location + theRange.length > [_markedText length]) 
		theRange.length = [_markedText length] - theRange.location;
	return [[[NSAttributedString alloc] initWithString: [[_markedText string] substringWithRange: theRange]] autorelease];
}

/* This method returns the range for marked region.  If hasMarkedText == false, it'll return NSNotFound location & 0 length range.
 */
- (NSRange) markedRange {
	return _markedRange;
}

/* This method returns the range for selected region.  Just like markedRange method, its location field contains char index from the text beginning.
 */
- (NSRange) selectedRange {
	return _selectedRange;
}

/* This method returns the first frame of rects for theRange in screen coordindate system.
 */
- (NSRect) firstRectForCharacterRange:(NSRange)theRange {
	NSPoint pointInWindowCoordinates;
	NSRect rectInScreenCoordinates;
	
	pointInWindowCoordinates = [_textField frame].origin;
	//[_textField convertPoint: [_textField frame].origin toView: nil];
	rectInScreenCoordinates.origin = [[_textField window] convertBaseToScreen: pointInWindowCoordinates];
	rectInScreenCoordinates.size = [_textField bounds].size;

	return rectInScreenCoordinates;
}

/* This method returns the index for character that is nearest to thePoint.  thPoint is in screen coordinate system.
 */
- (NSUInteger)characterIndexForPoint:(NSPoint)thePoint {
	return 0;
}

/* This method is the key to attribute extension.  We could add new attributes through this method. NSInputServer examines the return value of this method & constructs appropriate attributed string.
 */
- (NSArray*) validAttributesForMarkedText {
	return [NSArray array];
}

/*
#pragma mark -
#pragma mark NSTabVIew
- (void)addTabViewItem:(NSTabViewItem *)tabViewItem {
    [_tabItems addObject: tabViewItem];
}

- (void)insertTabViewItem:(NSTabViewItem *)tabViewItem atIndex:(NSInteger)index {
    [_tabItems insertObject: tabViewItem atIndex: index];
}

- (void)removeTabViewItem:(NSTabViewItem *)tabViewItem {
    [_tabItems removeObject: tabViewItem];
}

- (NSInteger)indexOfTabViewItem:(NSTabViewItem *)tabViewItem {
    return [_tabItems indexOfObject: tabViewItem];
}

- (NSInteger)indexOfTabViewItemWithIdentifier:(id)identifier {
    for (NSTabViewItem *item in _tabItems) {
        if ([item identifier] == identifier) return [_tabItems indexOfObject: item];
    }
    return NSNotFound;
}

- (NSInteger)numberOfTabViewItems {
    return [_tabItems count];
}

- (NSTabViewItem *)tabViewItemAtIndex:(NSInteger)index {
    return [_tabItems objectAtIndex: index];
}

- (NSArray *)tabViewItems {
    return _tabItems;
}
*/

@end
