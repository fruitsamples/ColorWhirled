
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import "ManipWorld.h"


@interface MySliderCell : NSSliderCell
{
}
@end


@interface ManipPanelGroup : NSView
{
	BOOL	_disabled;
	float	_origH;
}
- (BOOL) enabled;
- (void) setEnabled:(BOOL)b animate:(BOOL)animate;
@end


@interface ManipPanel : NSPanel
{
	IBOutlet NSPopUpButton*		_srcPop;
	IBOutlet NSPopUpButton*		_absPop;
	IBOutlet NSPopUpButton*		_prfPop;
	IBOutlet NSPopUpButton*		_dstPop;
	
	IBOutlet ManipPanelGroup*	_groupSrc;
	IBOutlet NSSlider*			_sBrightRed;
	IBOutlet NSSlider*			_sBrightGrn;
	IBOutlet NSSlider*			_sBrightBlu;
	IBOutlet NSSlider*			_sHueRed;
	IBOutlet NSSlider*			_sHueGrn;
	IBOutlet NSSlider*			_sHueBlu;
	IBOutlet NSSlider*			_sSatRed;
	IBOutlet NSSlider*			_sSatGrn;
	IBOutlet NSSlider*			_sSatBlu;
	
	IBOutlet ManipPanelGroup*	_groupAbs;
	IBOutlet NSSlider*			_sBrightDks;
	IBOutlet NSSlider*			_sBrightMds;
	IBOutlet NSSlider*			_sBrightLts;
	IBOutlet NSSlider*			_sTintDks;
	IBOutlet NSSlider*			_sTintMds;
	IBOutlet NSSlider*			_sTintLts;
	IBOutlet NSSlider*			_sHue;
	IBOutlet NSSlider*			_sSat;
	
	IBOutlet NSSlider*			_sLimitLo;
	IBOutlet NSSlider*			_sLimitHi;
	IBOutlet NSButton*			_sLimitOn;
	
	ManipWorld*			_world;
}


+ (ManipPanel*) sharedManipPanel;

- (ManipWorld*)world;
- (void)setWorld:(ManipWorld*)w;

- (void)updateUI:(BOOL)animate;

- (void) popupAction:(id)sender;
- (void) sliderAction:(id)sender;
- (void) limitOnAction:(id)sender;
- (void) buttonAction:(id)sender;

@end
