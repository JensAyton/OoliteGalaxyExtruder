//
//  OOGEGalaxy3DView.m
//  GalaxyExtruder
//
//  Created by Jens Ayton on 2011-04-08.
//  Copyright 2011 the Oolite team. All rights reserved.
//

#import "OOGEGalaxy3DView.h"
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import "OOGEGalaxy.h"
#import <OoliteGraphics/OoliteGraphics.h>

@interface OOGEGalaxy3DView ()

- (void) finishInit;

- (void) renderParticles;

-(void) makeTextureFromImage:(NSImage*)theImg forTexture:(GLuint*)texName;

@end


#define DRAW_AXES 1


#ifndef NDEBUG
static void CheckGLError(NSString *context);
#else
#define CheckGLError(context) do {} while (0)
#endif

#if DRAW_AXES
static void DrawAxes(BOOL inLabels, float inScale);
#else
#define DrawAxes(labels, scale) do {} while (0)
#endif


@implementation OOGEGalaxy3DView

@synthesize drawForceVectors = _drawForceVectors;


- (id)initWithCoder:(NSCoder *)inCoder
{
	if ((self = [super initWithCoder:inCoder]))
	{
		[self finishInit];
	}
	return self;
}


- (id)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame]))
	{
		[self finishInit];
    }
    return self;
}


- (void) finishInit
{
	[[self openGLContext] makeCurrentContext];
	
	glEnable(GL_MULTISAMPLE_ARB);
	glClearColor(0, 0, 0, 1);
	glPointSize(32);
	glEnable(GL_POINT_SMOOTH);
	CheckGLError(@"after initial setup");
	
	_xrot = 30;
	_yrot = -45;
	
	NSImage *texture = [NSImage imageNamed:@"oolite-star-1"];
	[self makeTextureFromImage:texture forTexture:&_texName];
	CheckGLError(@"after loading point sprite texture");
}


- (void)drawRect:(NSRect)rect
{
	[[self openGLContext] makeCurrentContext];
	
	// Set up camera
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glTranslatef(0.0f, 0.0f, -100.0f);
	
	glRotatef(_xrot, 1.0f, 0.0f, 0.0f);
	glRotatef(_yrot, 0.0f, 1.0f, 0.0f);
	glScalef(1.0, -1.0, 1.0);
	CheckGLError(@"setting up model view matrix");
	
	// Draw
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	CheckGLError(@"clearing buffers");
	
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE);
	
	[self renderParticles];
	
	CheckGLError(@"rendering particles");
	
#if DRAW_AXES
	DrawAxes(YES, 5.0f);
	CheckGLError(@"drawing axes");
#endif
	
	[[self openGLContext] flushBuffer];
	CheckGLError(@"flushing view");
}


- (void)reshape
{
	[[self openGLContext] makeCurrentContext];
	
	NSSize dimensions = self.frame.size;
	
	glViewport(0, 0, (GLsizei)dimensions.width, (GLsizei)dimensions.height);
	
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
	gluPerspective(45.0, dimensions.width / dimensions.height, 0.1, 300.0);
}


- (BOOL) isOpaque
{
	return YES;
}


- (OOGEGalaxy *) galaxy
{
	return _galaxy;
}


- (void) setGalaxy:(OOGEGalaxy *)galaxy
{
	if (galaxy != _galaxy)
	{
		if (galaxy != nil)
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:kOOGEGalaxyChangedNotification object:_galaxy];
		}
		
		_galaxy = galaxy;
		[self setNeedsDisplay:YES];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(priv_galaxyChanged) name:kOOGEGalaxyChangedNotification object:galaxy];
	}
}


- (void) priv_galaxyChanged
{
	[self setNeedsDisplay:YES];
}


- (void) renderParticles
{
	NSArray *systems = self.galaxy.systems;
	
	// Draw routes and height vectors.
	OOGLBEGIN(GL_LINES);
	for (OOGESystem *system in systems)
	{
		Vector p = system.position;
		for (OOGESystem *neighbour in system.neighbours)
		{
			if (system.index < neighbour.index)
			{
				Vector q = neighbour.position;
				
				BOOL outOfRange = [system actualDistanceTo:neighbour] > 7;
				
				if (outOfRange)  glColor3f(1.0, 0.5, 0.0);
				else  glColor3f(0.333, 0.333, 0.333);
				
				glVertex3f(p.x, p.y, p.z);
				glVertex3f(q.x, q.y, q.z);
			}
		}
		
		glColor3f(0.3, 0.1, 0.2);
		glVertex3f(p.x, p.y, p.z);
		glVertex3f(p.x, p.y, 0);
	}
	OOGLEND();
	
	// Draw unwanted routes.
	OOGL(glColor3f(1, 0, 0));
	OOGLBEGIN(GL_LINES);
	unsigned count = systems.count;
	for (unsigned i = 0; i < count; i++)
	{
		OOGESystem *system = [systems objectAtIndex:i];
		Vector p = system.position;
		for (unsigned j = i + 1; j < count; j++)
		{
			OOGESystem *other = [systems objectAtIndex:j];
			Vector q = other.position;
			if (distance2(p, q) < (7 * 7) && ![system hasNeighbour:other])
			{
				glVertex3f(p.x, p.y, p.z);
				glVertex3f(q.x, q.y, q.z);
			}
		}
	}
	OOGLEND();
	
	// Draw original positions.
	OOGL(glColor3f(0.1, 0.2, 0.2));
	OOGLBEGIN(GL_LINES);
	for (OOGESystem *system in systems)
	{
		Vector p = system.originalPosition;
		for (OOGESystem *neighbour in system.neighbours)
		{
			if (system.index < neighbour.index)
			{
				Vector q = neighbour.originalPosition;
				
				glVertex3f(p.x, p.y, p.z);
				glVertex3f(q.x, q.y, q.z);
			}
		}
	}
	OOGLEND();
	
	if (self.drawForceVectors)
	{
		// Draw force vectors.
		OOGL(glColor3f(0, 0, 1.0));
		OOGLBEGIN(GL_LINES);
		for (OOGESystem *system in systems)
		{
			Vector p = system.position;
			Vector f = vector_add(p, system.force);
			
			glVertex3f(p.x, p.y, p.z);
			glVertex3f(f.x, f.y, f.z);
		}
		OOGLEND();
	}
	
	OOGL(glEnable(GL_TEXTURE_2D));
	OOGL(glBindTexture(GL_TEXTURE_2D, _texName));
	OOGL(glEnable(GL_POINT_SPRITE));
	OOGL(glTexEnvi(GL_POINT_SPRITE, GL_COORD_REPLACE, GL_TRUE));
	
	// Draw stars.
	OOGLBEGIN(GL_POINTS);
	for (OOGESystem *system in systems)
	{
		Vector p = system.position;
		float components[4];
		[system getColorComponents:components];
		glColor4fv(components);
		glVertex3f(p.x, p.y, p.z);
	}
	OOGLEND();
	
	OOGL(glDisable(GL_POINT_SPRITE));
	OOGL(glDisable(GL_TEXTURE_2D));
}


-(void) makeTextureFromImage:(NSImage*)theImg forTexture:(GLuint*)texName
{
    NSBitmapImageRep* bitmap = [NSBitmapImageRep alloc];
    int samplesPerPixel = 0;
    NSSize imgSize = [theImg size];
	
    [theImg lockFocus];
    [bitmap initWithFocusedViewRect:NSMakeRect(0.0, 0.0, imgSize.width, imgSize.height)];
    [theImg unlockFocus];
	
    // Set proper unpacking row length for bitmap.
    glPixelStorei(GL_UNPACK_ROW_LENGTH, [bitmap pixelsWide]);
	
    // Set byte aligned unpacking (needed for 3 byte per pixel bitmaps).
    glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
	
    // Generate a new texture name if one was not provided.
    if (*texName == 0)
        glGenTextures (1, texName);
    glBindTexture (GL_TEXTURE_2D, *texName);
	
    // Non-mipmap filtering (redundant for texture_rectangle).
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,  GL_LINEAR_MIPMAP_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);
    samplesPerPixel = [bitmap samplesPerPixel];
	
    // Nonplanar, RGB 24 bit bitmap, or RGBA 32 bit bitmap.
    if(![bitmap isPlanar] && (samplesPerPixel == 3 || samplesPerPixel == 4)) {
		
        glTexImage2D(GL_TEXTURE_2D, 0,
					 samplesPerPixel == 4 ? GL_RGBA8 : GL_RGB8,
					 [bitmap pixelsWide],
					 [bitmap pixelsHigh],
					 0,
					 samplesPerPixel == 4 ? GL_RGBA : GL_RGB,
					 GL_UNSIGNED_BYTE,
					 [bitmap bitmapData]);
    } else {
        // Handle other bitmap formats.
    }
	
	
    // Clean up.
    [bitmap release];
}

@end


#if DRAW_AXES
static void DrawAxes(BOOL inLabels, float inScale)
{
	GLboolean oldLighting;
	glGetBooleanv(GL_LIGHTING, &oldLighting);
	if (oldLighting) glDisable(GL_LIGHTING);
	
	glScalef(inScale, inScale, inScale);
	
	glColor3f(1, 1, 1);
/*	glBegin(GL_POINTS);
	glVertex3f(0, 0, 0);
	glEnd();*/
	glBegin(GL_LINES);
	glColor3f(1, 0, 0);
	glVertex3f(0, 0, 0);
	glVertex3f(1, 0, 0);
	glVertex3f(1, 0, 0);
	glVertex3f(0.9, 0.05, 0);
	glVertex3f(1, 0, 0);
	glVertex3f(0.9, -0.05, 0);
	if (inLabels)
	{
		glVertex3f(1.1, 0.1, 0);
		glVertex3f(1.3, -0.1, 0);
		glVertex3f(1.1, -0.1, 0);
		glVertex3f(1.3, 0.1, 0);
	}
	
	glColor3f(0, 1, 0);
	glVertex3f(0, 0, 0);
	glVertex3f(0, 1, 0);
	glVertex3f(0, 1, 0);
	glVertex3f(0, 0.9, 0.05);
	glVertex3f(0, 1, 0);
	glVertex3f(0, 0.9, -0.05);
	if (inLabels)
	{
		glVertex3f(0, 1.1, 0.1);
		glVertex3f(0, 1.3, -0.1);
		glVertex3f(0, 1.2, -0.0);
		glVertex3f(0, 1.3, 0.1);
	}
	
	glColor3f(0, 0, 1);
	glVertex3f(0, 0, 0);
	glVertex3f(0, 0, 1);
	glVertex3f(0, 0, 1);
	glVertex3f(0.05, 0, 0.9);
	glVertex3f(0, 0, 1);
	glVertex3f(-0.05, 0, 0.9);
	if (inLabels)
	{
		glVertex3f(-0.1, 0, 1.1);
		glVertex3f(0.1, 0, 1.3);
		glVertex3f(0.1, 0, 1.1);
		glVertex3f(0.1, 0, 1.3);
		glVertex3f(-0.1, 0, 1.1);
		glVertex3f(-0.1, 0, 1.3);
	}
	glEnd();
	
	inScale = 1.0f / inScale;
	glScalef(inScale, inScale, inScale);
	
	if (oldLighting) glEnable(GL_LIGHTING);
}
#endif


#ifndef NDEBUG
static void CheckGLError(NSString *context)
{
	GLenum			errCode;
	const GLubyte	*errString = NULL;
	
	for (;;)
	{
		errCode = glGetError();
		if (errCode == GL_NO_ERROR)  break;
		
		errString = gluErrorString(errCode);
		OOLog(@"render.error", @"OpenGL error %s (%u) %@.", errString, errCode, context);
	}
}
#endif
