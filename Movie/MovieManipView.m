

#import <QuickTime/QuickTimeComponents.h>
#import <OpenGL/CGLCurrent.h>
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <OpenGL/CGLCurrent.h>
#import <sys/time.h>
#import <stdlib.h>
#import <unistd.h>

#import "DividerView.h"
#import "ManipPanel.h"
#import "MovieManipView.h"

extern void OpenGLCodec_DoRegister(int mode);
extern void OpenGLRAWCodec_DoRegister();

/*
#ifndef GL_NV_texture_shader
  #define GL_TEXTURE_SHADER_NV               0x86DE
  #define GL_SHADER_OPERATION_NV             0x86DF
  #define GL_PREVIOUS_TEXTURE_INPUT_NV       0x86E4
  #define GL_DEPENDENT_RGB_TEXTURE_3D_NV     0x8859
#endif

#ifndef GL_APPLE_ycbcr_422
  #define GL_YCBCR_422_APPLE                 0x85B9
  #define GL_UNSIGNED_SHORT_8_8_APPLE        0x85BA
  #define GL_UNSIGNED_SHORT_8_8_REV_APPLE    0x85BB
#endif
*/

enum {
	mode_unknown	= -1,
	mode_none		= 0,
	mode_NV25		= 1,
	mode_ATI		= 2,
};
	

int	Texture_3D_mode(CGLContextObj ctx)
{
	static int mode = mode_unknown;
	if (ctx  &&  mode == mode_unknown)
	{
		mode = mode_none;
		
		const GLubyte* s = glGetString(GL_EXTENSIONS);
		
		if (strstr(s, "GL_NV_texture_shader3"))
			mode = mode_NV25;
		
		if (strstr(s, "GL_ATI_text_fragment_shader"))
			mode = mode_ATI;
		
		printf("mode = %d\n", mode);
		
		// isn't "GL_EXT_texture_rectangle" also needed?
	}
	return mode;
}


@implementation MovieManipView

- (void) _init
{
	long one = 1;
	
	[[self openGLContext] setValues:&one forParameter:NSOpenGLCPSwapInterval];
	
	if (_timer == nil)
	{
		_timer = [[NSTimer timerWithTimeInterval:(1.0/30.0f)
					target:self selector:@selector(heartbeat:)
					userInfo:nil repeats:YES] retain];
		[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSModalPanelRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSEventTrackingRunLoopMode];
	}
	
	_clutNeedsUpdate = YES;
	_clutGridLog2 = 5;
	
	_world = [[ManipWorld newManipWorld] retain];
	[_world setDelegate:self];
	
	
	static int firstTime = 1;
	if (firstTime)
	{
	///	OpenGLRAWCodec_DoRegister();
		OpenGLCodec_DoRegister(Texture_3D_mode(CGLGetCurrentContext()));
		firstTime = 0;
	}
}

- (id) initWithCoder:(NSCoder *)coder
{
	///printf("initWithCoder MovieManipView\n");
    if (self = [super initWithCoder:coder])
		[self _init];
    return self;
}

- (id) initWithFrame: (NSRect)frame
{
	///printf("initWithFrame MovieManipView\n");
    if (self = [super initWithFrame:frame])
		[self _init];
    return self;
}

- (id) initWithFrame:(NSRect)frame pixelFormat:(NSOpenGLPixelFormat*)format;
{
	///printf("initWithFrame:pixelFormat MovieManipView\n");
    if (self = [super initWithFrame:frame pixelFormat:format])
		[self _init];
    return self;
}



- (void) viewWillMoveToWindow:(NSWindow *)newWindow;
{
	if (newWindow==NULL && _timer)
	{
		[_timer invalidate];
		[_timer release];
		_timer = nil;
	}
}


- (void) dealloc
{
	[_timer invalidate];
	[_timer release];
	[_world setDelegate:nil];
	[_world release];
	[_movie release];
	[super dealloc];
}


- (void) setFile:(NSString *)fileName;
{
	OSErr  err = noErr;
	NSURL* url = [NSURL fileURLWithPath:fileName];
	
	_movie = [[NSMovie alloc] initWithURL:url byReference:YES];
	
	if (_movie)
	{		
		_qtMovie = [_movie QTMovie];
		
		GetMovieBox(_qtMovie,&_movieRect);
		OffsetRect(&_movieRect, -_movieRect.left, -_movieRect.top);
		
		SetMovieBox(_qtMovie,&_movieRect);
		SetMoviePlayHints(_qtMovie, hintsHighQuality, hintsHighQuality);
		
		_textureWidth = _movieRect.right;
		_textureHeight = _movieRect.bottom;
		
		_movieNSRect = NSMakeRect(_movieRect.left,_movieRect.top,
								_movieRect.right,_movieRect.bottom);
		
		err = QTNewGWorldFromPtr(&_movieGWorld,
								'OGLX',		// glob->codecType,
								&_movieRect,// bounds
								NULL,		// CTabHandle
								NULL,		// GDHandle
								0,			// flags
								self,		// baseAddr
								32);		// rowBytes
		if (err) printf("couldn't make gworld: %d\n",err);
		
		SetMovieGWorld(_qtMovie, (CGrafPtr)_movieGWorld, NULL);		
		
		GoToBeginningOfMovie(_qtMovie);
	///	UpdateMovie(_qtMovie);
	///	MoviesTask(_qtMovie, 0L); 
	///	StartMovie(_qtMovie);
		SetMovieActive(_qtMovie, true);
	}	
	[self setNeedsDisplay:YES];
}


- (BOOL)isOpaque
	{ return YES; }


- (NSRect) boundsSource
{
	NSRect	rect = [self bounds];
	int		SbS = [(DividerView*)[self superview] sideBySide];
	  if (SbS == 1)	rect.size.width /= 2;
	  if (SbS == 2)	rect.size.height /= 2;
///	  if (SbS == 2)	rect.origin.y += rect.size.height;
	return NSIntegralRect(rect);
}

- (NSRect) boundsDest
{
	NSRect	rect = [self bounds];
	int		SbS = [(DividerView*)[self superview] sideBySide];
	  if (SbS == 1)	rect.size.width /= 2;
	  if (SbS == 1)	rect.origin.x += rect.size.width;
	  if (SbS == 2)	rect.size.height /= 2;
	  if (SbS == 2)	rect.origin.y += rect.size.height;
	return NSIntegralRect(rect);
}

- (NSRect) contentRect
{
	NSRect	rect = [self bounds];
	
	if ([(DividerView*)[self superview] sideBySide])
		rect.size.width /= 2;
	return NSIntegralRect(rect);
}




- (NSSize) windowWillResize:(NSWindow *)sender toSize:(NSSize)newSize
{
	NSSize	frameSize = [self bounds].size;
	NSSize	windSize = [sender frame].size;
	NSSize	imgSize = _movieNSRect.size;
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


- (NSRect) divRect:(NSRect)r
{
	float	div = [(DividerView*)[self superview] divide];
	int		divSide = [(DividerView*)[self superview] divideSide];
	
	if (divSide == 0)
	{
		r.origin.x += div*r.size.width;
		r.size.width *= (1.0-div);
	}
	if (divSide == 1)
	{
		r.origin.y += div*r.size.height;
		r.size.height *= (1.0-div);
	}
	if (divSide == 2)
	{
		r.size.width *= (1.0-div);
	}
	if (divSide == 3)
	{
		r.size.height *= (1.0-div);
	}
	
	return r;
}


- (void) print:(id)sender;
	{ [[self superview] print:sender]; }


- (void)drawRect:(NSRect)theRect
{
	int		minX, minY, maxX, maxY;
	NSRect	bounds = [self bounds];
	float	div = [(DividerView*)[self superview] divide];
	
	_ctx = CGLGetCurrentContext();
	
	if (![self hasTexture])
		[self createTextureWithContext:_ctx];
	
	minX = NSMinX(bounds);
	minY = NSMinY(bounds);
	maxX = NSMaxX(bounds);
	maxY = NSMaxY(bounds);
	
	glViewport(bounds.origin.x,bounds.origin.y,
		   bounds.size.width, bounds.size.height);
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(minX, maxX, maxY, minY, -1.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	// Assert default GL state
	glDisable(GL_ALPHA_TEST);
	glDisable(GL_BLEND);
	glDisable(GL_DEPTH_TEST);
	glDepthMask(GL_FALSE);
	glDisable(GL_TEXTURE_RECTANGLE_EXT);
//	glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
	glDisable(GL_CULL_FACE);
	
	// Clear background
	glClearColor(0.0,0.0,0.0,0.0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	// Draw unmatched movie
	[self drawLayer:NO];
	
	// Draw matched movie
	if ([(DividerView*)[self superview] sideBySide])
	{
		[self drawLayer:YES];
	}
	else if (_isNoOp==NO && div<1.0)
	{
		[self drawLayer:YES];
	}
	
	glFlush();
}


- (void)drawLayer:(BOOL)doDestSide
{	
	if (![self hasTexture])
		return;
	
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
///	glEnable(GL_BLEND);
	glEnable(GL_TEXTURE_RECTANGLE_EXT);
	
	
	#if _support_alpha_
	if (alphaTextureData && alphaTextureName)
	{		
		glActiveTextureARB(matrixEnabled ? GL_TEXTURE2_ARB : GL_TEXTURE1_ARB);				
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, alphaTextureName);
		glEnable(GL_TEXTURE_RECTANGLE_EXT);
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
		glActiveTextureARB(GL_TEXTURE0_ARB);
	}
	#endif
	
	if (doDestSide && Texture_3D_mode(_ctx) != mode_none)
	{
		if (_clutNeedsUpdate)
		{
			[self generateRemapTexture];
			_clutNeedsUpdate = NO;
		}
		
	#if _support_alpha_
		if(alphaTextureData && alphaTextureName)
		{		
			if (Texture_3D_mode(_ctx) == mode_NV25)
			{
				glActiveTextureARB(GL_TEXTURE2_ARB);
				glTexEnvi(GL_TEXTURE_SHADER_NV, GL_SHADER_OPERATION_NV, GL_TEXTURE_RECTANGLE_EXT);
				glTexEnvi(GL_TEXTURE_SHADER_NV, GL_PREVIOUS_TEXTURE_INPUT_NV, GL_TEXTURE1_ARB);
			}
		}
		else
		{
			glActiveTextureARB(GL_TEXTURE2_ARB);		
			if (Texture_3D_mode(_ctx) == mode_NV25)
				glTexEnvi(GL_TEXTURE_SHADER_NV, GL_SHADER_OPERATION_NV, GL_NONE);
			if (Texture_3D_mode(_ctx) == mode_ATI)
				glDisable(GL_TEXT_FRAGMENT_SHADER_ATI);
		}
	#endif
		
		// Bind the color matrix to texture unit 1
		glActiveTextureARB(GL_TEXTURE1_ARB);
		glEnable(GL_TEXTURE_3D); // Do we really need this?
		glBindTexture(GL_TEXTURE_3D, _clutTextureName);
		
		
		if (Texture_3D_mode(_ctx) == mode_NV25)
		{
			glTexEnvi(GL_TEXTURE_SHADER_NV, GL_SHADER_OPERATION_NV, GL_DEPENDENT_RGB_TEXTURE_3D_NV);
			glTexEnvi(GL_TEXTURE_SHADER_NV, GL_PREVIOUS_TEXTURE_INPUT_NV, GL_TEXTURE0_ARB);
			glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
			
			glActiveTextureARB(GL_TEXTURE0_ARB);
			glTexEnvi(GL_TEXTURE_SHADER_NV, GL_SHADER_OPERATION_NV, GL_TEXTURE_RECTANGLE_EXT);
			glTexEnvi(GL_TEXTURE_SHADER_NV, GL_PREVIOUS_TEXTURE_INPUT_NV, GL_TEXTURE0_ARB);
			glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
			
			glEnable(GL_TEXTURE_SHADER_NV);
		}
		if (Texture_3D_mode(_ctx) == mode_ATI)
		{
			unsigned char string_noalpha [] = {
				"!!ATIfs1.0\n \
			StartPrelimPass;\n \
				SampleMap r0, t0.str; # Get the RGB value of the source texel into r0\n \
				MOV r0, r0; # There has to be an ALU op in the preliminary pass so this is effectively a no-op\n \
			EndPass;\n \
			StartOutputPass;\n \
				SampleMap r1, r0.str; # Lookup the RGB value from the 3d color matrix at position r0(r,g,b)\n \
				MOV r0, r1; # Result fragment must be placed in r0\n \
			EndPass;\n" };
			
			unsigned char *string = string_noalpha;
			
	#if _support_alpha_
			unsigned char string_alpha [] = {
				"!!ATIfs1.0\n \
			StartPrelimPass;\n \
				SampleMap r0, t0.str; # Get the RGB value of the source texel into r0\n \
				MOV r0, r0; # There has to be an ALU op in the preliminary pass so this is effectively a no-op\n \
			EndPass;\n \
			StartOutputPass;\n \
				SampleMap r1, r0.str; # Lookup the RGB value from the 3d color matrix at position r0(r,g,b)\n \
				SampleMap r2, t2.str;\n \
				MUL r0, r1, r2;\n \
			EndPass;\n" };
			
			if (alphaTextureData && alphaTextureName)
				string = string_alpha;
	#endif
			
			// Upload the program string to OpenGL
			glProgramStringARB(GL_TEXT_FRAGMENT_SHADER_ATI, GL_PROGRAM_FORMAT_ASCII_ARB, strlen(string), string);
			
			glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

			// Enable the ATI fragment programming extension
			glEnable(GL_TEXT_FRAGMENT_SHADER_ATI);
		}
	}
	
	if ([self colorTextureData] && [self colorTextureName])
	{
		float	destMinX, destMinY, destMaxX, destMaxY;
		float	textMinX, textMinY, textMaxX, textMaxY;
		NSRect	destRect = [self boundsSource];
		NSRect	textRect = {{0,0},{[self colorTextureWidth], [self colorTextureHeight]}};
		
		if (doDestSide)
		{
			if (Texture_3D_mode(_ctx) == mode_none)
				textRect.origin.y = textRect.size.height;
			
			if ([(DividerView*)[self superview] sideBySide])
			{
				destRect = [self boundsDest];
			}
			else
			{
				destRect = [self divRect:destRect];
				textRect = [self divRect:textRect];
			}
		}
		
		destMinX = NSMinX(destRect);
		destMinY = NSMinY(destRect);
		destMaxX = NSMaxX(destRect);
		destMaxY = NSMaxY(destRect);
		
		textMinX = NSMinX(textRect);
		textMinY = NSMinY(textRect);
		textMaxX = NSMaxX(textRect);
		textMaxY = NSMaxY(textRect);
		
		glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
		glActiveTextureARB(GL_TEXTURE0_ARB);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, [self colorTextureName]);
		glBegin(GL_QUADS);
		
		// upper left
		glTexCoord2f(textMinX, textMinY);
		glMultiTexCoord2f(GL_TEXTURE1_ARB, textMinX, textMinY);
		glVertex2f(destMinX, destMinY);
		
		// upper right
		glTexCoord2f(textMaxX, textMinY);
		glMultiTexCoord2f(GL_TEXTURE1_ARB, textMaxX, textMinY);
		glVertex2f(destMaxX, destMinY);
		
		glTexCoord2f(textMaxX, textMaxY);
		glMultiTexCoord2f(GL_TEXTURE1_ARB, textMaxX, textMaxY);
		glVertex2f(destMaxX, destMaxY);
		
		glTexCoord2f(textMinX, textMaxY);
		glMultiTexCoord2f(GL_TEXTURE1_ARB, textMinX, textMaxY);
		glVertex2f(destMinX, destMaxY);
		
		glEnd();
	
	}
	
	if (doDestSide && Texture_3D_mode(_ctx) != mode_none)
	{
		glActiveTextureARB(GL_TEXTURE1_ARB);
		glDisable(GL_TEXTURE_3D);
		
		if (Texture_3D_mode(_ctx) == mode_NV25)
			glDisable(GL_TEXTURE_SHADER_NV);
		
		if (Texture_3D_mode(_ctx) == mode_ATI)
			glDisable(GL_TEXT_FRAGMENT_SHADER_ATI);
		
		glActiveTextureARB(GL_TEXTURE0_ARB);
	}
	
	glDisable(GL_BLEND);
	glDisable(GL_TEXTURE_RECTANGLE_EXT);
}


- (void) viewDidBecomeMain
{ 
	[[ManipPanel sharedManipPanel] setWorld:_world];
	[self setMuted:NO];
}

- (void) viewDidResignMain
	{ [self setMuted:YES]; }



- (void) ManipWorldDidChange:(id)sender
{
	_isNoOp = [_world MatchIsNoOp];
	
	_clutNeedsUpdate = YES;
	[self unlockBits];
	
	[self setNeedsDisplay:YES];
}


#pragma mark -


- (BOOL) acceptsFirstMouse:(NSEvent *)theEvent;
	{ return YES; }

- (void) keyDown:(NSEvent *)event;
{
	unichar			ch = [[event characters] characterAtIndex:0];
//	unsigned int	modflags = [event modifierFlags];
//	BOOL			opt = ((modflags & NSAlternateKeyMask)!=0);
//	BOOL			cmd = ((modflags & NSCommandKeyMask)!=0);
	
	if (ch == ' ')
		[self playPause];
	else if (ch == NSLeftArrowFunctionKey)
	{
		// if opt goto beginning
		// if cmd play backwards
		// else back frame
	}
	else if (ch == NSRightArrowFunctionKey)
	{
		// if opt goto end
		// if cmd play forward
		// else advance frame
	}
	else if (ch == NSUpArrowFunctionKey)
	{
		// if opt full volume
		// else up volume
	}
	else if (ch == NSDownArrowFunctionKey)
	{
		// if opt zero volume
		// else down volume
	}
	else
		[super keyDown:event];
}


#pragma mark -


- (void) setMuted:(BOOL)mute
{
	short curVol = GetMovieVolume(_qtMovie);
	
	if (mute==YES && curVol) // off
	{
		_movieOldVol = curVol;
		SetMovieVolume(_qtMovie, 0);
	}

	if (mute==NO && curVol==0) // on
	{
		if (_movieOldVol == 0)
			_movieOldVol = GetMoviePreferredVolume(_qtMovie);
		SetMovieVolume(_qtMovie, _movieOldVol);
	}
}


- (void) playPause
{
	if (GetMovieRate(_qtMovie))
		StopMovie(_qtMovie);
	else
		StartMovie(_qtMovie);
}


- (void) heartbeat:(NSTimer*)timer
{
	if (IsMovieDone(_qtMovie))
	{
		GoToBeginningOfMovie(_qtMovie);
		StartMovie(_qtMovie);
	}
	MoviesTask(_qtMovie, 0);
	[self setNeedsDisplay:YES];
	[self displayIfNeeded];
}


#pragma mark -


- (GLuint) colorTextureWidth
	{ return _textureWidth; }
	 
- (GLuint) colorTextureHeight;	
	{ return _textureHeight; }
	 
- (void*) colorTextureData;
	{ return _textureData; }
	 
- (GLuint) colorTextureName;
	{ return _textureName; }
	 

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
			_textureWidth, _textureHeight * (Texture_3D_mode(_ctx) == mode_none ? 2 : 1),
			0, _textureFormat, _textureType, _textureData);
		
		glPrioritizeTextures(1, &_textureName, &priority);		 
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAX_ANISOTROPY_EXT, 1.0f);					 
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	}
}


- (BOOL) hasTexture
	{ return _textureName ? YES : NO; }


- (void) generateRemapTexture
{
	GLuint				clutGrid = (1L << _clutGridLog2);
	
	// dispose old
	if (_clutData) free(_clutData);
	
	_clutData = [_world copyTextureData:clutGrid];
	if (_clutData)
	{
		if (!_clutTextureName)
			glGenTextures(1, &_clutTextureName);
		
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
		glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
		
		glBindTexture(GL_TEXTURE_3D, _clutTextureName);
		glTexImage3D(GL_TEXTURE_3D, 0, GL_RGBA, clutGrid, clutGrid, clutGrid, 0, GL_RGBA, GL_UNSIGNED_BYTE, _clutData);
		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);	
	}
}


#pragma mark -


- (void) setColorFormat:(OSType)format colorData:(unsigned char *)data colorRowBytes:(unsigned)rowBytes
{
	switch(format)
	{
		case '2vuy': // Component Y'CbCr 8-bit 4:2:2, ordered Cb Y'0 Cr Y'1
			_textureFormat = GL_YCBCR_422_APPLE;
			_textureType = GL_UNSIGNED_SHORT_8_8_REV_APPLE;
			_textureBytesPerPixel = 2;
			_textureInternalFormat = GL_RGB8;
			break;
		
		case 'yuvs': // kComponentVideoUnsigned
			_textureFormat = GL_YCBCR_422_APPLE;
			_textureType = GL_UNSIGNED_SHORT_8_8_APPLE;
			_textureBytesPerPixel = 2;
			_textureInternalFormat = GL_RGB8;
			break;
			
		case 'raw ':
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
	if (_textureName && _ctx)
	{
		// dirty the texture
		CGLSetCurrentContext(_ctx);
		glPixelStorei(GL_UNPACK_ROW_LENGTH, _textureRowLength);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureName);
		glTexSubImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 0, 0,
			_textureWidth, _textureHeight, _textureFormat, _textureType, _textureData);			
	}
}


- (void) unlockBits
{
	if (Texture_3D_mode(_ctx) == mode_none)
	{
		CMBitmap s = {
			_textureData,        // image
			_textureWidth,       // width
			_textureHeight,      // height
			_textureBytesPerRow, // rowBytes
			32,                  // pixelSize
			cmARGB32Space,       // space
			0,0};                // user1,user2
		
		CMBitmap d = s;
		d.image = ((char*)_textureData) + (_textureBytesPerRow*_textureHeight);
		
		[_world MatchBitmap:&s toBitmap:&d];
	}
}


- (CGLContextObj) glContext
	{ return _ctx; }

@end
