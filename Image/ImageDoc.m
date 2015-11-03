

//#import <QuickTime/QuickTime.h>
#import "ImageDoc.h"
#import "ManipPanel.h"


@implementation ImageDoc

- (void) dealloc
{
	[_file release];
	[super dealloc];
}


- (NSString*) windowNibName
	{ return @"ImageDoc"; }


- (void) windowControllerDidLoadNib:(NSWindowController*) aController
{
	NSWindow*		w = [aController window];
	
    [_mView setFile:_file];
	
	[super windowControllerDidLoadNib:aController];
	
	[aController setShouldCloseDocument:YES];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self selector:@selector(windowDidBecomeMain:)
		name:NSWindowDidBecomeMainNotification
		object:w ];
	
	NSRect r = [w frame];
	r.size = [self windowWillResize:w toSize:r.size];
	[w setFrame:r display:YES];
	
	[self setHasUndoManager:NO];
	
	[w makeFirstResponder:_mView];
	
	NSPrintInfo*		printInfo = [self printInfo];
	[printInfo setVerticalPagination:NSFitPagination];
	[printInfo setHorizontalPagination:NSFitPagination];
	if (r.size.width>r.size.height)
		[printInfo setOrientation:NSLandscapeOrientation];
	else
		[printInfo setOrientation:NSPortraitOrientation];
}


- (void) windowDidBecomeMain:(NSNotification*)n
	{ [_mView viewDidBecomeMain]; }


#pragma mark -
	

- (BOOL) prepareSavePanel:(NSSavePanel*)savePanel;
{
	[_accPop selectItemAtIndex:0];
	[savePanel setAccessoryView:_accView];
	return YES;
}

- (BOOL) writeWithBackupToFile:(NSString*)path 
		ofType:(NSString*)docType 
		saveOperation:(NSSaveOperationType)saveOp;
{
	printf("writeWithBackupToFile pop=%d\n", [_accPop indexOfSelectedItem]);
	return NO;
//	return [super writeWithBackupToFile:path ofType:docType 
//		saveOperation:saveOp];
}

- (NSData*) dataRepresentationOfType:(NSString*)aType
	{ return nil; }


#pragma mark -


- (BOOL) readFromFile:(NSString*)fileName ofType:(NSString*)type
{
	_file = [fileName retain];
	return YES;
}

- (NSSize) windowWillResize:(NSWindow*)sender toSize:(NSSize)newSize
	{ return [_mView windowWillResize:sender toSize:(NSSize)newSize]; }


#pragma mark -


- (void) printShowingPrintPanel:(BOOL)flag
{
	NSPrintOperation*	printOp = [NSPrintOperation printOperationWithView:[_mView superview] printInfo:[self printInfo]];
	NSPrintInfo*		printInfo = [printOp printInfo];
	
//	[printInfo setVerticalPagination:NSFitPagination];
//	[printInfo setHorizontalPagination:NSFitPagination];	
//	[printInfo setOrientation:NSLandscapeOrientation];
	
	NSRect				imgBounds = [printInfo imageablePageBounds];
	NSSize				paperSize = [printInfo paperSize];
	float				l,r,b,t, lr,tb;
	l = imgBounds.origin.x;
	b = imgBounds.origin.y;
	r = paperSize.width - (imgBounds.origin.x+imgBounds.size.width);
	t = paperSize.height - (imgBounds.origin.y+imgBounds.size.height);
	lr = MAX(MAX(l,r),0);
	tb = MAX(MAX(t,b),0);
	[printInfo setLeftMargin:lr];
	[printInfo setBottomMargin:tb];
	[printInfo setRightMargin:lr];
	[printInfo setTopMargin:tb];
	
	[printOp setShowPanels:flag];
	[self runModalPrintOperation:printOp delegate:nil didRunSelector:nil contextInfo:nil];
}

- (IBAction)runPageLayout:(id)sender;
{
	printf("runPageLayout\n");
	[super runPageLayout:sender];
}

@end
