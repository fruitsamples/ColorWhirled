
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>


@interface Profile : NSObject <NSCopying>
{
	CM2Header				_header;
    NSString*				_name;
    CMProfileLocation		_location;
    CMProfileRef			_ref;
	NSData*					_data;
}

+ (id) profileWithRef:(CMProfileRef)ref;
+ (id) profileWithPath:(NSString*)path;
+ (id) profileWithLoc:(CMProfileLocation*)loc;
+ (id) profileWithData:(NSData*)data;
+ (id) profileWithInfo:(CMProfileIterateData*)info;
+ (id) profileWithSpace:(OSType)space;
+ (id) profileWithUse:(OSType)use;

- (id) initializeWithRef:(CMProfileRef)ref;
- (id) initWithRef:(CMProfileRef)ref;
- (id) initWithPath:(NSString*)path;
- (id) initWithLoc:(CMProfileLocation*)loc;
- (id) initWithData:(NSData*)data;
- (id) initWithInfo:(CMProfileIterateData*)info;
- (id) initWithSpace:(OSType)space;
- (id) initWithUse:(OSType)use;

- (id) description;
- (UInt32) profSize;
- (UInt32) profVers;
- (OSType) profSpace;
- (OSType) profClass;
- (void) setProfClass:(OSType)c;
- (OSType) profConnSpace;
- (void) profLocation:(CMProfileLocation*)loc;
- (NSString*) profLocationStr;
- (NSString*) profLocationStrPretty;
- (NSCalendarDate*) profCreation;

- (void) open;
- (BOOL) isDirty;
- (void) closeWithSaving:(BOOL)save;
- (CMProfileRef) profRef;

+ (void) profileChoose:(id)sender
			modalForWindow:(NSWindow *)window
			modalDelegate:(id)delegate 
			didEndSelector:(SEL)didEndSelector 
			contextInfo:(void *)contextInfo;
+ (BOOL) panel:(id)sender shouldShowFilename:(NSString*)filename;
+ (void) openPanelDidEnd:(NSOpenPanel*)panel result:(int)result contextInfo:(void *)contextInfo;

- (void) saveProfileCopyModalForWindow:(NSWindow*)window
			modalDelegate:(id) delegate 
			didEndSelector:(SEL) didEndSelector 
			contextInfo:(void*) contextInfo;
- (void) savePanelDidEnd:(NSSavePanel*)panel result:(int)result contextInfo:(void *)contextInfo;

+ (Profile*) profileWithSource:(Profile*)src andAbstract:(Profile*)abs;

@end
