//
//  OOGEGalaxy3DView.h
//  GalaxyExtruder
//
//  Created by Jens Ayton on 2011-04-08.
//  Copyright 2011 the Oolite team. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class OOGEGalaxy, OOTexture;


@interface OOGEGalaxy3DView : NSOpenGLView
{
@private
	OOGEGalaxy					*_galaxy;
	float						_xrot, _yrot;
	unsigned					_texName;
}

@property OOGEGalaxy *galaxy;

@property BOOL drawForceVectors;

@end
