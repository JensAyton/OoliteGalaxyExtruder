//
//  OOGEGalaxy.h
//  GalaxyExtruder
//
//  Created by Jens Ayton on 2011-04-06.
//  Copyright 2011 the Oolite team. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OoliteBase/OoliteBase.h>

@class OOGESystem;


@interface OOGEGalaxy: NSObject
{
@private
	NSArray							*_propertyList;
	__strong struct OOGESystemRep	*_systems;
	NSArray							*_wrappers;
	RANROTSeed						_seed;
	
	float							_damping;
	float							_neighbourWeight;
	float							_pinWeight;
}

@property (readonly) NSArray *systems;

@property float damping;
@property float drag;
@property float neighbourWeight;
@property float pinWeight;
@property float constraintWeight;
@property float antiGravityStrength;


+ (id) galaxyFromPropertyList:(id)propertyList error:(NSError **)outError;

#ifndef NDEBUG
- (NSString *) debugGraphViz;
#endif

- (OOGESystem *) systemAtIndex:(unsigned)index;


- (void) jiggleWithScale:(float)scale;

- (void) simulateWithStep:(float)timeStep;

- (void) reset;

@end


@interface OOGESystem: NSObject
{
@private
	unsigned						_index;
	struct OOGESystemRep			*_rep;
	OOGEGalaxy						*_owningGalaxy;
	NSDictionary					*_plist;
}

@property (readonly) unsigned index;
@property (readonly) NSString *name;
@property Vector position;
@property (readonly) Vector originalPosition;
@property (readonly) Vector velocity;
@property (readonly) Vector force;
@property (readonly) NSColor *color;
@property (readonly) NSArray *neighbours;

@property (readonly, getter=isConstrained) BOOL constrained;

- (float) desiredDistanceTo:(OOGESystem *)other;
- (float) actualDistanceTo:(OOGESystem *)other;

- (BOOL) hasNeighbour:(OOGESystem *)other;

- (void) getColorComponents:(float[4])components;

@end


extern NSString * const kOOGEGalaxyChangedNotification;


extern NSString * const kOOGEGalaxyErrorDomain;

enum
{
	kOOGEGalaxyStructureInvalidError = 1
};
