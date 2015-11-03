

#import "DividerView.h"
#import "ImageManipView.h"
#import "ManipPanel.h"


@implementation ImageManipView

- (void) _init
{
	_world = [[ManipWorld newManipWorld] retain];
	[_world setDelegate:self];
}

- (id) initWithCoder:(NSCoder *)coder
{
	///printf("initWithCoder ImageManipView\n");
    if (self = [super initWithCoder:coder])
		[self _init];
    return self;
}

- (id) initWithFrame: (NSRect)frame
{
	///printf("initWithFrame ImageManipView\n");
    if (self = [super initWithFrame:frame])
		[self _init];
    return self;
}


- (void)dealloc
{
	[_image release];
	[_world setDelegate:nil];
	[_world release];
	[_copy release];
	[super dealloc];
}


- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent;
	{ return YES; }


- (BOOL)isOpaque
	{ return YES; }


- (NSRect) boundsSource
{
	NSRect	rect = [self bounds];
	int		SbS = [(DividerView*)[self superview] sideBySide];
	  if (SbS == 1)	rect.size.width /= 2;
	  if (SbS == 2)	rect.size.height /= 2;
	  if (SbS == 2)	rect.origin.y += rect.size.height;
	return NSIntegralRect(rect);
}

- (NSRect) boundsDest
{
	NSRect	rect = [self bounds];
	int		SbS = [(DividerView*)[self superview] sideBySide];
	  if (SbS == 1)	rect.size.width /= 2;
	  if (SbS == 1)	rect.origin.x += rect.size.width;
	  if (SbS == 2)	rect.size.height /= 2;
	return NSIntegralRect(rect);
}

- (NSRect) boundsDestClipped
{
	NSRect	rect = [self boundsDest];
	int		SbS = [(DividerView*)[self superview] sideBySide];
	if (SbS==0)
	{
		float	div = [(DividerView*)[self superview] divide];
		int		divSide = [(DividerView*)[self superview] divideSide];
		
		if (divSide == 0)
		{
			rect.origin.x += div*rect.size.width;
			rect.size.width *= (1.0-div);
		}
		if (divSide == 1)
		{
			rect.size.height *= (1.0-div);
		}
		if (divSide == 2)
		{
			rect.size.width *= (1.0-div);
		}
		if (divSide == 3)
		{
			rect.origin.y += div*rect.size.height;
			rect.size.height *= (1.0-div);
		}
	}
	return NSIntegralRect(rect);
}


- (NSSize) windowWillResize:(NSWindow *)sender toSize:(NSSize)newSize
{
	NSSize	frameSize = [self bounds].size;
	NSSize	windSize = [sender frame].size;
	NSSize	imgSize = [_image size];
	float	dw, dh, aspect;
	
	// calc margins
	dw = windSize.width - frameSize.width;
	dh = windSize.height - frameSize.height;
	
	// subtract margins from newSize
	newSize.width -= dw;
	newSize.height -= dh;
	
	if ([(DividerView*)[self superview] sideBySide]==1)
		imgSize.width *= 2;
	
	if ([(DividerView*)[self superview] sideBySide]==2)
		imgSize.height *= 2;
	
	// constrain to aspect
	aspect = imgSize.height / imgSize.width;
	newSize.width = (newSize.width + aspect*newSize.height)/(aspect*aspect +1);
	newSize.height = aspect * newSize.width;
	
	// add margins
	newSize.width += dw;
	newSize.height += dh;
	
	return newSize;
}


- (void) drawRect:(NSRect)clipRect
{
	NSRect	bounds = [self bounds];
	float	div = [(DividerView*)[self superview] divide];
	
	[[NSColor blackColor] set];
	[NSBezierPath fillRect:bounds];
	
	// Draw unmatched image
	[_image drawInRect:[self boundsSource]];
	
	// Draw matched image
	if ([(DividerView*)[self superview] sideBySide]) // ==1 or ==2
	{
		[_copy drawInRect:[self boundsDest]];
	}
	else if (_isNoOp==NO && div<1.0)
	{
		NSRectClip([self boundsDestClipped]);
		[_copy drawInRect:[self boundsDest]];
	}
}


- (void) setFile:(NSString *)fileName;
{
	NSData*				prof = nil;
	NSSize				pixelSize;
	float				maxPixs = 500*500;
	NSBitmapImageRep*	rep = nil;
	
	// Out with the old...
	[_image autorelease];
	[_copy autorelease];
	_image = _copy = nil;
	
	// and in with the new
	rep = [[NSImageRep imageRepWithContentsOfFile:fileName] retain];
	require(rep, bail);
	require([rep class] == [NSBitmapImageRep class], bail);
	
	prof = [rep valueForProperty:NSImageColorSyncProfileData];
	if (prof)
	{
		[_world setEmbeddedProf:[Profile profileWithData:prof]];
		
		// Remove the profile from the rep so that we can
		// match with it other profiles if desired
		[rep setProperty:NSImageColorSyncProfileData withValue:nil];
		 
#if 0
		// If the above doesnt work (on Puma?) then we can make
		// a new rep from just the pixels of the original rep
		NSBitmapImageRep*	temp = nil;
		unsigned char *		planes[5] = {};
		
		[rep getBitmapDataPlanes:planes];
		temp = [[NSBitmapImageRep alloc]
					initWithBitmapDataPlanes:planes 
								  pixelsWide:[rep pixelsWide] 
								  pixelsHigh:[rep pixelsHigh] 
							   bitsPerSample:[rep bitsPerSample] 
							 samplesPerPixel:[rep samplesPerPixel] 
									hasAlpha:[rep hasAlpha]
									isPlanar:[rep isPlanar] 
							  colorSpaceName:[rep colorSpaceName]
								 bytesPerRow:[rep bytesPerRow]
								bitsPerPixel:[rep bitsPerPixel] ];
		
		[rep autorelease];
		rep = [[NSBitmapImageRep alloc] initWithData:[temp TIFFRepresentation]];
		[temp release];
#endif
	}
	
	pixelSize.width = [rep pixelsWide];
	pixelSize.height = [rep pixelsHigh];
	
	if ((pixelSize.width*pixelSize.height)>maxPixs)
	{
		NSImage*			i = nil;
		NSCachedImageRep*	c = nil;
		float				scale = sqrt(maxPixs/(pixelSize.width*pixelSize.height));
		
		pixelSize.width = floor(pixelSize.width*scale);
		pixelSize.height = floor(pixelSize.height*scale);
			
		// Create an image with new size and other appropriate attributes
		c = [[NSCachedImageRep alloc] 
				initWithSize: pixelSize 
					   depth: NSBestDepth([rep colorSpaceName], [rep bitsPerSample], 
										  [rep bitsPerPixel], [rep isPlanar], nil) 
					separate: YES 
					   alpha: [rep hasAlpha]];
		i = [[NSImage alloc] initWithSize:pixelSize];
		[i addRepresentation:c];
		
		// Draw rep into image to resample 
		[i lockFocus];
		[rep drawInRect:[c rect]];
		[i unlockFocus];
		[i setDataRetained:YES];
		
		// convert cachedImageRep back into a bitmapImageRep
		[rep autorelease];
		rep = [[NSBitmapImageRep alloc] initWithData:[i TIFFRepresentation]];
		
		[i release];
		[c release];
	}
	
	_image = rep;
	_copy = [_image copyWithZone:nil];
	
bail:
	
	return;
}


- (void) viewDidBecomeMain
	{ [[ManipPanel sharedManipPanel] setWorld:_world]; }

- (void) viewDidResignMain
	{ }


- (void) ManipWorldDidChange:(id)sender
{
	_isNoOp = [_world MatchIsNoOp];
	[_world MatchBitmapRep:_image toBitmapRep:_copy];
	[self setNeedsDisplay:YES];
}


- (CMBitmap) ManipWorldGetBitmap:(id)sender;
{
	CMBitmap bm = {};
	bm.image = [_image bitmapData];
	bm.width = [_image pixelsWide];
	bm.height = [_image pixelsHigh];
	bm.rowBytes = [_image bytesPerRow];
	bm.pixelSize = [_image bitsPerPixel];
	bm.space = cmRGB24Space;
	return bm;
}

@end
