//
//  MovieLayer.h
//  CGGLCompositeExample
//
//  Created by kdyke on Mon Oct 22 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <QuickTime/QuickTime.h>

@interface MovieLayer : NSObject 
{
	NSRect			_layerRect; 		// presentation rect in composite view

	void*			_ctx;
	
	GLuint			_textureWidth;
	GLuint          _textureHeight;	
	void*			_textureData;
	GLuint			_textureName;
	GLuint          _textureFormat;
	GLuint          _textureType;
	GLuint          _textureInternalFormat;
	GLuint			_textureBytesPerRow;
	GLuint          _textureBytesPerPixel;
	GLuint          _textureRowLength;
	
	NSMovie*			_movie;
	Movie				qtMovie;
	short				_movieOldVol;
	Rect				_movieRect;
	ComponentInstance	_movieVideoOut;
	GWorldPtr			_movieGWorld;
}

- (id)initWithURL:(NSURL *)movieURL;

- (NSSize)size;
- (NSRect)rect;
- (void)setMuted:(BOOL)mute;
- (void)playPause;

- (GLuint) colorTextureWidth;
- (GLuint) colorTextureHeight;	
- (void*) colorTextureData;
- (GLuint) colorTextureName;

- (void)setColorFormat:(OSType)format colorData:(unsigned char *)data colorRowBytes:(unsigned)rowBytes;
- (void)lockBits;
- (void)unlockBits;
- (void)createTextureWithContext:(void *)ctx;
- (void)dirtyTexture:(unsigned int)mask;
- (BOOL)hasTexture;
- (void)heartbeat;

@end
