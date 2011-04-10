//
//  OOGEGalaxy3DView.h
//  GalaxyExtruder
//
//  Created by Jens Ayton on 2011-04-08.
//  Copyright 2011 the Oolite team. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OoliteGraphics/OoliteGraphics.h>

@class OOGEGalaxy, OOTexture;


@interface OOGEGalaxy3DView : NSOpenGLView
{
@private
	OOGEGalaxy						*_galaxy;
	GLfloat							_xrot, _yrot;
	GLuint							_texName;
	
	__strong GLfloat				*_starVBOData;
	size_t							_starVBOSize;
	GLuint							_starVBO;
	
	__strong GLfloat				*_starColorVBOData;
	GLuint							_starColorVBO;
	
	__strong GLfloat				*_originalStarVBOData;
	size_t							_originalStarVBOSize;
	GLuint							_originalStarVBO;
	
	__strong GLushort				*_routesVBOData;
	size_t							_routesVBOSize;
	GLsizei							_routesCount;
	GLuint							_routesVBO;
	
	BOOL							_starVBOUpToDate;
	BOOL							_originalStarVBOUpToDate;
	BOOL							_routesVBOUpToDate;
}

@property OOGEGalaxy *galaxy;

@property BOOL drawForceVectors;

@end
