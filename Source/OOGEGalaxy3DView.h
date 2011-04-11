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
	Vector							_dragPoint;
	OOMatrix						_cameraRotation;
	float							_drawDistance;
	
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

@property (nonatomic) OOGEGalaxy *galaxy;

@property (nonatomic) BOOL drawForceVectors;
@property (nonatomic) BOOL drawOriginalGrid;
@property (nonatomic) BOOL drawGrid;
@property (nonatomic) BOOL drawStars;
@property (nonatomic) BOOL drawHeightVectors;
@property (nonatomic) BOOL drawConflicts;


- (IBAction) zoomIn:sender;
- (IBAction) zoomOut:sender;

@end
