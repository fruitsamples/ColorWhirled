

#import <Cocoa/Cocoa.h>
#import "ImageManipView.h"


@interface ImageDoc : NSDocument
{
	IBOutlet ImageManipView* 	_mView;
	IBOutlet NSView* 			_accView;
	IBOutlet NSPopUpButton*		_accPop;
	
	NSString*					_file;
}

@end
