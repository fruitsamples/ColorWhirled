
#import <AppKit/AppKit.h>


@interface DividerView : NSView
{
	float		_divide;
	int			_divideSide;
	int			_sideBySide;
}

- (NSRect) subviewFrame;
- (void) mouse:(NSEvent*)event;
- (float) divide;
- (int) divideSide;
- (int) sideBySide;

@end
