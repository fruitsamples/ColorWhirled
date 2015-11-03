//
//  MovieLayer.m
//  CGGLCompositeExample
//
//  Created by kdyke on Mon Oct 22 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <QuickTime/QuickTimeComponents.h>
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <OpenGL/CGLCurrent.h>
#import <sys/time.h>
#import <stdlib.h>
#import <unistd.h>

#import "MovieLayer.h"
#import "OpenGLCodecs.h"


#ifndef GL_APPLE_ycbcr_422
	#define GL_YCBCR_422_APPLE                 0x85B9
	#define GL_UNSIGNED_SHORT_8_8_APPLE        0x85BA
	#define GL_UNSIGNED_SHORT_8_8_REV_APPLE    0x85BB
#endif


@implementation MovieLayer

+ (void) initialize
{
	if ([self class] == [MovieLayer class])
	{
		OpenGLVout_DoRegister();
		OpenGLRAWCodec_DoRegister();
		OpenGLCodec_DoRegister();
	}
}


- (id) initWithURL:(NSURL *)movieURL
{
	[super init];
	_movie = [[NSMovie alloc] initWithURL:movieURL byReference:YES];
	
	if (_movie)
	{		
		OSErr err;
		
		qtMovie = [_movie QTMovie];
		
		GetMovieBox(qtMovie,&_movieRect);
		OffsetRect(&_movieRect, -_movieRect.left, -_movieRect.top);
		
		SetMovieBox(qtMovie,&_movieRect);
	//	SetMovieVolume(qtMovie, 0);
		SetMoviePlayHints(qtMovie, hintsHighQuality, hintsHighQuality);
		
		_textureWidth = _movieRect.right;
		_textureHeight = _movieRect.bottom;
		
		_layerRect = NSMakeRect(_movieRect.left,_movieRect.top,
								_movieRect.right,_movieRect.bottom);
		
		err = OpenAComponent(OpenGLVoutComponent, &_movieVideoOut);
		if (err) printf("hmm, OpenAComponent on GL video out barfed: %d\n",err);
		
		err = QTVideoOutputSetDisplayMode(_movieVideoOut, 1);
		if (err) printf("couldn't set video display mode: %d\n",err);
		
		err = QTVideoOutputBegin(_movieVideoOut);
		if (err) printf("couldn't begin video output: %d\n",err);
		
		err = QTVideoOutputGetGWorld(_movieVideoOut, &_movieGWorld);
		if (err) printf("couldn't get output video gworld: %d\n",err);
		
		{
			// Oh this is just *so amazingly evil*.
			PixMapHandle pmH = GetPortPixMap((CGrafPtr)_movieGWorld);			
			*(id *)(**pmH).baseAddr = self;
		}
		
		SetMovieVideoOutput(qtMovie, _movieVideoOut);
		
		SetMovieGWorld(qtMovie, (CGrafPtr)_movieGWorld, NULL);		
		
		GoToBeginningOfMovie(qtMovie);
		UpdateMovie(qtMovie);
		MoviesTask(qtMovie, 0L); 
		StartMovie(qtMovie);
		SetMovieActive(qtMovie, true);
	}	
	else
	{
		[self release];
		return nil;
	}	
	
	return self;
}


- (void) dealloc
{
	[_movie release];
	[super dealloc];
}


- (void) setMuted:(BOOL)mute
{
	short curVol = GetMovieVolume(qtMovie);
	
	if (mute==YES && curVol) // off
	{
		_movieOldVol = curVol;
		SetMovieVolume(qtMovie, 0);
	}

	if (mute==NO && curVol==0) // on
	{
		if (_movieOldVol == 0)
			_movieOldVol = GetMoviePreferredVolume(qtMovie);
		SetMovieVolume(qtMovie, _movieOldVol);
	}
}


- (void) playPause
{
	if (GetMovieRate(qtMovie))
		StopMovie(qtMovie);
	else
		StartMovie(qtMovie);
}


- (void) heartbeat
{
	if (IsMovieDone(qtMovie))
	{
		GoToBeginningOfMovie(qtMovie);
		StartMovie(qtMovie);
	}
	MoviesTask(qtMovie, 0);
}


- (NSSize) size
	{ return _layerRect.size; }

- (NSRect) rect
	{ return _layerRect; }


#pragma mark -


- (GLuint) colorTextureWidth
	{ return _textureWidth; }
	 
- (GLuint) colorTextureHeight;	
	{ return _textureHeight; }
	 
- (void*) colorTextureData;
	{ return _textureData; }
	 
- (GLuint) colorTextureName;
	{ return _textureName; }
	 


#pragma mark -


- (void) setColorFormat:(OSType)format colorData:(unsigned char *)data colorRowBytes:(unsigned)rowBytes
{
	printf("setColorFormat %.4s\n", (char*)&format);
	switch(format)
	{
		case '2vuy':
			_textureFormat = GL_YCBCR_422_APPLE;
			_textureType = GL_UNSIGNED_SHORT_8_8_REV_APPLE;
			_textureBytesPerPixel = 2;
			_textureInternalFormat = GL_RGB8;
			break;
		
		case 'yuvs':
			_textureFormat = GL_YCBCR_422_APPLE;
			_textureType = GL_UNSIGNED_SHORT_8_8_APPLE;
			_textureBytesPerPixel = 2;
			_textureInternalFormat = GL_RGB8;
			break;
			
		case 'ABGR':
		case 'BGRA':
		case 'oglr':
			_textureFormat = GL_BGRA;
			_textureType = GL_UNSIGNED_INT_8_8_8_8_REV;
			_textureBytesPerPixel = 4;
			_textureInternalFormat = GL_RGBA8;
			break;
	}
	_textureData = data;
	_textureBytesPerRow = rowBytes;
	_textureRowLength = rowBytes / _textureBytesPerPixel;
	if(_textureName)
		glDeleteTextures(1,&_textureName);
	_textureName = 0;
}


- (void) lockBits
{
printf("    layer lockBits\n");
	CGLSetCurrentContext(_ctx);
	[self dirtyTexture:0x01];
}


- (void) unlockBits
{
printf("    layer unlockBits\n");
}


- (void)createTextureWithContext:(void *)ctx
{
	_ctx = ctx;
	
	if (_textureData)
	{
		float priority = 0.0f;
		
		if(_textureName)
			glDeleteTextures(1, &_textureName);
		_textureName = 0;	
		glGenTextures(1, &_textureName);
		
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
		glPixelStorei(GL_UNPACK_ROW_LENGTH, _textureRowLength);
		
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureName);
		glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, _textureInternalFormat,
#if _no3dText_
			_textureWidth, _textureHeight*2, 
#else
			_textureWidth, _textureHeight, 
#endif
			0, _textureFormat, _textureType, _textureData);
		
		glPrioritizeTextures(1, &_textureName, &priority);		 
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAX_ANISOTROPY_EXT, 1.0f);					 
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	}
}


- (void)dirtyTexture:(unsigned int)mask
{
	if (_textureName && _ctx)
	{
		glPixelStorei(GL_UNPACK_ROW_LENGTH, _textureRowLength);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureName);
		glTexSubImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 0, 0,
			_textureWidth, _textureHeight, _textureFormat, _textureType, _textureData);			
	}
}


- (BOOL)hasTexture
	{ return _textureName ? YES : NO; }

@end
