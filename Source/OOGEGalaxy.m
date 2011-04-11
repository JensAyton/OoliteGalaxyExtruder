//
//  OOGEGalaxy.m
//  GalaxyExtruder
//
//  Created by Jens Ayton on 2011-04-06.
//  Copyright 2011 the Oolite team. All rights reserved.
//

#import "OOGEGalaxy.h"


NSString * const kOOGEGalaxyErrorDomain = @"org.oolite.galaxyextruder OOGEGalaxy ErrorDomain";
NSString * const kOOGEGalaxyChangedNotification = @"org.oolite.galaxyextruder OOGEGalaxy Changed";

static void SetError(NSError **error, NSInteger code, NSString *messageFormat, ...);
static void SetErrorStructureInvalid(NSError **error);


enum
{
	kMaxNeighbours			= 18
};

#define kMaxTimeStep		0.02


typedef struct OOGESystemRep
{
	Vector					originalPosition;
	Vector					rawOriginalPosition;
	Vector					position;
	Vector					velocity;
	Vector					force;	// Physics note: we assume all nodes have the same mass, and arbitrarily set it to 1, so force == acceleration.
	uint8_t					constrained;
	uint8_t					neighbourCount;
	uint8_t					neighbours[kMaxNeighbours];
	float					neighbourDistance[kMaxNeighbours];
	OOGESystem				*wrapper;
} OOGESystemRep;


OOINLINE float DesiredDistance(OOGESystemRep *a, OOGESystemRep *b)
{
	return distanceBetweenPlanetPositions(a->rawOriginalPosition.x, a->rawOriginalPosition.y, b->rawOriginalPosition.x, b->rawOriginalPosition.y);
}


static BOOL MakeSystem(OOGESystemRep *system, OOGEGalaxy *galaxy, unsigned idx, NSDictionary *dict, NSError **outError);


@interface OOGEGalaxy ()

- (id) initWithPropertyList:(NSArray *)propertyList error:(NSError **)outError;

- (void) sendChangedNotification;


- (void) clearSimulationState;
- (void) applySpringForces;
- (void) applyAntiGravity;
- (void) integrateWithStep:(float)timeStep;
- (void) applyNeighbourConstraints;

@end


@implementation OOGEGalaxy

@synthesize systems = _wrappers;
@synthesize damping = _damping, drag = _drag, neighbourWeight = _neighbourWeight, pinWeight = _pinWeight, constraintWeight = _constraintWeight, antiGravityStrength = _antiGravityStrength;


+ (id) galaxyFromPropertyList:(id)propertyList error:(NSError **)outError
{
	if (![propertyList isKindOfClass:[NSArray class]] || [propertyList count] != 256)
	{
		SetErrorStructureInvalid(outError);
		return nil;
	}
	
	for (id element in propertyList)
	{
		if (![element isKindOfClass:[NSDictionary class]])
		{
			SetErrorStructureInvalid(outError);
			return nil;
		}
	}
	
	return [[self alloc] initWithPropertyList:propertyList error:outError];
}


- (id) initWithPropertyList:(NSArray *)propertyList error:(NSError **)outError
{
	if ((self = [super init]))
	{
		_seed = MakeRanrotSeed(arc4random());
		_damping = 0.1;
		_drag = 1;
		_neighbourWeight = 1;
		_pinWeight = 0.5;
		_constraintWeight = 0;
		_antiGravityStrength = 1;
		
		_propertyList = propertyList;
		_systems = NSAllocateCollectable(256 * sizeof (OOGESystemRep), 0);
		NSMutableArray *wrappers = [NSMutableArray arrayWithCapacity:256];
		
		// Load positions.
		unsigned i, j;
		for (i = 0; i < 256; i++)
		{
			if (!MakeSystem(&_systems[i], self, i, [propertyList objectAtIndex:i], outError))
			{
				return NO;
			}
			[wrappers addObject:_systems[i].wrapper];
		}
		
		_wrappers = [wrappers copy];
		
		// Identify neighbours and shift overlapping planets slightly.
		for (i = 0; i < 256; i++)
		{
			for (j = i + 1; j < 256; j++)
			{
				float dist = DesiredDistance(&_systems[i], &_systems[j]);
				if (dist <= 7.0f)
				{
				//	OOLog(@"load.neigbours", @"Systems %u (%@) and %u (%@) are neighbours with nominal distance %g, actual distance %g.", i, [_systems[i].wrapper name], j, [_systems[j].wrapper name], dist, distance(_systems[i].position, _systems[j].position));
					NSAssert(_systems[i].neighbourCount < kMaxNeighbours && _systems[j].neighbourCount < kMaxNeighbours, @"kMaxNeighbours is too low.");
					
					if (dist == 0.0f)
					{
						dist = 0.1;
						_systems[i].position.z += 0.05;
						_systems[j].position.z -= 0.05;
					}
					
					_systems[i].neighbours[_systems[i].neighbourCount] = j;
					_systems[i].neighbourDistance[_systems[i].neighbourCount] = dist;
					_systems[i].neighbourCount++;
					
					_systems[j].neighbours[_systems[j].neighbourCount] = i;
					_systems[j].neighbourDistance[_systems[j].neighbourCount] = dist;
					_systems[j].neighbourCount++;
				}
			}
		}
		
#ifndef NDEBUG
//		OOLog(@"load.graphviz", @"%@", [self debugGraphViz]);
#endif
	}
	
	return self;
}


#ifndef NDEBUG
- (NSString *) debugGraphViz
{
	NSMutableString *string = [NSMutableString string];
	
	[string appendString:@"graph galaxy\n{\n"];
	unsigned i, j;
	for (i = 0; i < 256; i++)
	{
		[string appendFormat:@"\tplanet_%u [label=\"%@\"]\n", i, [[[_propertyList oo_dictionaryAtIndex:i] oo_stringForKey:@"name"] oo_escapedForJavaScriptLiteral]];
	}
	
	[string appendString:@"\t\n"];
	
	for (i = 0; i < 256; i++)
	{
		for (j = 0; j < _systems[i].neighbourCount; j++)
		{
			unsigned n = _systems[i].neighbours[j];
			if (n > i)
			{
				[string appendFormat:@"\tplanet_%u -- planet_%u [weight=%g]\n", i, n, 100.0 / _systems[i].neighbourDistance[j]];
			}
		}
	}
	
	[string appendString:@"}\n"];
	
	return string;
}
#endif


- (OOGESystem *) systemAtIndex:(unsigned)index
{
	if (index < 256)  return _systems[index].wrapper;
	return nil;
}


- (void) sendChangedNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kOOGEGalaxyChangedNotification object:self];
}


- (void) jiggleWithScale:(float)scale
{
	RANROTSeed savedSeed = RANROTGetFullSeed();
	RANROTSetFullSeed(_seed);
	
	for (unsigned i = 0; i < 256; i++)
	{
		_systems[i].velocity = vector_add(_systems[i].velocity, OOVectorRandomSpatial(scale));
	}
	
	_seed = RANROTGetFullSeed();
	RANROTSetFullSeed(savedSeed);
}


- (void) reset
{
	for (unsigned i = 0; i < 256; i++)
	{
		_systems[i].velocity = kZeroVector;
		_systems[i].force = kZeroVector;
		_systems[i].position = _systems[i].originalPosition;
	}
	[self sendChangedNotification];
}


- (id) propertyListRepresentation
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:256];
	
	for (OOGESystem *system in self.systems)
	{
		NSMutableDictionary *dict = [system.propertyList mutableCopy];
		Vector position = system.position;
		position.x = position.x / 0.4 + 128;	// Undo loading transformations.
		position.y = position.y / 0.2 + 128;
		[dict setObject:$array($float(position.x), $float(position.y), $float(position.z)) forKey:@"coordinates"];
		
		position = system.rawOriginalPosition;
		[dict setObject:$array($float(position.x), $float(position.y), $float(position.z)) forKey:@"original_coodinates"];
		
		[result addObject:dict];
	}
	
	return result;
}


- (id) simplePropertyListRepresentation
{
	NSMutableArray *positions = [NSMutableArray arrayWithCapacity:256 * 3];
	for (OOGESystem *system in self.systems)
	{
		Vector position = system.position;
		[positions addObject:$float(position.x)];
		[positions addObject:$float(position.y)];
		[positions addObject:$float(position.z)];
	}
	
	NSMutableArray *neighbours = [NSMutableArray array];
	for (OOGESystem *system in self.systems)
	{
		for (OOGESystem *neighbour in system.neighbours)
		{
			if (system.index < neighbour.index)
			{
				[neighbours addObject:$int(system.index)];
				[neighbours addObject:$int(neighbour.index)];
			}
		}
	}
	
	return $dict(@"positions", positions, @"neighbours", neighbours);
}


- (void) performSimulateWithStep:(float)timeStep
{
	if (timeStep <= kMaxTimeStep)
	{
		[self clearSimulationState];
		[self applySpringForces];
		[self applyAntiGravity];
		[self applyNeighbourConstraints];
		[self integrateWithStep:timeStep];
	}
	else
	{
		[self performSimulateWithStep:timeStep * 0.5f];
		[self performSimulateWithStep:timeStep * 0.5f];
	}
}


- (void) simulateWithStep:(float)timeStep
{
	[self performSimulateWithStep:timeStep];
	
	[self sendChangedNotification];
}


- (void) clearSimulationState
{
	for (unsigned i = 0; i < 256; i++)
	{
		_systems[i].force = kZeroVector;
		_systems[i].constrained = NO;
	}
}


OOINLINE Vector SpringForce(Vector posA, Vector velA, Vector posB, Vector velB, OOScalar restLength, OOScalar springWeight, OOScalar springDamping, float powerUpThreshold)
{
	Vector deltaPosition = vector_subtract(posA, posB);
	OOScalar distance = magnitude(deltaPosition);
	if (distance > powerUpThreshold)  springWeight *= 3;
	OOScalar springForce = (restLength - distance) * springWeight;
	
	Vector deltaVelocity = vector_subtract(velA, velB);
	OOScalar dampingTerm = dot_product(deltaPosition, deltaVelocity) * springDamping / distance;
	
	Vector force = vector_multiply_scalar(deltaPosition, 1.0 / distance * (springForce - dampingTerm));
	return force;
}


- (void) applySpringForces
{
	OOScalar springWeight = self.neighbourWeight;
	OOScalar pinWeight = self.pinWeight;
	OOScalar springDamping = self.damping;
	
	if (springWeight == 0 && pinWeight == 0)  return;
	
	for (unsigned i = 0; i < 256; i++)
	{
		OOGESystemRep *system = &_systems[i];
		
		Vector pos = system->position;
		Vector sysForce = system->force;
		
		for (unsigned j = 0; j < system->neighbourCount; j++)
		{
			OOGESystemRep *neighbour = &_systems[system->neighbours[j]];
			
			Vector force = SpringForce(pos, system->velocity, neighbour->position, neighbour->velocity, system->neighbourDistance[j], springWeight, springDamping, 6.9);
			
			sysForce = vector_add(sysForce, force);
			neighbour->force = vector_subtract(neighbour->force, force);
		}
		
		Vector pinPos = system->originalPosition;
		pinPos.z = pos.z * 0.99;
		if (!vector_equal(pos, pinPos))
		{
			Vector pinForce = SpringForce(pos, system->velocity, pinPos, kZeroVector, 0, pinWeight, springDamping, 2);
			sysForce = vector_add(sysForce, pinForce);
		}
		
		system->force = sysForce;
	}
}


- (void) integrateWithStep:(float)timeStep
{
	float undrag = 1.0 - self.drag * timeStep;
	
	for (unsigned i = 0; i < 256; i++)
	{
		_systems[i].velocity = vector_multiply_scalar(vector_add(_systems[i].velocity, vector_multiply_scalar(_systems[i].force, timeStep)), undrag);
		_systems[i].position = vector_add(_systems[i].position, vector_multiply_scalar(_systems[i].velocity, timeStep));
	}
}


OOINLINE unsigned NextNeighbour(unsigned *nextNeighbourIndex, OOGESystemRep *system)
{
	if (*nextNeighbourIndex == system->neighbourCount)  return 256;
	return system->neighbours[(*nextNeighbourIndex)++];
}


- (void) applyAntiGravity
{
	float antiGravityStrength = -self.antiGravityStrength;
	if (antiGravityStrength == 0)  return;
	
	for (unsigned i = 0; i < 256; i++)
	{
		OOGESystemRep *system = &_systems[i];
		unsigned nextNeighbourIndex = 0;
		unsigned nextNeighbour = NextNeighbour(&nextNeighbourIndex, system);
		
		for (unsigned j = i + 1; j < 256; j++)
		{
			OOGESystemRep *other = &_systems[j];
			BOOL isNeighbour = (j == nextNeighbour);
			
			float dist2 = distance2(system->position, other->position);
			if (isNeighbour)
			{
				nextNeighbour = NextNeighbour(&nextNeighbourIndex, system);
			}
			else
			{
				Vector direction = vector_normal(vector_subtract(other->position, system->position));
				Vector antiGravity = vector_multiply_scalar(direction, antiGravityStrength / dist2);
				
				system->force = vector_add(system->force, antiGravity);
				other->force = vector_subtract(other->force, antiGravity);
			}
		}
	}
}


- (void) applyNeighbourConstraints
{
	float constraintWeight = self.constraintWeight;
	if (constraintWeight == 0)  return;
	
	for (unsigned i = 0; i < 256; i++)
	{
		OOGESystemRep *system = &_systems[i];
		unsigned nextNeighbourIndex = 0;
		unsigned nextNeighbour = NextNeighbour(&nextNeighbourIndex, system);
		
		for (unsigned j = i + 1; j < 256; j++)
		{
			OOGESystemRep *other = &_systems[j];
			BOOL isNeighbour = (j == nextNeighbour);
			BOOL adjust = NO;
			float adjustTarget;
			
			float dist2 = distance2(system->position, other->position);
			if (isNeighbour)
			{
				nextNeighbour = NextNeighbour(&nextNeighbourIndex, system);
				
				adjustTarget = 6.99;
				adjust = (dist2 > (adjustTarget * adjustTarget));
			}
			else
			{
				adjustTarget = 7.01;
				adjust = (dist2 < (adjustTarget * adjustTarget));
			}
			
			if (adjust)
			{
				system->constrained = YES;
				other->constrained = YES;
				
				float dist = sqrtf(dist2);
				Vector direction = vector_normal(vector_subtract(other->position, system->position));
				Vector offset = vector_multiply_scalar(direction, (dist - adjustTarget) * constraintWeight);
				
				system->force = vector_add(system->force, offset);
				other->force = vector_subtract(other->force, offset);
			}
		}
	}
}

@end


@implementation OOGESystem

- (id) initWithRep:(OOGESystemRep *)rep owner:(OOGEGalaxy *)galaxy plist:(NSDictionary *)plist index:(unsigned)idx
{
	if ((self = [super init]))
	{
		_index = idx;
		_rep = rep;
		_owningGalaxy = galaxy;	// Strong reference, because galaxy owns _rep’s memory.
		_plist = plist;
	}
	return self;
}


- (unsigned) index
{
	return _index;
}


- (NSString *) name
{
	return [_plist oo_stringForKey:@"name"];
}


- (Vector) position
{
	return _rep->position;
}


- (void) setPosition:(Vector)value
{
	_rep->position = value;
	[_owningGalaxy sendChangedNotification];
}


- (Vector) originalPosition
{
	return _rep->originalPosition;
}


- (Vector) rawOriginalPosition
{
	return _rep->rawOriginalPosition;
}


- (Vector) velocity
{
	return _rep->velocity;
}


- (Vector) force
{
	return _rep->force;
}


- (NSColor *) color
{
	float components[4];
	[self getColorComponents:components];
	return [NSColor colorWithCalibratedRed:components[0]
									 green:components[1]
									  blue:components[2]
									 alpha:components[3]];
}


- (void) getColorComponents:(float[4])components
{
	NSParameterAssert(&components[0] != NULL);
	
	NSArray *colorSpec = [_plist oo_arrayForKey:@"sun_color"];
	if (colorSpec != nil)
	{
		components[0] = [colorSpec oo_floatAtIndex:0];
		components[1] = [colorSpec oo_floatAtIndex:1];
		components[2] = [colorSpec oo_floatAtIndex:2];
		components[3] = [colorSpec oo_floatAtIndex:3];
	}
	else
	{
		components[0] = 1;
		components[1] = 1;
		components[2] = 1;
		components[3] = 1;
	}
}


- (NSArray *) neighbours
{
	OOGESystem *neighbours[kMaxNeighbours];
	for (unsigned i = 0; i < _rep->neighbourCount; i++)
	{
		neighbours[i] = [_owningGalaxy systemAtIndex:_rep->neighbours[i]];
	}
	return [NSArray arrayWithObjects:neighbours count:_rep->neighbourCount];
}


- (NSDictionary *) propertyList
{
	return _plist;
}


- (float) desiredDistanceTo:(OOGESystem *)other
{
	if (other == nil || other->_owningGalaxy != _owningGalaxy)
	{
		return NAN;
	}
	
	return DesiredDistance(_rep, other->_rep);
}


- (float) actualDistanceTo:(OOGESystem *)other
{
	return distance(self.position, other.position);
}


- (BOOL) hasNeighbour:(OOGESystem *)other
{
	unsigned targetIndex = other->_index;
	unsigned i, count = _rep->neighbourCount;
	for (i = 0; i < count; i++)
	{
		if (_rep->neighbours[i] == targetIndex)  return YES;
	}
	
	return NO;
}


- (BOOL) isConstrained
{
	return _rep->constrained;
}

@end


static BOOL MakeSystem(OOGESystemRep *system, OOGEGalaxy *galaxy, unsigned idx, NSDictionary *dict, NSError **outError)
{
	NSCParameterAssert(system != NULL && dict != nil);
	memset(system, 0, sizeof *system);
	
	NSArray *position = [dict oo_arrayForKey:@"coordinates"];
	if (position == nil || position.count < 2 || position.count > 3)
	{
		SetErrorStructureInvalid(outError);
		return NO;
	}
	
	system->position.x = [position oo_floatAtIndex:0];
	system->position.y = [position oo_floatAtIndex:1];
	system->position.z = [position oo_floatAtIndex:2];
	system->rawOriginalPosition = system->position;
	
	system->position.x = (system->position.x - 128) * 0.4;
	system->position.y = (system->position.y - 128) * 0.2;
	
	NSArray *originalPosition = [dict oo_arrayForKey:@"original_coordinates"];
	if (originalPosition != NULL)
	{
		if (originalPosition == nil || originalPosition.count < 2 || originalPosition.count > 3)
		{
			SetErrorStructureInvalid(outError);
			return NO;
		}
		
		system->originalPosition.x = [position oo_floatAtIndex:0];
		system->originalPosition.y = [position oo_floatAtIndex:1];
		system->originalPosition.z = [position oo_floatAtIndex:2];
		system->rawOriginalPosition = system->originalPosition;
		
		system->originalPosition.x = (system->position.x - 128) * 0.4;
		system->originalPosition.y = (system->position.y - 128) * 0.2;
	}
	else
	{
		system->originalPosition = system->position;
	}
	
	system->wrapper = [[OOGESystem alloc] initWithRep:system owner:galaxy plist:dict index:idx];
	
	return YES;
}



static void SetError(NSError **error, NSInteger code, NSString *messageFormat, ...)
{
	if (error != NULL)
	{
		messageFormat = NSLocalizedString(messageFormat, NULL);
		va_list args;
		va_start(args, messageFormat);
		messageFormat = [[NSString alloc] initWithFormat:messageFormat arguments:args];
		va_end(args);
		
		*error = [NSError errorWithDomain:kOOGEGalaxyErrorDomain code:code userInfo:$dict(NSLocalizedFailureReasonErrorKey, messageFormat)];
	}
}


static void SetErrorStructureInvalid(NSError **error)
{
	SetError(error, kOOGEGalaxyStructureInvalidError, @"The document is not a galaxy.");
}
