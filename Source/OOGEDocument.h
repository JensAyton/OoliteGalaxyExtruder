//
//  OOGEDocument.h
//  GalaxyExtruder
//
//  Created by Jens Ayton on 2011-04-06.
//  Copyright 2011 the Oolite team. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OoliteBase/OoliteBase.h>

@class OOGEGalaxy, OOGEGalaxy3DView;


@interface OOGEDocument: NSDocument
{
@private
	NSTimer					*_timer;
	double					_lastTime;
}

@property IBOutlet OOGEGalaxy3DView *galaxy3DView;
@property IBOutlet NSButton *stepButton;
@property IBOutlet NSButton *runStopButton;

@property (readonly) OOGEGalaxy *galaxy;

@property (readonly) BOOL running;

- (IBAction) step:sender;
- (IBAction) runStop:sender;
- (IBAction) reset:sender;
- (IBAction) jiggle:sender;

- (IBAction) zoomIn:sender;
- (IBAction) zoomOut:sender;

@end
