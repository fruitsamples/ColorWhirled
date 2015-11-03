

#import <Cocoa/Cocoa.h>
#import <OpenGL/CGLCurrent.h>
#import <OpenGL/gl.h>
#import <QuickTime/QuickTime.h>

#import "ManipWorld.h"


@interface MovieManipView : NSOpenGLView
{
	CGLContextObj		_ctx;
	NSTimer*			_timer;
	
	ManipWorld*			_world;
	BOOL				_isNoOp;
	
	BOOL				_clutNeedsUpdate;
	GLuint				_clutGridLog2;
	unsigned char *		_clutData;
	GLuint				_clutTextureName;
	
	NSMovie*			_movie;
	Movie				_qtMovie;
	short				_movieOldVol;
	Rect				_movieRect;
	NSRect				_movieNSRect;
	ComponentInstance	_movieVideoOut;
	GWorldPtr			_movieGWorld;	
	
	GLuint				_textureWidth;
	GLuint				_textureHeight;	
	void*				_textureData;
	GLuint				_textureName;
	GLuint				_textureFormat;
	GLuint				_textureType;
	GLuint				_textureInternalFormat;
	GLuint				_textureBytesPerRow;
	GLuint				_textureBytesPerPixel;
	GLuint				_textureRowLength;
}

- (void) setFile:(NSString *)fileName;

- (void) viewDidBecomeMain;
- (void) viewDidResignMain;

- (NSRect) boundsSource;
- (NSRect) boundsDest;

- (NSRect) contentRect;
- (NSSize) windowWillResize:(NSWindow *)sender toSize:(NSSize)newSize;

- (NSRect) divRect:(NSRect)r;

- (void) drawLayer:(BOOL)doDestSide;

- (void) generateRemapTexture;

- (void) setMuted:(BOOL)mute;
- (void) playPause;

- (GLuint) colorTextureWidth;
- (GLuint) colorTextureHeight;	
- (void*) colorTextureData;
- (GLuint) colorTextureName;

- (void) setColorFormat:(OSType)format colorData:(unsigned char *)data colorRowBytes:(unsigned)rowBytes;
- (void) lockBits;
- (void) unlockBits;
- (CGLContextObj) glContext;
- (void) createTextureWithContext:(void *)ctx;
- (BOOL) hasTexture;
- (void) heartbeat:(NSTimer*)timer;


@end
