//
//  YLImageView.h
//  MacBlueTelnet
//
//  Created by Jjgod Jiang on 3/27/08.
//  Copyright 2008 Jjgod Jiang. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "YLImagePreviewer.h"

enum showTips { kShowTipsNone, kShowTipsWhite, kShowTipsGray };

@interface YLImageView : NSImageView {
    NSRect tipsRect;
    enum showTips tipsState;
    
    YLImagePreviewer *previewer;
}

- (id) initWithFrame: (NSRect)frame previewer: (YLImagePreviewer *)thePreviewer;
- (void) setPreviewer: (YLImagePreviewer *)thePreviewer;
- (YLImagePreviewer *)previewer;

@end
