
#import "ManipWorld.h"


#if _use_uv
#include "conversions.h" // for conv_xy_to_uv and conv_uv_to_xy
#else
#define kRadsToDeg	(180.0 / 3.141592654)
#define kDegToRads	(3.141592654 / 180.0)
#endif


#if TARGET_CARBON
	#define Log2(x)   (log(x) * 1.442695040888963)
#else
	#define Log2(x)   (log2(x))
#endif


#define _normal_sense_  0 // normal sense


#pragma options align=mac68k
typedef struct {
	OSType					cmm;
	UInt32					flags;			// specify quality, lookup only, no gamut checking ...
	UInt32					flagsMask;		// which bits of 'flags' to use to override profile
	UInt32					profileCount;	// how many ProfileSpecs in the following set
	NCMConcatProfileSpec	profileSpecs[4];// Variable. Ordered from Source -> Dest
} NCMConcatProfileSet4;
#pragma options align=reset


void move_xy (double* px, double* py, double ang, double sat)
{
	double			wx=0.3127, wy=0.3290;  // D65
	double			x=*px, y=*py;
	double			s,h;
	
	// convert x,y to s,h
#if _use_uv
	double			wu=0.19783, wv=0.46832;	// D65
	double			u,v;
	conv_xy_to_uv(x, y, &u, &v);
	u -= wu;
	v -= wv;
	s = 13 * sqrt(u*u + v*v);
	h = atan2(v,u) * kRadsToDeg;
#else
	x -= wx;
	y -= wy;
	s = sqrt(x*x + y*y);
	h = atan2(y,x) * kRadsToDeg;
#endif
	
	// apply ang,sat
	h += ang;
	s *= 1.0 + sat/200.0;
	
	// convert s,h to x,y
#if _use_uv
	u = s * cos(h*kDegToRads) / 13.0;
	v = s * sin(h*kDegToRads) / 13.0;
	conv_uv_to_xy(u+wu, v+wv, x, y);
#else
	x = s * cos(h*kDegToRads);
	y = s * sin(h*kDegToRads);
	x += wx;
	y += wy;
#endif
	
	if (x+y > 1)
	{
		x -= (x+y-1)/2.0;
		y -= (x+y-1)/2.0;
	}
	
	*px = x;
	*py = y;
}


@implementation ManipWorld

+ (ManipWorld*) newManipWorld
	{ return [[[ManipWorld alloc] init] autorelease]; }

- (id) init
{
	if (self = [super init])
	{
		_srcMode = imRGB;
		_absMode = imNone;
		_prfMode = imNone;
		_dstMode = imDisplay;
		_val[kvalLimitLo] = -100.0;
		_val[kvalLimitHi] = 100.0;
	}
	return self;
}

- (void)dealloc
{
	[_embedProf release];
	[_customProfAbs release];
	[_customProfSrc release];
	[_srcProf release];
	[_absProf release];
	[_prfProf release];
	[_dstProf release];
	if (_cw) CWDisposeColorWorld(_cw);
	[super dealloc];
}



- (id)delegate;
	{ return _delegate; }

- (void)setDelegate:(id)obj	
	{ _delegate = obj; }


- (Profile*) embeddedProf
	{ return _embedProf; }

- (void) setEmbeddedProf:(Profile*)ref
{
	[_embedProf autorelease];
	_embedProf = [ref retain];
}


- (OSType) sourceMode
	{ return _srcMode; }

- (void) setSourceMode:(OSType)type;
{
	if (type==imEmbedded && _embedProf==nil)
		type = imRGB;
	if (type == imOther && _srcProf==nil)
		type = imRGB;		
	if (type == _srcMode)
		return;
	_srcMode = type;
	_cwOK = NO;
	[self WorldDidChange];
}

- (void) setSourceProf:(Profile*)ref
{
	if (ref)
	{
		[_srcProf autorelease];
		_srcProf = [ref retain];
		[self setSourceMode:imOther];
	}
}

- (void) zeroSource
{
	int i;
	
	for (i=kvalBrightRed; i<=kvalSatBlu; i++)
		_val[i] = 0;
	
	_cwOK = NO;
	_srcMode = imCustom;
	_custSrcOK = NO;
	[self WorldDidChange];
}


- (OSType) abstactMode;
	{ return _absMode; }

- (void) setAbstractMode:(OSType)type;
{
	if (type == imOther && _absProf==nil)
		type = imCustom;		
	if (type == _absMode)
		return;
	_absMode = type;
	_cwOK = NO;
	[self WorldDidChange];
}

- (void) setAbstractProf:(Profile*)ref
{
	if (ref)
	{
		[_absProf autorelease];
		_absProf = [ref retain];
		[self setAbstractMode:imOther];
	}
}

- (void) zeroAbstract
{
	int i;
	
	for (i=kvalBrightDks; i<=kvalSat; i++)
		_val[i] = 0;
	
	_cwOK = NO;
	_absMode = imCustom;
	_custAbsOK = NO;
	[self WorldDidChange];
}


- (OSType) proofMode;
	{ return _prfMode; }

- (void) setProofMode:(OSType)type;
{
	if (type == imOther && _prfProf==nil)
		type = imNone;		
	if (type == _prfMode)
		return;
	_prfMode = type;
	_cwOK = NO;
	[self WorldDidChange];
}

- (void) setProofProf:(Profile*)ref
{
	if (ref)
	{
		[_prfProf autorelease];
		_prfProf = [ref retain];
		[self setProofMode:imOther];
	}
}


- (OSType) destMode;
	{ return _dstMode; }

- (void) setDestMode:(OSType)type;
{
	if (type == imOther && _dstProf==nil)
		type = imDisplay;		
	if (type == _dstMode)
		return;
	_dstMode = type;
	_cwOK = NO;
	[self WorldDidChange];
}

- (void) setDestProf:(Profile*)ref
{
	if (ref)
	{
		[_dstProf autorelease];
		_dstProf = [ref retain];
		[self setDestMode:imOther];
	}
}



- (float) custValForIndex:(int)i
	{ return (i<kvalMax) ? _val[i] : 0; }

- (void) setCustVal:(float)v forIndex:(int)i
{
	if (i>=kvalMax || v == _val[i])
		return;
	_val[i] = v;
	_cwOK = NO;
	if (i<=kvalLimitHi)
		_custAbsOK = NO;
	else
		_custSrcOK = NO;
	[self WorldDidChange];
}


- (BOOL) custLimitOn;
	{ return _limitOn; }

- (void) setCustLimitOn:(BOOL)on;
{
	if (on == _limitOn)
		return;
	_limitOn = on;
	_cwOK = NO;
	_custAbsOK = NO;
	[self WorldDidChange];
}




- (BOOL) MatchIsNoOp
{
	return (_prfMode==imNone && _absMode==imNone &&
			_srcMode!=imOther && _dstMode!=imOther &&
			_srcMode==_dstMode);
}


- (CMError) MatchBitmap:(CMBitmap*)bitmap toBitmap:(CMBitmap*)toBitmap
{
	CMError		err = noErr;
	CMWorldRef	cw = [self world];
	
	if (cw)
		err = CWMatchBitmap(cw, bitmap, nil, nil, toBitmap);
	else
	{
		CMBitmap* dest = (toBitmap) ? toBitmap : bitmap;
		
		if (bitmap->image     != dest->image  &&
			bitmap->width     == dest->width  &&
			bitmap->height    == dest->height &&
			bitmap->rowBytes  == dest->rowBytes &&
			bitmap->pixelSize == dest->pixelSize &&
			bitmap->space     == dest->space)
			memmove(dest->image, bitmap->image, bitmap->rowBytes*bitmap->height);
		else
			err = unimpErr; // too much work
	}
	return err;
}


- (CMError) MatchBitmapRep:(NSBitmapImageRep*)bitmap toBitmapRep:(NSBitmapImageRep*)toBitmap
{
	CMBitmap	s={}, d={};
	
	s.image = [bitmap bitmapData];
	s.width = [bitmap pixelsWide];
	s.height = [bitmap pixelsHigh];
	s.rowBytes = [bitmap bytesPerRow];
	s.pixelSize = [bitmap bitsPerPixel];
	s.space = cmRGB24Space;
	
	d.image = [toBitmap bitmapData];
	d.width = [toBitmap pixelsWide];
	d.height = [toBitmap pixelsHigh];
	d.rowBytes = [toBitmap bytesPerRow];
	d.pixelSize = [toBitmap bitsPerPixel];
	d.space = cmRGB24Space;
	
	return [self MatchBitmap:&s toBitmap:&d];
}


- (Profile*) getProfForUse:(int)use
{
	Profile*		ref = nil;
	OSType			type = 0;
	
	if (use==imSrcAbs)
	{
		ref = [Profile profileWithSource:[self getProfForUse:imSrc] andAbstract:[self getProfForUse:imAbs]];
		return ref;
	}
	
	
	if (use==imSrc) type = _srcMode;
	if (use==imAbs) type = _absMode;
	if (use==imPrf) type = _prfMode;
	if (use==imDst) type = _dstMode;
	
	switch (type)
	{
		case imRGB:
		case imSRGB:
			ref = [Profile profileWithSpace:type];
			break;
		
		case imDisplay:
		case imProofer:
		case imPrinter:
			ref = [Profile profileWithUse:type];
			break;
		
		case imEmbedded:
			ref = _embedProf;
			break;
		
		case imOther:
			if (use==imSrc)	ref = _srcProf;
			if (use==imAbs)	ref = _absProf;
			if (use==imPrf)	ref = _prfProf;
			if (use==imDst)	ref = _dstProf;
			break;
		
		case imAuto:
		case imCustom:
			if (use==imSrc)
			{
				[self buildCustomProfSrc]; // update _customProfSrc if needed
				ref = _customProfSrc;
			}
			if (use==imAbs)
			{
				[self buildCustomProfAbs]; // update _customProfAbs if needed
				ref = _customProfAbs;
			}
			break;
	}
		
	return ref;
	
}


- (void*) copyTextureData:(unsigned)grid
{
	unsigned			numEntries = grid * grid * grid;
	unsigned			clutDataSize = numEntries * 4 * sizeof(unsigned char);
	void*				clutData = nil;
	
	if (![self MatchIsNoOp])
	{
		clutData = malloc(clutDataSize);
		(void) CWFillLookupTexture([self world], grid, cmTextureRGBtoRGBX8, clutDataSize, clutData);
	}
	
	return clutData;
}


typedef struct
{
	float*	vals;
	BOOL	limit;
} LabToLabRec;

//--------------------------------------------------------------------- LabToLabProc
void LabToLabProc (float *L, float *a, float *b, void *refcon)
{
	float			c,h;
	float			n,min,mid,max,gamma;
	LabToLabRec*	rec = (LabToLabRec*)refcon;
	float			k = 1.0;
	
	if (rec->limit)
	{
		float	lo = rec->vals[kvalLimitLo];
		float	hi = rec->vals[kvalLimitHi];
		
		// convert a,b to hue
		h = atan2((*b),(*a)) * kRadsToDeg;
		
		if (lo<hi && (h<lo || h>hi))
			k = 0;
		if (lo>hi && (h<lo && h>hi))
			k = 0;
	}
	
	// Change white-pt
	{
		float			l = (*L) / 100.0;
		float			kl = (2*l - 1);
		float			km = (l<0.5) ? (2*l) : (2 - 2*l);
		float			kd = (1 - 2*l);
		
		if (kl<0) kl = 0;
		if (km<0) km = 0;
		if (kd<0) kd = 0;
		
		(*b) += kl * k*rec->vals[kvalTintLts];
		(*b) += km * k*rec->vals[kvalTintMds];
		(*b) += kd * k*rec->vals[kvalTintDks];
		
		(*a) += kl * k*(rec->vals[kvalTintLts]) / 3.;
		(*a) += km * k*(rec->vals[kvalTintMds]) / 3.;
		(*a) += kd * k*(rec->vals[kvalTintDks]) / 3.;
	}
	
	// convert a,b to c,h
	c = sqrt((*a)*(*a) + (*b)*(*b));
	h = atan2((*b),(*a)) * kRadsToDeg;
	
	// Change hue
	h += k*rec->vals[kvalHue];
	
	// Change saturation
	n = k*rec->vals[kvalSat]; // n = -100 .. 0 .. 100
	if (n>0)
	{
		if (c < 130.0)
		{
			n = 1.0 + n/50.0; // n = .. 1 .. 3
			c = 130.0 - 130.0*pow( 1.0 - c/130.0, n);
		}
	}
	else
		c *= 1.0 + n/100.0;
	
	// Change gamma
#if _normal_sense_
	
	min = 0.0	+ k*rec->vals[kvalBrightDks];
	mid = 50.0  + k*rec->vals[kvalBrightMds];
	max = 100.0	+ k*rec->vals[kvalBrightLts];
	
	gamma = -Log2((mid-min)/(max-min));
	*L = min + (max-min)*pow((*L)/100.0,gamma);
	
#else // inverse sence
	
	min = 0.0	- k*rec->vals[kvalBrightDks];
	mid = 50.0	- k*rec->vals[kvalBrightMds];
	max = 100.0	- k*rec->vals[kvalBrightLts];
	
	mid = (mid-min)/(max-min);
	gamma = -log(0.5)/log(1.0/mid); // sol to mid^gam = 0.5
	(*L) = ((*L)-min)/(max-min);
	if ((*L) < 0.0)
		(*L) = 0.0;
	else if ((*L) > 1.0)
		(*L) = 100.0;
	else
		(*L) = 100.0 * pow((*L),gamma);
	
#endif
	
	// convert c,h to a,b
	h *= kDegToRads;
	*a = c * cos(h);
	*b = c * sin(h);
}


- (void) buildCustomProfSrc
{
	CMProfileRef	ref = nil;
	double			midR, midG, midB;
	double			min=0.0, max=100.0;
	double			Rx=0.630, Ry=0.340, Rgamma=1.0; // P22
	double			Gx=0.295, Gy=0.605, Ggamma=1.0;
	double			Bx=0.155, By=0.077, Bgamma=1.0;
	double			Wx=0.3127, Wy=0.3290;  // D65
	
	// if previously build prof is still good return
	if (_custSrcOK)
		return;
	
	CMNewProfile(&ref,nil);
	
	midR = 50.0 + _val[kvalBrightRed];
	midG = 50.0 + _val[kvalBrightGrn];
	midB = 50.0 + _val[kvalBrightBlu];
	
	Rgamma = -Log2((midR-min)/(max-min));
	Ggamma = -Log2((midG-min)/(max-min));
	Bgamma = -Log2((midB-min)/(max-min));
	
	move_xy(&Rx, &Ry, _val[kvalHueRed], _val[kvalSatRed]);
	move_xy(&Gx, &Gy, _val[kvalHueGrn], _val[kvalSatGrn]);
	move_xy(&Bx, &By, _val[kvalHueBlu], _val[kvalSatBlu]);
	
	CFStringRef		keys[] = {	CFSTR("profileType"),
								CFSTR("phosphorRx"), CFSTR("phosphorRy"), CFSTR("gammaR"),
								CFSTR("phosphorGx"), CFSTR("phosphorGy"), CFSTR("gammaG"),
								CFSTR("phosphorBx"), CFSTR("phosphorBy"), CFSTR("gammaB"),
								CFSTR("whitePointx"), CFSTR("whitePointy")};
	CFTypeRef		vals[] = {	CFSTR("displayRGB"),
								(CFTypeRef)CFNumberCreate(nil, kCFNumberDoubleType, (void *)&Rx), 
								(CFTypeRef)CFNumberCreate(nil, kCFNumberDoubleType, (void *)&Ry), 
								(CFTypeRef)CFNumberCreate(nil, kCFNumberDoubleType, (void *)&Rgamma),
								(CFTypeRef)CFNumberCreate(nil, kCFNumberDoubleType, (void *)&Gx), 
								(CFTypeRef)CFNumberCreate(nil, kCFNumberDoubleType, (void *)&Gy), 
								(CFTypeRef)CFNumberCreate(nil, kCFNumberDoubleType, (void *)&Ggamma),
								(CFTypeRef)CFNumberCreate(nil, kCFNumberDoubleType, (void *)&Bx), 
								(CFTypeRef)CFNumberCreate(nil, kCFNumberDoubleType, (void *)&By), 
								(CFTypeRef)CFNumberCreate(nil, kCFNumberDoubleType, (void *)&Bgamma),
								(CFTypeRef)CFNumberCreate(nil, kCFNumberDoubleType, (void *)&Wx), 
								(CFTypeRef)CFNumberCreate(nil, kCFNumberDoubleType, (void *)&Wy)
							 };
	CFDictionaryRef spec = CFDictionaryCreate(nil, (const void **)keys, (const void **)vals, 12, 
						&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	
	(void) CMMakeProfile(ref, spec);
	
	if (spec) CFRelease(spec);
	int r;
	for (r=1; r<12; r++)
		if (vals[r]) CFRelease(vals[r]);
	
	[_customProfSrc autorelease];
	_customProfSrc = [[Profile profileWithRef:ref] retain];
}



- (void) buildCustomProfAbs
{
	CMError			err = noErr;
	CMProfileRef	ref = nil;
	
	// if previously build prof is still good return
	if (_custAbsOK)
		return;
	
	CMNewProfile(&ref,nil);
	
	SInt32			gp = 17;
	LabToLabRec		labrec = {_val, _limitOn};
	SInt64			proc = (SInt64)LabToLabProc;
	SInt64			rc = (SInt64)&labrec;
	CFStringRef		keys[] = {	CFSTR("profileType"),
								CFSTR("gridPoints"),
								CFSTR("proc"),
								CFSTR("refcon")};
	CFTypeRef		vals[] = {	CFSTR("abstractLab"),
								(CFTypeRef)CFNumberCreate(nil, kCFNumberSInt32Type, (void *)&gp), 
								(CFTypeRef)CFNumberCreate(nil, kCFNumberSInt64Type, (void *)&proc), 
								(CFTypeRef)CFNumberCreate(nil, kCFNumberSInt64Type, (void *)&rc)
							 };
	CFDictionaryRef spec = CFDictionaryCreate(nil, (const void **)keys, (const void **)vals, 4, 
						&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	int r;
	for (r=1; r<4; r++)
		if (vals[r]) CFRelease(vals[r]);
	
	err = CMMakeProfile(ref, spec);
	
	if (spec) CFRelease(spec);
	
	if (err)
		printf("failed to build abstract profile (%ld)\n", err);
	
	[_customProfAbs autorelease];
	_customProfAbs = [[Profile profileWithRef:ref] retain];
}


- (CMWorldRef) world
{
	// if previously build cw is still good return it
	if (_cwOK)
		return _cw;
	
	// Otherwise, dispose of the old cw
	if (_cw) CWDisposeColorWorld(_cw);
	_cw = nil;
	
	// Build new cw if needed
	if ([self MatchIsNoOp] == NO)
	{
		CMError					err = noErr;
		CMProfileRef			prof;
		UInt32					pc = 0;
		NCMConcatProfileSet4	set = {
									0,
									0x00020000 + cmGamutCheckingMask, // best + nogammut,
									cmQualityMask + cmGamutCheckingMask,
									0};
		
		prof = [[self getProfForUse:imSrc] profRef];
		if (prof)
		{
			set.profileSpecs[pc].renderingIntent = kUseProfileIntent;
			set.profileSpecs[pc].transformTag = kDeviceToPCS;
			set.profileSpecs[pc].profile = prof;
			pc++;
		}
		
		prof = [[self getProfForUse:imAbs] profRef];
		if (prof)
		{
			set.profileSpecs[pc].renderingIntent = kUseProfileIntent;
			set.profileSpecs[pc].transformTag = kPCSToPCS;
			set.profileSpecs[pc].profile = prof;
			pc++;
		}
		
		prof = [[self getProfForUse:imPrf] profRef];
		if (prof)
		{
			set.profileSpecs[pc].renderingIntent = kUseProfileIntent;
			set.profileSpecs[pc].transformTag = kPCSToPCS;
			set.profileSpecs[pc].profile = prof;
			pc++;
		}
		
		prof = [[self getProfForUse:imDst] profRef];
		{
			set.profileSpecs[pc].renderingIntent = kUseProfileIntent;
			set.profileSpecs[pc].transformTag = kPCSToDevice;
			set.profileSpecs[pc].profile = prof;
			pc++;
		}
		
		set.profileCount = pc;
		
		err = NCWConcatColorWorld(&_cw, (NCMConcatProfileSet*)&set, nil, nil);
		if (err) NSLog(@"NCWConcatColorWorld failed (%d)\n", err);
	}
	
	_cwOK = YES;
	return _cw;
}


- (void) WorldDidChange
{
	if ([_delegate respondsToSelector:@selector(ManipWorldDidChange:)]) 
		[_delegate ManipWorldDidChange:self];
}


@end
