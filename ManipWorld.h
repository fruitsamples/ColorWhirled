
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

#import "Profile.h"


enum {
	imNone		= 0,
	imEmbedded	= 'embd',		// 1701667428
	imRGB		= cmRGBData,    // 1380401696  'RGB ',
	imSRGB		= cmSRGBData,   // 1934772034  'sRGB',
	imDisplay	= cmDisplayUse, // 1685089401  'dply',
	imProofer	= cmProofUse,   // 1886549350  'pruf',
	imPrinter	= cmOutputUse,  // 1869968496  'outp',
	imAuto		= 'auto',		// 1635087471
	imOther		= 'othr',		// 1869899890
	imCustom	= 'cust'		// 1668641652
};


enum {
	kvalBrightDks = 0,
	kvalBrightMds,
	kvalBrightLts,
	kvalTintDks,
	kvalTintMds,
	kvalTintLts,
	kvalHue,
	kvalSat,
	kvalLimitLo,
	kvalLimitHi,
	
	kvalBrightRed,
	kvalBrightGrn,
	kvalBrightBlu,
	kvalHueRed,
	kvalHueGrn,
	kvalHueBlu,
	kvalSatRed,
	kvalSatGrn,
	kvalSatBlu,
	
	kvalMax
};

enum {
	imSrc		= 0,
	imAbs		= 1,
	imPrf		= 2,
	imDst		= 3,
	imSrcAbs	= 4,
	
};


@interface ManipWorld : NSObject
{
	IBOutlet id		_delegate;
	
	Profile*		_embedProf;
	Profile*		_customProfSrc;
	Profile*		_customProfAbs;
	
	Profile*		_srcProf;
	Profile*		_absProf;
	Profile*		_prfProf;
	Profile*		_dstProf;
	
	OSType			_srcMode;
	OSType			_absMode;
	OSType			_prfMode;
	OSType			_dstMode;
	
	BOOL			_custSrcOK;
	BOOL			_custAbsOK;
	BOOL			_cwOK;
	CMWorldRef		_cw;
	
	float			_val[kvalMax];
	BOOL			_limitOn;
}

+ (ManipWorld*) newManipWorld;

- (id)delegate;
- (void)setDelegate:(id)obj;

- (Profile*) getProfForUse:(int)use;
- (void*) copyTextureData:(unsigned)grid;

- (Profile*) embeddedProf;
- (void) setEmbeddedProf:(Profile*)ref;

- (OSType) sourceMode;
- (void) setSourceMode:(OSType)type;
- (void) setSourceProf:(Profile*)ref;
- (void) zeroSource;

- (OSType) abstactMode;
- (void) setAbstractMode:(OSType)type;
- (void) setAbstractProf:(Profile*)ref;
- (void) zeroAbstract;

- (OSType) proofMode;
- (void) setProofMode:(OSType)type;
- (void) setProofProf:(Profile*)ref;

- (OSType) destMode;
- (void) setDestMode:(OSType)type;
- (void) setDestProf:(Profile*)ref;

- (float) custValForIndex:(int)i;
- (void) setCustVal:(float)v forIndex:(int)i;

- (BOOL) custLimitOn;
- (void) setCustLimitOn:(BOOL)on;

- (BOOL) MatchIsNoOp;
- (CMError) MatchBitmap:(CMBitmap*)bitmap toBitmap:(CMBitmap*)toBitmap;
- (CMError) MatchBitmapRep:(NSBitmapImageRep*)bitmap toBitmapRep:(NSBitmapImageRep*)toBitmap;

- (void) buildCustomProfAbs;
- (void) buildCustomProfSrc;

- (CMWorldRef) world;
- (void) WorldDidChange;

@end



@interface NSObject(ManipWorldDelegate)

- (void) ManipWorldDidChange:(id)sender;

- (CMBitmap) ManipWorldGetBitmap:(id)sender;

@end
