//
//	OOGEDocument.m
//	GalaxyExtruder
//
//	Created by Jens Ayton on 2011-04-06.
//	Copyright 2011 the Oolite team. All rights reserved.
//

#import "OOGEDocument.h"
#import "OOGEGalaxy.h"
#import "OOGEGalaxy2DView.h"
#import "OOGEGalaxy3DView.h"


@interface OOGEDocument ()

@property (readwrite) OOGEGalaxy *galaxy;

- (void) start;
- (void) stop;

@end


@implementation OOGEDocument

@synthesize galaxy = _galaxy, galaxy2DView = _galaxy2DView, galaxy3DView = _galaxy3DView, stepButton = _stepButton, runStopButton = _runStopButton;


- (void) finalize
{
	[_timer invalidate];
	
	[super finalize];
}


- (void) close
{
	[self stop];
	[super close];
}


- (NSString *) windowNibName
{
	// Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
	return @"OOGEDocument";
}


- (void) windowControllerDidLoadNib:(NSWindowController *)windowController
{
	self.galaxy2DView.galaxy = self.galaxy;
	self.galaxy3DView.galaxy = self.galaxy;
}


- (NSData *) dataOfType:(NSString *)typeName error:(NSError **)outError
{
	if ([typeName isEqualToString:@"JSON Document"])
	{
		[self stop];
		id plist = [self.galaxy propertyListRepresentation];
		return [plist ooConfDataWithOptions:kOOConfGenerationJSONCompatible error:outError];
	}
	else if ([typeName isEqualToString:@"Compact JSON Document"])
	{
		[self stop];
		id plist = [self.galaxy simplePropertyListRepresentation];
		return [plist ooConfDataWithOptions:kOOConfGenerationJSONCompatible | kOOConfGenerationSmall error:outError];
	}
	return nil;
}


- (BOOL) readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	id value = [NSObject objectFromOOConfData:data error:outError];
	if (value != nil)  self.galaxy = [OOGEGalaxy galaxyFromPropertyList:value error:outError];
	[self.galaxy jiggleWithScale:0.1];
	return self.galaxy != nil;
}


+ (NSArray *) writableTypes
{
	NSMutableArray *result = [[super writableTypes] mutableCopy];
	[result addObject:@"Compact JSON Document"];
	return result;
}


- (BOOL)  running
{
	return _timer != nil;
}


- (IBAction) step:sender
{
	[self.galaxy simulateWithStep:0.1];
	[self updateChangeCount:NSChangeDone];
}


- (void) start
{
	[self.stepButton setEnabled:NO];
	[self.runStopButton setTitle:NSLocalizedString(@"Stop", NULL)];
	_lastTime = [[NSDate date] timeIntervalSinceReferenceDate];
	
	_timer = [NSTimer timerWithTimeInterval:0.03 target:self selector:@selector(runStep) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}


- (void) stop
{
	[self.stepButton setEnabled:YES];
	[self.runStopButton setTitle:NSLocalizedString(@"Run", NULL)];
	
	[_timer invalidate];
	_timer = nil;
}


- (IBAction) runStop:sender
{
	if (!self.running)  [self start];
	else  [self stop];
}


- (void) runStep
{
	NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
	[self.galaxy simulateWithStep:(now - _lastTime)];
	_lastTime = now;
	[self updateChangeCount:NSChangeDone];
}


- (IBAction) reset:sender
{
	[self stop];
	[self.galaxy reset];
	[self.galaxy jiggleWithScale:0.1];
	[self updateChangeCount:NSChangeDone];
}


- (IBAction) jiggle:sender
{
	[self.galaxy jiggleWithScale:1];
	[self updateChangeCount:NSChangeDone];
}

@end
