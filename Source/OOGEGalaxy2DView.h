//
//  OOGEGalaxy2DView.h
//  GalaxyExtruder
//
//  Created by Jens Ayton on 2011-04-06.
//  Copyright 2011 the Oolite team. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class OOGEGalaxy;


@interface OOGEGalaxy2DView: NSView
{
@private
	OOGEGalaxy					*_galaxy;
}

@property OOGEGalaxy *galaxy;

@property BOOL drawForceVectors;

@end
