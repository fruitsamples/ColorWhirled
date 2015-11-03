

#import <AppKit/AppKit.h>
#import "ManipWorld.h"


@interface ImageManipView : NSView
{
	NSBitmapImageRep*			_image;
	NSBitmapImageRep*			_copy;
	ManipWorld*					_world;
	BOOL						_isNoOp;
}

- (void) setFile:(NSString *)fileName;

- (void) viewDidBecomeMain;
- (void) viewDidResignMain;

- (NSRect) boundsSource;
- (NSRect) boundsDest;
- (NSRect) boundsDestClipped;

- (NSSize) windowWillResize:(NSWindow *)sender toSize:(NSSize)newSize;


@end
