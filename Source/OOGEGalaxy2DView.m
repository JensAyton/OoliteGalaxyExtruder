//
//  OOGEGalaxy2DView.m
//  GalaxyExtruder
//
//  Created by Jens Ayton on 2011-04-06.
//  Copyright 2011 the Oolite team. All rights reserved.
//

#import "OOGEGalaxy2DView.h"
#import "OOGEGalaxy.h"


@interface OOGEGalaxy2DView ()
@end


static NSPoint Transform(Vector v, NSPoint offset, float scale)
{
	return (NSPoint) { v.x * scale + offset.x, v.y * -scale + offset.y };
}


@implementation OOGEGalaxy2DView

@synthesize drawForceVectors = _drawForceVectors;


- (id) initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
	if (self != nil)
	{
		_drawForceVectors = NO;
	}
    return self;
}


- (void) drawRect:(NSRect)dirtyRect
{
	NSSize size = self.bounds.size;
	NSPoint offset = { size.width / 2, size.height / 2 };
	float scale = 1.5;
	
	[[NSColor blackColor] set];
	[NSBezierPath fillRect:dirtyRect];
	
	NSArray *systems = self.galaxy.systems;
	
	// Draw routes.
	[[NSColor darkGrayColor] set];
	for (OOGESystem *system in systems)
	{
		NSPoint p = Transform(system.position, offset, scale);
		for (OOGESystem *neighbour in system.neighbours)
		{
			if (system.index < neighbour.index)
			{
				NSPoint q = Transform(neighbour.position, offset, scale);
				
				BOOL outOfRange = [system actualDistanceTo:neighbour] > 7;
				
				if (outOfRange)  [[NSColor orangeColor] set];
				[NSBezierPath strokeLineFromPoint:p toPoint:q];
				if (outOfRange)  [[NSColor darkGrayColor] set];
			}
		}
	}
	
	// Draw unwanted routes.
	[[NSColor redColor] set];
	unsigned count = systems.count;
	for (unsigned i = 0; i < count; i++)
	{
		OOGESystem *system = [systems objectAtIndex:i];
		Vector sPos = system.position;
		for (unsigned j = i + 1; j < count; j++)
		{
			OOGESystem *other = [systems objectAtIndex:j];
			Vector oPos = other.position;
			if (distance2(sPos, oPos) < (7 * 7) && ![system hasNeighbour:other])
			{
				[NSBezierPath strokeLineFromPoint:Transform(sPos, offset, scale) toPoint:Transform(oPos, offset, scale)];
			}
		}
	}
	
	for (OOGESystem *system in systems)
	{
		Vector pos = system.position;
		NSPoint p = Transform(pos, offset, scale);
		
		if (_drawForceVectors)
		{
			[[NSColor blueColor] set];
			NSPoint f = Transform(vector_add(pos, system.force), offset, scale);
			[NSBezierPath strokeLineFromPoint:p toPoint:f];
		}
		
		if (1 || !system.constrained)  [system.color set];
		else  [[NSColor redColor] set];
		float halfSize = 2;
		
	//	OOLog(@"draw", @"Drawing system %@ at %@", system.name, NSStringFromPoint(p));
		
		NSRect r = {{ p.x - halfSize, p.y - halfSize }, { halfSize * 2, halfSize * 2 }};
		NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:r];
		[path fill];
	}
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

@end
