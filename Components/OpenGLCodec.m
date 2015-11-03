/*

If your video output device cannot display a pixel format defined by QuickTime, you should include
a special decompressor, known as a transfer codec, that converts one of the supported QuickTime pixel
formats (preferably 32-bit RGB) to data that the device can display. When this transfer codec is
available, the QuickTime Image Compression Manager automatically uses it together with its built-in
decompressors. This, in turn, lets applications or other software draw any QuickTime video directly
to the video output component's graphics world.

A transfer codec is a specialized image decompressor component, and should be based on the Base Image
Decompressor.

*/

#define __PMAPPLICATION__

#include <Carbon/Carbon.h>
#include <QuickTime/QuickTime.h>
#include <OpenGL/gl.h>
#import <OpenGL/CGLCurrent.h>


// Our Private Pixel Format
// To register a new fourCC please send mail to qtfourCC@apple.com.
// Include an email address for future correspondence, the fourCC you
// would like to register, and a brief description of the fourCC format.
// For more information refer to IceFloe #20 - QuickTime Pixel Format FourCCs
// http://developer.apple.com/quicktime/icefloe/dispatch020.html
static const OSType kOpenGLPixelFormat = 'OGLX';
static const UInt8 kNumPixelFormatsSupported = 1;


// Because this is a custom codec which implements a custom pixel format, you have to provide
// all codec functionality, for example Masking(Clipping) and Scaling, yourself. QuickTime
// isn't going to do any of this work for you.
// NOTE: This example does not actually scale, but we say we do because it's expected of us.
static const long kCodecCapabilitiesFlags = codecCanMask | codecCanScale | codecCanTransform | codecCanRemapColor | codecCanRemapResolution;

// Per frame globals
typedef struct {
	long	width;
	long	height;
	long	depth;
	long	maxBytesPerRow;
	long	maxRows;
} OpenGLCodecDecompressRecord;


@interface MovieManipView
- (void) setColorFormat:(OSType)format colorData:(unsigned char *)data colorRowBytes:(unsigned)rowBytes;
- (void) lockBits;
- (void) unlockBits;
- (CGLContextObj) glContext;
@end
enum {
	mode_unknown	= -1,
	mode_none		= 0,
	mode_NV25		= 1,
	mode_ATI		= 2,
};
	

// Per instance globals
typedef struct
{
	ComponentInstance		self;
	ComponentInstance		target;
	ComponentInstance		baseCodec;
	OSType					codecType;
	OSType**				wantedDestPixelTypeH;
	ImageCodecMPDrawBandUPP drawBandUPP;
	unsigned char *			imageBuffer;
	unsigned long			imageBufferRowBytes;
	MovieManipView*			owner;
	
} OpenGLCodecGlobalsRecord, *OpenGLCodecGlobals;

/************************************************************************************/
// Setup required for ComponentDispatchHelper.c

#define IMAGECODEC_BASENAME()		OpenGLCodec_
#define IMAGECODEC_GLOBALS()		OpenGLCodecGlobals storage

#define CALLCOMPONENT_BASENAME()	IMAGECODEC_BASENAME()
#define CALLCOMPONENT_GLOBALS()		IMAGECODEC_GLOBALS()

#define COMPONENT_DISPATCH_FILE		"OpenGLCodecDispatch.h"
#define	GET_DELEGATE_COMPONENT()	(storage->baseCodec)
#define COMPONENT_UPP_SELECT_ROOT()	ImageCodec

#include <CoreServices/Components.k.h>
#include <QuickTime/ImageCodec.k.h>
#include <QuickTime/ComponentDispatchHelper.c>	// Make the dispatcher and canDo


#pragma mark -


Component OpenGLARGBComponent = nil;
Component OpenGL2VUYComponent = nil;
Component OpenGLYUVSComponent = nil;

int gMode = mode_unknown;


void OpenGLCodec_DoRegister(int mode)
{
	ComponentRoutineUPP glComponentUPP;
	ComponentDescription cd;
	
	cd.componentType = decompressorComponentType;
	cd.componentManufacturer = 'wirl';
	cd.componentFlags = 
			    codecInfoDoes32 |
				codecInfoDoes16	 |
				codecInfoDoesStretch |
				codecInfoDoesDouble  |
				codecInfoDoesMask	 |
				codecInfoDoesQuad;		// component flags
	cd.componentFlagsMask = 0;
	
	glComponentUPP = NewComponentRoutineUPP((ComponentRoutineProcPtr)OpenGLCodec_ComponentDispatch);
	
	gMode = mode;
	
	// nVidia cards don't support 3d-testure lookup on Yuv surfaces.
	// Don't register this codec's Yuv variants in this case.
	if (mode == mode_NV25)
	{
		cd.componentSubType = '2vuy';
		OpenGL2VUYComponent = RegisterComponent(&cd, glComponentUPP, 0, NULL, NULL, NULL);
		
		cd.componentSubType = 'yuvs';
		OpenGLYUVSComponent = RegisterComponent(&cd, glComponentUPP, 0, NULL, NULL, NULL);
	}
	
	cd.componentSubType = 'raw ';
	OpenGLARGBComponent = RegisterComponent(&cd, glComponentUPP, 0, NULL, NULL, NULL);
	
	// Register information about our custom pixel format with the ICM
	// Ignore any errors as this could be a duplicate registration
	ICMPixelFormatInfo pixelInfo2 = {sizeof(ICMPixelFormatInfo)};
	pixelInfo2.formatFlags = 0;
	pixelInfo2.bitsPerPixel[0] = 32;
	ICMSetPixelFormatInfo('OGLX', &pixelInfo2);
}


#pragma mark-


/* -- This Image Decompressor User the Base Image Decompressor Component --
	The base image decompressor is an Apple-supplied component
	that makes it easier for developers to create new decompressors.
	The base image decompressor does most of the housekeeping and
	interface functions required for a QuickTime decompressor component,
	including scheduling for asynchronous decompression.
*/


/************************************************************************************/
// Component Manager Calls


// Component Open Request - Required
pascal ComponentResult OpenGLCodec_Open(OpenGLCodecGlobals glob, ComponentInstance self)
{
    ComponentDescription cd;
	ComponentResult		 err;

	// Allocate memory for our globals, set them up and inform the component
	// manager that we've done so
	glob = (OpenGLCodecGlobals)NewPtrClear(sizeof(OpenGLCodecGlobalsRecord));
	if ((err = MemError())) goto bail;
	
	SetComponentInstanceStorage(self, (Handle)glob);
	glob->self	 = self;
	glob->target = self;
	
	// Open and target an instance of the base decompressor
	err	= OpenADefaultComponent(decompressorComponentType, kBaseCodecType, &glob->baseCodec);
	if (err) goto bail;

	// Set us as the base component's target
	CallComponentTarget(glob->baseCodec, self);
	
	// Record our codecType for posterity
	err = GetComponentInfo((Component)self, &cd, NULL, NULL, NULL);
	if (err) goto bail;
	
	glob->codecType	= cd.componentSubType;
//printf("codec GL(%.4s) Open \n", (char*)&glob->codecType );

	// Allocate memory for our wantedDestinationPixelType list, we fill it in during the Preflight call.
	glob->wantedDestPixelTypeH = (OSType **)NewHandle(sizeof(OSType) * (kNumPixelFormatsSupported + 1));

bail:
	return err;
}


// Component Close Request - Required
pascal ComponentResult OpenGLCodec_Close(OpenGLCodecGlobals glob, ComponentInstance self)
{
	if (glob)
	{
//printf("codec GL(%.4s) Close \n", (char*)&glob->codecType );
		if (glob->baseCodec)
			CloseComponent(glob->baseCodec);
		if (glob->wantedDestPixelTypeH)
			DisposeHandle((Handle)glob->wantedDestPixelTypeH);	
		if (glob->drawBandUPP)
			DisposeImageCodecMPDrawBandUPP(glob->drawBandUPP);
		DisposePtr((Ptr)glob);
	}
	return noErr;
}


// Component Version Request - Required
pascal ComponentResult OpenGLCodec_Version(OpenGLCodecGlobals glob)
{
	#pragma unused(glob)
	return (codecInterfaceVersion << 2) + 1;
}


// Component Register Request
pascal ComponentResult OpenGLCodec_Register(OpenGLCodecGlobals glob)
{
	#pragma unused(glob)
	// Always register
	return noErr;
}


/* Component Target Request
	Allows another component to "target" you i.e., you call another component whenever
	you would call yourself (as a result of your component being used by another component).
*/
pascal ComponentResult OpenGLCodec_Target(OpenGLCodecGlobals glob, ComponentInstance target)
{
	ComponentResult	err;

	// Tell the base component to target the instance
	err	= CallComponentTarget(glob->baseCodec, target);
	if (err) return err;

	// Remember our target
	glob->target = target;
	return noErr;
}


/* Component GetMPWorkFunction Request
	Allows your image decompressor component to perform asynchronous decompression in a 
	single MP task by taking advantage of the Base Decompressor. If you implement this 
	selector, your DrawBand function must be MP-safe. MP safety means not calling routines 
	that may move or purge memory and not calling any routines which might cause 68K code 
	to be executed. Ideally, your DrawBand function should not make any API calls whatsoever. 
	Obviously don't implement this if you're building a 68k component.
*/
pascal ComponentResult OpenGLCodec_GetMPWorkFunction(OpenGLCodecGlobals glob, ComponentMPWorkFunctionUPP *workFunction, void **refCon)
{
//printf("codec GL GetMPWorkFunction\n");
	if (NULL == glob->drawBandUPP)
		glob->drawBandUPP = 
		#if !TARGET_API_MAC_CARBON
			NewImageCodecMPDrawBandProc(OpenGLCodec_DrawBand);
		#else
			NewImageCodecMPDrawBandUPP((ImageCodecMPDrawBandProcPtr)OpenGLCodec_DrawBand);
		#endif
		
	return ImageCodecGetBaseMPWorkFunction(glob->baseCodec, workFunction, refCon, glob->drawBandUPP, glob);
}


#pragma mark-


/************************************************************************************/
// Base Component Calls


/* ImageCodecInitialize
	The first function call that your image decompressor component receives from the base 
	image decompressor is always a call to ImageCodecInitialize . In response to this call, 
	your image decompressor component returns an ImageSubCodecDecompressCapabilities 
	structure that specifies its capabilities.
*/
pascal ComponentResult OpenGLCodec_Initialize(OpenGLCodecGlobals glob, ImageSubCodecDecompressCapabilities *cap)
{
	#pragma unused(glob)
	cap->decompressRecordSize = sizeof(OpenGLCodecDecompressRecord);
	cap->canAsync = true;
	return noErr;
}


/* ImageCodecPreflight
	The base image decompressor gets additional information about the capabilities of your 
	image decompressor component by calling ImageCodecPreflight. The base image decompressor 
	uses this information when responding to a call to the ImageCodecPredecompress function,
	which the ICM makes before decompressing an image. You are required only to provide 
	values for the wantedDestinationPixelSize and wantedDestinationPixelTypes fields and 
	can also modify other fields if necessary.
*/
pascal ComponentResult OpenGLCodec_Preflight(OpenGLCodecGlobals glob, CodecDecompressParams *p)
{
	OSTypePtr		  formats = *glob->wantedDestPixelTypeH;
	
///printf("codec GL Preflight\n");
	// Fill in formats for wantedDestPixelTypeH - terminate with 0
	formats[0] = kOpenGLPixelFormat;
	formats[1] = 0;
	
	// The base codec adds some flags, so OR in our own flags as well
	p->capabilities->flags |= kCodecCapabilitiesFlags; 
	// | codecIsDirectToScreenOnly | codecWantsDestinationPixels;
	
	// Indicate that the codec can accept source data only from an image buffer.
	p->capabilities->flags2 |= codecSrcMustBeImageBuffer;
	
	p->capabilities->wantedPixelSize  = 0; 	
	p->capabilities->extendWidth = 0;
	p->capabilities->extendHeight = 0;
	p->wantedDestinationPixelTypes = glob->wantedDestPixelTypeH;

	return noErr;
}


/* ImageCodecBeginBand
	The ImageCodecBeginBand function allows your image decompressor component to save 
	information about a band before decompressing it. This function is never called at 
	interrupt time. The base image decompressor preserves any changes your component 
	makes to any of the fields in the ImageSubCodecDecompressRecord or CodecDecompressParams 
	structures. If your component supports asynchronous scheduled decompression, it may 
	receive more than one ImageCodecBeginBand call before receiving an ImageCodecDrawBand call.
*/
pascal ComponentResult OpenGLCodec_BeginBand(OpenGLCodecGlobals glob, CodecDecompressParams *p, ImageSubCodecDecompressRecord *drp, long flags)
{
	#pragma unused(glob, flags)
//printf("codec GL BeginBand\n");
	return noErr;
}


/* ImageCodecDrawBand
	The base image decompressor calls your image decompressor component's ImageCodecDrawBand 
	function to decompress a band or frame. Your component must implement this function. 
	If the ImageSubCodecDecompressRecord structure specifies a progress function or 
	data-loading function, the base image decompressor will never call ImageCodecDrawBand
	at interrupt time. If the ImageSubCodecDecompressRecord structure specifies a progress 
	function, the base image decompressor handles codecProgressOpen and codecProgressClose 
	calls, and your image decompressor component must not implement these functions.
	You can however optionally implement the codecProgressUpdatePercent function to provide 
	progress information during lengthy decompression operations.  If the 
	ImageSubCodecDecompressRecord structure does not specify a progress function the base 
	image decompressor may call the ImageCodecDrawBand function at interrupt time.
	When the base image decompressor calls your ImageCodecDrawBand function, your component 
	must perform the decompression specified by the fields of the ImageSubCodecDecompressRecord 
	structure. The structure includes any changes your component made to it when performing 
	the ImageCodecBeginBand function. If your component supports asynchronous scheduled 
	decompression, it may receive more than one ImageCodecBeginBand call before receiving an 
	ImageCodecDrawBand call.
*/
pascal ComponentResult OpenGLCodec_DrawBand(OpenGLCodecGlobals glob, ImageSubCodecDecompressRecord *drp)
{
#pragma unused(glob)
//printf("codec GL DrawBand\n");
	return noErr;
}


#pragma mark -


/************************************************************************************/


// Codec Component Calls

/* ImageCodecGetCodecInfo
	Your component receives the ImageCodecGetCodecInfo request whenever an application 
	calls the Image Compression Manager's GetCodecInfo function. Your component should 
	return a formatted compressor information structure defining its capabilities.
	Both compressors and decompressors may receive this request.
*/
pascal ComponentResult OpenGLCodec_GetCodecInfo(OpenGLCodecGlobals glob, CodecInfo *info)
{
	if (!info) return paramErr;
	
	c2pstrcpy((unsigned char *)info->typeName,"OpenGL Output Codec");
	info->version = 0x0001;
	info->revisionLevel = 0x0001;
	info->vendor = 'wirl';
	info->decompressFlags = 
				codecInfoDoes32 |
				codecInfoDoes16	 |
				codecInfoDoesStretch |
				codecInfoDoesDouble  |
				codecInfoDoesMask	 |
				codecInfoDoesQuad;		// component flags
	info->compressFlags = 0,
	info->formatFlags = codecInfoDepth16 | codecInfoDepth32 | codecInfoDoesLossless;
	info->compressionAccuracy = 100;
	info->decompressionAccuracy = 100;
	info->compressionSpeed = 1;
	info->decompressionSpeed = (glob->codecType == 'raw ') ? 20 : 10;
	info->compressionLevel = 0;
	info->resvd = 0;
	info->minimumHeight = 2;
	info->minimumWidth = 2;
	info->decompressPipelineLatency = 0;
	info->compressPipelineLatency = 0;
	info->privateData = 0;
	
	return noErr;
}


// ImageCodecNewImageGWorld
pascal ComponentResult 
OpenGLCodec_NewImageGWorld(OpenGLCodecGlobals glob, CodecDecompressParams *p, GWorldPtr *newGW, long flags)
{
	#pragma unused(glob, flags)
	PixMapPtr	portPixMap;
  	Rect		voutRect;
  	long		pixMapType; 
	long		codecType;
  	OSErr		err = codecConditionErr;
	
printf("codec GL(%.4s) NewImageGWorld \n", (char*)&glob->codecType );
	// Make sure the destination port is our VOut. This is done by checking
	// the pixelFormat of the destination image. If the pixel format isn't ours,
	// (kOpenGLPixelFormat) it is a bogus usage of the transfer codec.
	portPixMap = *(GetPortPixMap(p->port));
	
	pixMapType = GETPIXMAPPIXELFORMAT(portPixMap);
	
	if (pixMapType == (long)kOpenGLPixelFormat)
	{
		MovieManipView* owner = (MovieManipView*)portPixMap->baseAddr;
		int Bpp = 4;
		
		voutRect.top	= voutRect.left = 0;
		voutRect.right	= p->srcRect.right - p->srcRect.left;
		voutRect.bottom	= p->srcRect.bottom - p->srcRect.top;
		
		codecType = glob->codecType;
		
		if (codecType == '2vuy' || codecType == 'yuvs' || codecType == 'yuv2')
			Bpp = 2;
		
		glob->imageBufferRowBytes = (voutRect.right * Bpp + 31) & ~31;
		glob->imageBuffer = malloc(glob->imageBufferRowBytes * 
						(gMode==mode_none ? 2 : 1) * voutRect.bottom);
		glob->owner = owner;
		
		err	= QTNewGWorldFromPtr(newGW,
					(codecType=='raw ') ? 32 : codecType,
					&voutRect,							// bounds
					nil, nil,							// CTabHandle, GDHandle
					0,									// flags
					glob->imageBuffer,
					glob->imageBufferRowBytes);
		if (err) printf("        NewImageErr: %d\n",err);
		
		[owner setColorFormat:codecType colorData:glob->imageBuffer colorRowBytes:glob->imageBufferRowBytes];
	}

	return err;
}

// ImageCodecDisposeImageGWorld
pascal ComponentResult
OpenGLCodec_DisposeImageGWorld(OpenGLCodecGlobals glob, GWorldPtr theGW)
{
	#pragma unused(glob)
//printf("codec GL(%.4s) DisposeImageGWorld \n", (char*)&glob->codecType );
	DisposeGWorld(theGW);
	
	if (glob->imageBuffer) 
	{
		free (glob->imageBuffer);
		glob->imageBuffer = nil;
	}
	
	return noErr;
}


pascal ComponentResult
OpenGLCodec_LockBits(OpenGLCodecGlobals storage, CGrafPtr port)
{
	#pragma unused(port)
	[storage->owner lockBits];
	return noErr;
}


pascal ComponentResult
OpenGLCodec_UnlockBits(OpenGLCodecGlobals storage, CGrafPtr port)
{
	#pragma unused(port)
	[storage->owner unlockBits];
	return noErr;
}
