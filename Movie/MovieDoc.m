
#import <QuickTime/QuickTime.h>
#import "MovieDoc.h"
#import "ManipPanel.h"


@implementation MovieDoc

- (void)dealloc
{
	[_file release];
	[super dealloc];
}


- (NSString *)windowNibName
	{ return @"MovieDoc"; }


- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
	NSWindow*		w = [aController window];
	
    [_mView setFile:_file];

	[super windowControllerDidLoadNib:aController];
	
	[aController setShouldCloseDocument:YES];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self selector:@selector(windowDidBecomeMain:)
		name:NSWindowDidBecomeMainNotification
		object:w ];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self selector:@selector(windowDidResignMain:)
		name:NSWindowDidResignMainNotification
		object:w ];
	
	{
	NSRect r = [w frame];
	r.size = [self windowWillResize:w toSize:r.size];
	[w setFrame:r display:YES];
	}
	///[w setContentSize:[self windowWillResize:w toSize:[w frame].size]];
	
	[w makeFirstResponder:_mView];

}


- (void) windowDidBecomeMain:(NSNotification*)n
	{ [_mView viewDidBecomeMain]; }

- (void) windowDidResignMain:(NSNotification*)n
	{ [_mView viewDidResignMain]; }


- (NSData *)dataRepresentationOfType:(NSString *)aType
	{ return nil; }


- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)type
{
	_file = [fileName retain];
	return YES;
}


- (NSSize) windowWillResize:(NSWindow *)sender toSize:(NSSize)newSize
	{ return [_mView windowWillResize:sender toSize:(NSSize)newSize]; }


@end
