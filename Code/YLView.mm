//
//  YLView.m
//  Nally
//
//  Created by Yung-Luen Lan on 2006/6/9.
//  Copyright 2006 yllan.org. All rights reserved.
//

#import "YLView.h"
#import "YLSite.h"
#import "YLLGlobalConfig.h"
#import "Nally-Swift.h"
#import "YLContextualMenuManager.h"
#import "YLTextSuite.h"

#include <deque>
#include "encoding.h"

using namespace std;

static YLLGlobalConfig *gConfig;
static int gRow;
static int gColumn;
static NSImage *gLeftImage;
static CGSize *gSingleAdvance;
static CGSize *gDoubleAdvance;
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

BOOL isEnglishNumberAlphabet(unsigned char c)
{
    return ('0' <= c && c <= '9') || ('A' <= c && c <= 'Z') || ('a' <= c && c <= 'z') || (c == '-') || (c == '_') || (c == '.');
}

BOOL isSpecialSymbol(unichar ch)
{
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

+ (void) initialize
{
    NSImage *cursorImage = [[NSImage alloc] initWithSize: NSMakeSize(11.0, 20.0)];
    [cursorImage lockFocus];
    [[NSColor clearColor] set];
    NSRectFill(NSMakeRect(0, 0, 11, 20));
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
    [cursorImage unlockFocus];
    gMoveCursor = [[NSCursor alloc] initWithImage: cursorImage hotSpot: NSMakePoint(5.5, 9.5)];
    [cursorImage release];
}

- (void) createSymbolPath
{
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

- (void) configure
{
    if (!gConfig) gConfig = [YLLGlobalConfig sharedInstance];
	gColumn = [gConfig column];
	gRow = [gConfig row];
    _fontWidth = [gConfig cellWidth];
    _fontHeight = [gConfig cellHeight];
	
    NSRect frame = [self frame];
	frame.size = NSMakeSize(gColumn * [gConfig cellWidth], gRow * [gConfig cellHeight]);
    frame.origin = NSZeroPoint;
    [self setFrame: frame];

    [self createSymbolPath];

    [_backedImage release];
    _backedImage = [[NSImage alloc] initWithSize: frame.size];
    [_backedImage setFlipped: NO];

    [gLeftImage release]; 
    gLeftImage = [[NSImage alloc] initWithSize: NSMakeSize(_fontWidth, _fontHeight)];			

    if (!gSingleAdvance) gSingleAdvance = (CGSize *) malloc(sizeof(CGSize) * gColumn);
    if (!gDoubleAdvance) gDoubleAdvance = (CGSize *) malloc(sizeof(CGSize) * gColumn);

    int i;
    for (i = 0; i < gColumn; i++) {
        gSingleAdvance[i] = CGSizeMake(_fontWidth * 1.0, 0.0);
        gDoubleAdvance[i] = CGSizeMake(_fontWidth * 2.0, 0.0);
    }
    [_markedText release];
    _markedText = nil;

    _selectedRange = NSMakeRange(NSNotFound, 0);
    _markedRange = NSMakeRange(NSNotFound, 0);
    
    [_textField setHidden: YES];
}

- (id) initWithFrame: (NSRect)frame
{
    self = [super initWithFrame: frame];
    if (self) {
        [self configure];
        _selectionLength = 0;
        _selectionLocation = 0;
        [self setTabViewType: NSNoTabsNoBorder];
    }
    return self;
}

- (void) dealloc
{
	[_backedImage release];
	[super dealloc];
}

#pragma mark -
#pragma mark Actions

- (IBAction) copy: (id)sender
{
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
    int i, j;
    int bufferLength = 0;
    id ds = [self frontMostTerminal];
    int emptyCount = 0;

    for (i = 0; i < length; i++) {
        int index = location + i;
        cell *currentRow = [ds cellsOfRow: index / gColumn];
        
        if ((index % gColumn == 0) && (index != location)) {
            buffer[bufferLength].byte = '\n';
            buffer[bufferLength].attr = buffer[bufferLength - 1].attr;
            bufferLength++;
            emptyCount = 0;
        }
        if (currentRow[index % gColumn].byte != '\0') {
            for (j = 0; j < emptyCount; j++) {
                buffer[bufferLength] = currentRow[index % gColumn];
                buffer[bufferLength].byte = ' ';
                buffer[bufferLength].attr.f.doubleByte = 0;
                buffer[bufferLength].attr.f.url = 0;
                buffer[bufferLength].attr.f.nothing = 0;
                bufferLength++;   
            }
            buffer[bufferLength] = currentRow[index % gColumn];
            /* Clear non-ANSI related properties. */
            buffer[bufferLength].attr.f.doubleByte = 0;
            buffer[bufferLength].attr.f.url = 0;
            buffer[bufferLength].attr.f.nothing = 0;
            bufferLength++;
            emptyCount = 0;
        } else {
            emptyCount++;
        }
    }
    
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSMutableArray *types = [NSMutableArray arrayWithObjects: NSStringPboardType, ANSIColorPBoardType, nil];
    if (!s) s = @"";
    [pb declareTypes: types owner: self];
    [pb setString: s forType: NSStringPboardType];
    [pb setData: [NSData dataWithBytes: buffer length: bufferLength * sizeof(cell)] forType: ANSIColorPBoardType];
    free(buffer);
}

- (IBAction) pasteColor: (id)sender
{
    if (![self connected]) return;
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSArray *types = [pb types];
	if (![types containsObject: ANSIColorPBoardType]) {
		[self paste: self];
		return;
	}
	
    NSData *escData;
    YLSite *s = [[self frontMostConnection] site];
    if ([s ansiColorKey] == YLCtrlUANSIColorKey) {
        escData = [NSData dataWithBytes: "\x15" length: 1];
    } else if ([s ansiColorKey] == YLEscEscEscANSIColorKey) {
        escData = [NSData dataWithBytes: "\x1B\x1B" length: 2];
    } else {
        escData = [NSData dataWithBytes: "\x1B" length:1];
    }
    
	cell *buffer = (cell *) [[pb dataForType: ANSIColorPBoardType] bytes];
	int bufferLength = [[pb dataForType: ANSIColorPBoardType] length] / sizeof(cell);
		
	attribute defaultANSI;
	defaultANSI.f.bgColor = gConfig.bgColorIndex;
	defaultANSI.f.fgColor = gConfig.fgColorIndex;
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
            [writeBuffer appendData: escData];
			[writeBuffer appendBytes: "[m\r" length: 3];
			continue;
		}
		
		attribute currentANSI = buffer[i].attr;
		
        char tmp[100];
        tmp[0] = '\0';
        
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
			(currentANSI.f.reverse == 0 && previousANSI.f.reverse == 1) ||
            (currentANSI.f.bgColor ==  gConfig.bgColorIndex && previousANSI.f.reverse != gConfig.bgColorIndex) ) {
			strcpy(tmp, "[0");
			if (currentANSI.f.blink == 1) strcat(tmp, ";5");
			if (currentANSI.f.bold == 1) strcat(tmp, ";1");
			if (currentANSI.f.underline == 1) strcat(tmp, ";4");
			if (currentANSI.f.reverse == 1) strcat(tmp, ";7");
			if (currentANSI.f.fgColor != gConfig.fgColorIndex) sprintf(tmp, "%s;%d", tmp, currentANSI.f.fgColor + 30);
			if (currentANSI.f.bgColor != gConfig.bgColorIndex) sprintf(tmp, "%s;%d", tmp, currentANSI.f.bgColor + 40);
			strcat(tmp, "m");
            [writeBuffer appendData: escData];
			[writeBuffer appendBytes: tmp length: strlen(tmp)];
			[writeBuffer appendBytes: &(buffer[i].byte) length: 1];
			previousANSI = currentANSI;
			continue;
		}
		
		/* Add attribute */
		strcpy(tmp, "[");
		if (currentANSI.f.blink == 1 && previousANSI.f.blink == 0) strcat(tmp, "5;");
		if (currentANSI.f.bold == 1 && previousANSI.f.bold == 0) strcat(tmp, "1;");
		if (currentANSI.f.underline == 1 && previousANSI.f.underline == 0) strcat(tmp, "4;");
		if (currentANSI.f.reverse == 1 && previousANSI.f.reverse == 0) strcat(tmp, "7;");
		if (currentANSI.f.fgColor != previousANSI.f.fgColor) sprintf(tmp, "%s%d;", tmp, currentANSI.f.fgColor + 30);
		if (currentANSI.f.bgColor != previousANSI.f.bgColor) sprintf(tmp, "%s%d;", tmp, currentANSI.f.bgColor + 40);
		tmp[strlen(tmp) - 1] = 'm';
		sprintf(tmp, "%s%c", tmp, buffer[i].byte);
        [writeBuffer appendData: escData];
		[writeBuffer appendBytes: tmp length: strlen(tmp)];
		previousANSI = currentANSI;
		continue;
	}
    [writeBuffer appendData: escData];
	[writeBuffer appendBytes: "[m" length: 2];
    unsigned char *buf = (unsigned char *)[writeBuffer bytes];
    for (i = 0; i < [writeBuffer length]; i++) {
        [[self frontMostConnection] sendBytes: buf + i length: 1];
        usleep(100);
    }
}

- (IBAction) paste: (id)sender
{
    if (![self connected]) return;
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSArray *types = [pb types];
    if ([types containsObject: NSStringPboardType]) {
        NSString *str = [pb stringForType: NSStringPboardType];
        [self insertText: str withDelay: 100];
    }
}

- (void) pasteWrap: (id)sender
{
    if (![self connected]) return;
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSArray *types = [pb types];
    if (![types containsObject: NSStringPboardType]) return;
    
    NSString *text = [pb stringForType: NSStringPboardType];
    int LINE_WIDTH = 66, LPADDING = 4;
	YLTextSuite *textSuite = [[YLTextSuite new] autorelease];
    
	text = [textSuite wrapText: text withLength: LINE_WIDTH encoding: self.frontMostConnection.site.encoding];
	text = [textSuite paddingText: text withLeftPadding: LPADDING];
	
	[self insertText: text withDelay: 50];
}

- (IBAction) selectAll: (id)sender
{
    if (![self connected]) return;
    _selectionLocation = 0;
    _selectionLength = gRow * gColumn;
    [self setNeedsDisplay: YES];
}

- (BOOL) validateMenuItem: (NSMenuItem *)item
{
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

- (void) refreshHiddenRegion
{
    if (![self connected]) return;
    int i, j;
    for (i = 0; i < gRow; i++) {
        cell *currRow = [[self frontMostTerminal] cellsOfRow: i];
        for (j = 0; j < gColumn; j++)
            if (isHiddenAttribute(currRow[j].attr)) 
                [[self frontMostTerminal] setDirty: YES atRow: i column: j];
    }
}

- (void) loadUrlOfString:(NSString *)url
{
    // if it's a image file, try loading it.
    if (_shouldUseImagePreviewer &&
        [url characterAtIndex:([url length] - 1)] != '/' &&
        [url pathExtension] &&
        [[NSImage imageFileTypes] containsObject:[url pathExtension]] &&
        ![[url pathExtension] isEqual: @"pdf"])
    {
        [[YLImagePreviewer alloc] initWithURL: [NSURL URLWithString: url]];
    }
    else
    {
        NSWorkspaceLaunchOptions launchOptions =
            _shouldOpenUrlInBackground ? NSWorkspaceLaunchWithoutActivation : NSWorkspaceLaunchDefault;
        
        [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:[NSURL URLWithString:url]]
                        withAppBundleIdentifier:nil
                                        options:launchOptions
                 additionalEventParamDescriptor:nil
                              launchIdentifiers:nil];
    }
    
}

#pragma mark -
#pragma mark Conversion

- (int) convertIndexFromPoint: (NSPoint)p
{
    if (p.x >= gColumn * _fontWidth) p.x = gColumn * _fontWidth - 0.001;
    if (p.y >= gRow * _fontHeight) p.y = gRow * _fontHeight - 0.001;
    if (p.x < 0) p.x = 0;
    if (p.y < 0) p.y = 0;
    int cx, cy = 0;
    cx = (int) ((CGFloat) p.x / _fontWidth);
    cy = gRow - (int) ((CGFloat) p.y / _fontHeight) - 1;
    return cy * gColumn + cx;
}


#pragma mark -
#pragma mark Event Handling
- (void) mouseDown: (NSEvent *)e
{
    [[self frontMostTerminal] setHasMessage: NO];
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
        cell *currRow = [[self frontMostTerminal] cellsOfRow: r];
        [[self frontMostTerminal] updateDoubleByteStateForRow: r];
        if (currRow[c].attr.f.doubleByte == 1) { // Double Byte
            _selectionLength = 2;
        } else if (currRow[c].attr.f.doubleByte == 2) {
            _selectionLocation--;
            _selectionLength = 2;
        } else if (isEnglishNumberAlphabet(currRow[c].byte)) { // Not Double Byte
            for (; c >= 0; c--) {
                if (isEnglishNumberAlphabet(currRow[c].byte) && currRow[c].attr.f.doubleByte == 0) 
                    _selectionLocation = r * gColumn + c;
                else 
                    break;
            }
            for (c = c + 1; c < gColumn; c++) {
                if (isEnglishNumberAlphabet(currRow[c].byte) && currRow[c].attr.f.doubleByte == 0) 
                    _selectionLength++;
                else 
                    break;
            }
        } else {
            _selectionLength = 1;
        }
    }
    
    [self setNeedsDisplay: YES];
    
    /* Click to move cursor. */
    if ([e modifierFlags] & NSCommandKeyMask) {
        unsigned char cmd[gRow * gColumn + 1];
        unsigned int cmdLength = 0;
        int moveToRow = _selectionLocation / gColumn;
        int moveToCol = _selectionLocation % gColumn;
        id ds = [self frontMostTerminal];
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
		
        cell *currRow = [[self frontMostTerminal] cellsOfRow: moveToRow];
		if (home) {
			for (i = 0; i < moveToCol; i++) {
                if (currRow[i].attr.f.doubleByte != 2 || [[[self frontMostConnection] site] detectDoubleByte]) {
                    cmd[cmdLength++] = 0x1B;
                    cmd[cmdLength++] = 0x4F;
                    cmd[cmdLength++] = 0x43;                    
                }
			}
		} else if (moveToCol > [ds cursorColumn]) {
			for (i = [ds cursorColumn]; i < moveToCol; i++) {
                if (currRow[i].attr.f.doubleByte != 2 || [[[self frontMostConnection] site] detectDoubleByte]) {
                    cmd[cmdLength++] = 0x1B;
                    cmd[cmdLength++] = 0x4F;
                    cmd[cmdLength++] = 0x43;
                }
			}
		} else if (moveToCol < [ds cursorColumn]) {
			for (i = [ds cursorColumn]; i > moveToCol; i--) {
                if (currRow[i].attr.f.doubleByte != 2 || [[[self frontMostConnection] site] detectDoubleByte]) {
                    cmd[cmdLength++] = 0x1B;
                    cmd[cmdLength++] = 0x4F;
                    cmd[cmdLength++] = 0x44;
                }
			}
		}
		if (cmdLength > 0) 
            [[self frontMostConnection] sendBytes: cmd length: cmdLength];
    }
    
//    [super mouseDown: e];
}

- (void) mouseDragged: (NSEvent *)e
{
    if (![self connected]) return;
    NSPoint p = [e locationInWindow];
    p = [self convertPoint: p toView: nil];
    int index = [self convertIndexFromPoint: p];
    int oldValue = _selectionLength;
    _selectionLength = index - _selectionLocation + 1;
    if (_selectionLength <= 0) _selectionLength--;
    if (oldValue != _selectionLength)
        [self setNeedsDisplay: YES];
    // TODO: Calculate the precise region to redraw
}

- (void) mouseUp: (NSEvent *)e
{
    if (![self connected]) return;
    if (_selectionLength == 0) {
        NSPoint p = [e locationInWindow];
        p = [self convertPoint: p toView: nil];
        int index = [self convertIndexFromPoint: p];
        
        NSString *url = [[self frontMostTerminal] urlStringAtRow: (index / gColumn) 
                                                          column: (index % gColumn)];
        if (url && !([e modifierFlags] & NSCommandKeyMask))
        {
            _shouldOpenUrlInBackground = (([e modifierFlags] & NSAlternateKeyMask) == NSAlternateKeyMask) ? YES : NO;
            _shouldUseImagePreviewer = [gConfig shouldPreferImagePreviewer];
            if ([e modifierFlags] & NSShiftKeyMask)
                _shouldUseImagePreviewer = !_shouldUseImagePreviewer;
            
            // Try to revert shortened URLs
            if ([url length] < 25 && [url hasPrefix: @"http://"])  // FIXME: Need a better way to identify short URLs
            {
                [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]
                                              delegate:self];
                // Do the rest in the delegate method -connection:didReceiveResponse:
            }
            else
            {
                [self loadUrlOfString:url];
            }
        }
    }
}

- (void) keyDown: (NSEvent *)e
{
    [self clearSelection];
    
	unichar c = [[e characters] characterAtIndex: 0];
	unsigned char arrow[6] = {0x1B, 0x4F, 0x00, 0x1B, 0x4F, 0x00};
	unsigned char buf[10];

    [[self frontMostTerminal] setHasMessage: NO];
    
	if ([e modifierFlags] & NSControlKeyMask) {
		buf[0] = c;
		[[self frontMostConnection] sendBytes: buf length: 1];
        return;
	}
    else if ([e modifierFlags] & NSCommandKeyMask)
    {
        buf[0] = 0x1b;
        buf[1] = 0x5b;
        buf[2] = 0x00;
        buf[3] = 0x7e;
        switch (c)
        {
            case NSUpArrowFunctionKey:
                buf[2] = 0x35;
                break;
            case NSDownArrowFunctionKey:
                buf[2] = 0x36;
                break;
            case NSLeftArrowFunctionKey:
                buf[2] = 0x31;
                break;
            case NSRightArrowFunctionKey:
                buf[2] = 0x34;
                break;
            default:
                break;
        }
        if (buf[2] != 0x00) {
            [[self frontMostConnection] sendBytes:buf length:4];
        } else {
            [super keyDown:e];
        }
        return;
    }
	
	if (c == NSUpArrowFunctionKey) arrow[2] = arrow[5] = 'A';
	if (c == NSDownArrowFunctionKey) arrow[2] = arrow[5] = 'B';
	if (c == NSRightArrowFunctionKey) arrow[2] = arrow[5] = 'C';
	if (c == NSLeftArrowFunctionKey) arrow[2] = arrow[5] = 'D';

    YLTerminal *ds = [self frontMostTerminal];
	
	if (![self hasMarkedText] && 
		(c == NSUpArrowFunctionKey ||
		 c == NSDownArrowFunctionKey ||
		 c == NSRightArrowFunctionKey || 
		 c == NSLeftArrowFunctionKey)) {
        [ds updateDoubleByteStateForRow: [ds cursorRow]];
        if ((c == NSRightArrowFunctionKey && [ds attrAtRow: [ds cursorRow] column: [ds cursorColumn]].f.doubleByte == 1) || 
            (c == NSLeftArrowFunctionKey && [ds cursorColumn] > 0 && [ds attrAtRow: [ds cursorRow] column: [ds cursorColumn] - 1].f.doubleByte == 2))
            if ([[[self frontMostConnection] site] detectDoubleByte]) {
                [[self frontMostConnection] sendBytes: arrow length: 6];
                return;
            }
        
		[[self frontMostConnection] sendBytes: arrow length: 3];
		return;
	}
	
	if (![self hasMarkedText] && (c == 0x7F)) {
		buf[0] = buf[1] = 0x08;
        if ([[[self frontMostConnection] site] detectDoubleByte] &&
            [ds cursorColumn] > 0 && [ds attrAtRow: [ds cursorRow] column: [ds cursorColumn] - 1].f.doubleByte == 2)
            [[self frontMostConnection] sendBytes: buf length: 2];
        else
            [[self frontMostConnection] sendBytes: buf length: 1];
        return;
	}

	[self interpretKeyEvents: [NSArray arrayWithObject: e]];
}

- (void) flagsChanged: (NSEvent *)event
{
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

- (void) clearSelection
{
    if (_selectionLength != 0) {
        _selectionLength = 0;
        [self setNeedsDisplay: YES];
    }
}

#pragma mark -
#pragma mark Drawing

- (void) displayCellAtRow: (int)r column: (int)c
{
    [self setNeedsDisplayInRect: NSMakeRect(c * _fontWidth, (gRow - 1 - r) * _fontHeight, _fontWidth, _fontHeight)];
}

- (void) tick
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
	[self updateBackedImage];
    YLTerminal *ds = [self frontMostTerminal];

	if (ds && (_x != [ds cursorColumn] || _y != [ds cursorRow])) {
		[self setNeedsDisplayInRect: NSMakeRect(_x * _fontWidth, (gRow - 1 - _y) * _fontHeight, _fontWidth, _fontHeight)];
		[self setNeedsDisplayInRect: NSMakeRect([ds cursorColumn] * _fontWidth, (gRow - 1 - [ds cursorRow]) * _fontHeight, _fontWidth, _fontHeight)];
		_x = [ds cursorColumn];
		_y = [ds cursorRow];
	}
    [pool release];
}

- (NSRect) cellRectForRect: (NSRect)r
{
	int originx = r.origin.x / _fontWidth;
	int originy = r.origin.y / _fontHeight;
	int width = ((r.size.width + r.origin.x) / _fontWidth) - originx + 1;
	int height = ((r.size.height + r.origin.y) / _fontHeight) - originy + 1;
	return NSMakeRect(originx, originy, width, height);
}

- (void) drawRect: (NSRect)rect
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    YLTerminal *ds = [self frontMostTerminal];
        
	if ([self connected]) {
        /* Draw the backed image */
		NSRect imgRect = rect;
		imgRect.origin.y = (_fontHeight * gRow) - rect.origin.y - rect.size.height;
		[_backedImage drawAtPoint: rect.origin fromRect: rect operation: NSCompositeCopy fraction: 1.0];

        [self drawBlink];
        
        /* Draw the url underline */
        int c, r;
        [[NSColor orangeColor] set];
        [NSBezierPath setDefaultLineWidth: 1.0];
        for (r = 0; r < gRow; r++) {
            cell *currRow = [ds cellsOfRow: r];
            for (c = 0; c < gColumn; c++) {
                int start;
                for (start = c; c < gColumn && currRow[c].attr.f.url; c++) ;
                if (c != start) {
                    [NSBezierPath strokeLineFromPoint: NSMakePoint(start * _fontWidth, (gRow - r - 1) * _fontHeight + 0.5) 
                                              toPoint: NSMakePoint(c * _fontWidth, (gRow - r - 1) * _fontHeight + 0.5)];
                }
            }
        }
        
		/* Draw the cursor */
		[[NSColor whiteColor] set];
		[NSBezierPath setDefaultLineWidth: 2.0];
		[NSBezierPath strokeLineFromPoint: NSMakePoint([ds cursorColumn] * _fontWidth, (gRow - 1 - [ds cursorRow]) * _fontHeight + 1) 
								  toPoint: NSMakePoint(([ds cursorColumn] + 1) * _fontWidth, (gRow - 1 - [ds cursorRow]) * _fontHeight + 1) ];
        [NSBezierPath setDefaultLineWidth: 1.0];
        _x = [ds cursorColumn], _y = [ds cursorRow];

        /* Draw the selection */
        if (_selectionLength != 0) 
            [self drawSelection];
	} else {
		[[gConfig colorBG] set];
        
        NSRect r = [self bounds];
		NSRectFill(r);
	}
	
    [pool release];
}

- (void) drawBlink
{
    int c, r;
    if (![gConfig blinkTicker]) return;
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    id ds = [self frontMostTerminal];
    if (!ds) {
        [pool drain];
        return;
    }
    for (r = 0; r < gRow; r++) {
        cell *currRow = [ds cellsOfRow: r];
        for (c = 0; c < gColumn; c++) {
            if (isBlinkCell(currRow[c])) {
                int bgColorIndex = currRow[c].attr.f.reverse ? currRow[c].attr.f.fgColor : currRow[c].attr.f.bgColor;
                BOOL bold = currRow[c].attr.f.reverse ? currRow[c].attr.f.bold : NO;
                [[gConfig colorAtIndex: bgColorIndex hilite: bold] set];
                NSRectFill(NSMakeRect(c * _fontWidth, (gRow - r - 1) * _fontHeight, _fontWidth, _fontHeight));
            }
        }
    }
    [pool drain];
}

- (void) drawSelection
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
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
    [pool release];
}

/* 
	Extend Bottom:
 
		AAAAAAAAAAA			BBBBBBBBBBB
		BBBBBBBBBBB			CCCCCCCCCCC
		CCCCCCCCCCC   ->	DDDDDDDDDDD
		DDDDDDDDDDD			...........
 
 */
- (void) extendBottomFrom: (int)start to: (int)end
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
	[_backedImage lockFocus];
	[_backedImage drawAtPoint: NSMakePoint(0, (gRow - end) * _fontHeight)
                     fromRect: NSMakeRect(0, (gRow - end - 1) * _fontHeight, gColumn * _fontWidth, (end - start) * _fontHeight)
                    operation: NSCompositeCopy
                     fraction: 1.0];

	[[gConfig colorAtIndex:gConfig.bgColorIndex hilite:NO] set];
	NSRectFill(NSMakeRect(0, (gRow - end - 1) * _fontHeight, gColumn * _fontWidth, _fontHeight));
	[_backedImage unlockFocus];
    [pool release];
}


/* 
	Extend Top:
		AAAAAAAAAAA			...........
		BBBBBBBBBBB			AAAAAAAAAAA
		CCCCCCCCCCC   ->	BBBBBBBBBBB
		DDDDDDDDDDD			CCCCCCCCCCC
 */
- (void) extendTopFrom: (int)start to: (int)end
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    [_backedImage lockFocus];
	[_backedImage drawAtPoint: NSMakePoint(0, (gRow - end - 1) * _fontHeight)
                     fromRect: NSMakeRect(0, (gRow - end) * _fontHeight, gColumn * _fontWidth, (end - start) * _fontHeight)
                    operation: NSCompositeCopy
                     fraction: 1.0];
	
	[[gConfig colorAtIndex:gConfig.bgColorIndex hilite:NO] set];
	NSRectFill(NSMakeRect(0, (gRow - start - 1) * _fontHeight, gColumn * _fontWidth, _fontHeight));
	[_backedImage unlockFocus];
    [pool release];
}

- (void) updateBackedImage
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
	int x, y;
    YLTerminal *ds = [self frontMostTerminal];
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
        CGContextSetShouldSmoothFonts(myCGContext, 
                                      gConfig.shouldSmoothFonts == YES ? true : false);
        
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
        [[NSColor clearColor] set];
        CGContextFillRect(myCGContext, CGRectMake(0, 0, gColumn * _fontWidth, gRow * _fontHeight));
    }

	[_backedImage unlockFocus];
    [pool release];
}



#pragma mark -
#pragma mark Override

- (BOOL) mouseDownCanMoveWindow
{
    return NO;
}

- (BOOL) isFlipped
{
	return NO;
}

- (BOOL) isOpaque
{
	return YES;
}

- (BOOL) acceptsFirstResponder
{
	return YES;
}

- (BOOL) canBecomeKeyView
{
    return YES;
}

//- (void) removeTabViewItem: (NSTabViewItem *)tabViewItem
//{
//    [[tabViewItem identifier] close];
//    [super removeTabViewItem: tabViewItem];
//}

+ (NSMenu *) defaultMenu {
    return [[[NSMenu alloc] init] autorelease];
}

- (NSMenu *) menuForEvent: (NSEvent *)theEvent
{
    NSMenu *menu = [[self class] defaultMenu];
    if (![self connected]) return menu;
    
    NSString *s = [self selectedPlainString];
    NSArray *a = [[YLContextualMenuManager sharedInstance] availableMenuItemForSelectionString: s];
    for(NSMenuItem *item in a) {
        [menu addItem: item];
    }
    return menu;
}

- (NSView *) hitTest: (NSPoint) p 
{
    return self; /* Otherwise, it will return the subview. */
}

#pragma mark -
#pragma mark Accessor
@synthesize x = _x;
@synthesize y = _y;

- (BOOL) connected
{
	return [[self frontMostConnection] connected];
}

- (YLTerminal *) frontMostTerminal
{
    return (YLTerminal *)[[self frontMostConnection] terminal];
}

- (YLConnection *) frontMostConnection
{
    id identifier = [[self selectedTabViewItem] identifier];
    return (YLConnection *) identifier;
}

- (NSString *) selectedPlainString
{
    if (_selectionLength == 0) return nil;
    int location, length;
    if (_selectionLength >= 0) {
        location = _selectionLocation;
        length = _selectionLength;
    } else {
        location = _selectionLocation + _selectionLength;
        length = 0 - (int)_selectionLength;
    }
    return [[self frontMostTerminal] stringFromIndex: location length: length];
}

- (BOOL) hasBlinkCell
{
    int c, r;
    id ds = [self frontMostTerminal];
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
- (void) insertText: (id)aString
{
    [self insertText: aString withDelay: 0];
}

- (void) insertText: (id)aString withDelay: (int)microsecond
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
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
            YLEncoding encoding = [[[self frontMostConnection] site] encoding];
            unichar code = (encoding == YLBig5Encoding ? U2B[ch] : U2G[ch]);
			buf[0] = code >> 8;
			buf[1] = code & 0xFF;
			[data appendBytes: buf length: 2];
		}
	}
    if (microsecond == 0) {
        [[self frontMostConnection] sendData: data];
    } else {
        int i;
        unsigned char *buf = (unsigned char *) [data bytes];
        for (i = 0; i < [data length]; i++) {
            [[self frontMostConnection] sendBytes: buf + i length: 1];
            usleep(microsecond);
        }
    }
    [pool release];
}

- (void) doCommandBySelector: (SEL)aSelector
{
	unsigned char ch[10];
    
//    NSLog(@"%s", aSelector);
    
	if (aSelector == @selector(insertNewline:)) {
		ch[0] = 0x0D;
		[[self frontMostConnection] sendBytes: ch length: 1];
    } else if (aSelector == @selector(cancelOperation:)) {
        ch[0] = 0x1B;
		[[self frontMostConnection] sendBytes: ch length: 1];
//	} else if (aSelector == @selector(cancel:)) {
	} else if (aSelector == @selector(scrollToBeginningOfDocument:)) {
        ch[0] = 0x1B; ch[1] = '['; ch[2] = '1'; ch[3] = '~';
		[[self frontMostConnection] sendBytes: ch length: 4];		
	} else if (aSelector == @selector(scrollToEndOfDocument:)) {
        ch[0] = 0x1B; ch[1] = '['; ch[2] = '4'; ch[3] = '~';
		[[self frontMostConnection] sendBytes: ch length: 4];		
	} else if (aSelector == @selector(scrollPageUp:)) {
		ch[0] = 0x1B; ch[1] = '['; ch[2] = '5'; ch[3] = '~';
		[[self frontMostConnection] sendBytes: ch length: 4];
	} else if (aSelector == @selector(scrollPageDown:)) {
		ch[0] = 0x1B; ch[1] = '['; ch[2] = '6'; ch[3] = '~';
		[[self frontMostConnection] sendBytes: ch length: 4];		
	} else if (aSelector == @selector(insertTab:)) {
        ch[0] = 0x09;
		[[self frontMostConnection] sendBytes: ch length: 1];
    } else if (aSelector == @selector(deleteForward:)) {
		ch[0] = 0x1B; ch[1] = '['; ch[2] = '3'; ch[3] = '~';
		ch[4] = 0x1B; ch[5] = '['; ch[6] = '3'; ch[7] = '~';
        int len = 4;
        id ds = [self frontMostTerminal];
        if ([[[self frontMostConnection] site] detectDoubleByte] && 
            [ds cursorColumn] < (gColumn - 1) && 
            [ds attrAtRow: [ds cursorRow] column: [ds cursorColumn] + 1].f.doubleByte == 2)
            len += 4;
        [[self frontMostConnection] sendBytes: ch length: len];
    } else {
        NSLog(@"Unprocessed selector: %@", NSStringFromSelector(aSelector));
    }
}

// setMarkedText: cannot take a nil first argument. aString can be NSString or NSAttributedString
- (void) setMarkedText: (id)aString selectedRange: (NSRange)selRange
{
    YLTerminal *ds = [self frontMostTerminal];
    if (!ds) return;

	if (![aString respondsToSelector: @selector(isEqualToAttributedString:)] && [aString isMemberOfClass: [NSString class]])
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

	NSPoint o = NSMakePoint([ds cursorColumn] * _fontWidth, (gRow - 1 - [ds cursorRow]) * _fontHeight + 5.0);
	CGFloat dy;
	if (o.x + [_textField frame].size.width > gColumn * _fontWidth) 
		o.x = gColumn * _fontWidth - [_textField frame].size.width;
	if (o.y + [_textField frame].size.height > gRow * _fontHeight) {
		o.y = (gRow - [ds cursorRow]) * _fontHeight - 5.0 - [_textField frame].size.height;
		dy = o.y + [_textField frame].size.height;
	} else {
		dy = o.y;
	}
	[_textField setFrameOrigin: o];
	[_textField setDestination: [_textField convertPoint: NSMakePoint(([ds cursorColumn] + 0.5) * _fontWidth, dy)
												fromView: self]];
	[_textField setHidden: NO];
}

- (void) unmarkText
{
	[_markedText release];
	_markedText = nil;
	[_textField setHidden: YES];
}

- (BOOL) hasMarkedText
{
	return (_markedText != nil);
}

- (NSInteger) conversationIdentifier
{
	return (NSInteger) self;
}

/* Returns attributed string at the range.  This allows input mangers to query any range in backing-store.  May return nil.
 */
- (NSAttributedString *) attributedSubstringFromRange: (NSRange)theRange
{
	if (theRange.location >= [_markedText length]) return nil;
	if (theRange.location + theRange.length > [_markedText length]) 
		theRange.length = [_markedText length] - theRange.location;
	return [[[NSAttributedString alloc] initWithString: [[_markedText string] substringWithRange: theRange]] autorelease];
}

/* This method returns the range for marked region.  If hasMarkedText == false, it'll return NSNotFound location & 0 length range.
 */
- (NSRange) markedRange
{
	return _markedRange;
}

/* This method returns the range for selected region.  Just like markedRange method, its location field contains char index from the text beginning.
 */
- (NSRange) selectedRange
{
	return _selectedRange;
}

/* This method returns the first frame of rects for theRange in screen coordindate system.
 */
- (NSRect) firstRectForCharacterRange: (NSRange)theRange
{
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
- (NSUInteger) characterIndexForPoint: (NSPoint)thePoint
{
	return 0;
}

/* This method is the key to attribute extension.  We could add new attributes through this method. NSInputServer examines the return value of this method & constructs appropriate attributed string.
 */
- (NSArray*) validAttributesForMarkedText
{
	return [NSArray array];
}

#pragma mark -
#pragma mark NSURLConnectionDelegate methods

-(void)connection: (NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSString *url = [[response URL] absoluteString];
    [connection cancel];
    [self loadUrlOfString:url];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"Error!");
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
}

@end

@implementation YLView (SwiftBridge)
- (id)swiftFrontMostTerminal {
    return [self frontMostTerminal];
}
@end
