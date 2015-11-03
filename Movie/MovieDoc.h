

#import <Cocoa/Cocoa.h>
#import "MovieManipView.h"


@interface MovieDoc : NSDocument
{
	IBOutlet MovieManipView* 	_mView;
	
	NSString*					_file;
}

@end
