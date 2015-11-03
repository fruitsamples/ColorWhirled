
#import "Profile.h"
#include <CoreFoundation/CFPriv.h>


@implementation Profile


#pragma mark -


+ (id) profileWithRef:(CMProfileRef)ref
	{ return [[[self alloc] initWithRef:ref] autorelease]; }

+ (id) profileWithPath:(NSString*)path
	{ return [[[self alloc] initWithPath:path] autorelease]; }

+ (id) profileWithLoc:(CMProfileLocation*)loc
	{ return [[[self alloc] initWithLoc:loc] autorelease]; }

+ (id) profileWithData:(NSData*)data
	{ return [[[self alloc] initWithData:data] autorelease]; }

+ (id) profileWithInfo:(CMProfileIterateData*)info
	{ return [[[self alloc] initWithInfo:info] autorelease]; }

+ (id) profileWithSpace:(OSType)space
	{ return [[[self alloc] initWithSpace:space] autorelease]; }

+ (id) profileWithUse:(OSType)use
	{ return [[[self alloc] initWithUse:use] autorelease]; }


- (id) initializeWithRef:(CMProfileRef)ref
{
	CMError			err = noErr;
	Str255			pName;
	ScriptCode		code;
	UInt32			locSize = sizeof(_location);
	
	self = [super init];
	require_action(self, bail, err=1; );
	
	err = CMCloneProfileRef(ref);
	require_noerr(err, bail);
	_ref = ref;
	
	err = NCMGetProfileLocation(ref, &_location, &locSize);
	require_noerr(err, bail);
	
	err = CMGetProfileHeader(ref, (CMAppleProfileHeader*)&_header);
	require_noerr(err, bail);
	
	// For icc4 profiles, look in 'desc' tag for 'mluc' data
	err = CMCopyProfileLocalizedString(ref, cmProfileDescriptionTag, 0,0, (CFStringRef*)&_name);
	if (!err) goto bail;
	
	// For transition profiles, look in 'dscm' tag for 'mluc' data
	err = CMCopyProfileLocalizedString(ref, cmProfileDescriptionMLTag, 0,0, (CFStringRef*)&_name);
	if (!err) goto bail;
	
	// do it the old way
	err = CMGetScriptProfileDescription(ref, pName, &code);
	require_noerr(err, bail);
	_name = (NSString*)CFStringCreateWithPascalString(0L, pName, code);
	
bail:
	
	if (err)
	{
		NSLog(@"initializeWithRef failed\n"); NSBeep();
		[self autorelease];
		self = nil;
	}
	
	return self;
}


- (id) initWithRef:(CMProfileRef)ref
{
	return [self initializeWithRef:ref];
}


- (id) initWithPath:(NSString*)path
{
	CMProfileLocation	loc = {cmPathBasedProfile};
	
	if (YES == [path getFileSystemRepresentation:loc.u.pathLoc.path maxLength:255])
	{
		self = [self initWithLoc:&loc];
	}
	else
	{
		NSLog(@"getFileSystemRepresentation failed\n"); NSBeep();
		[self autorelease];
		self = nil;
	}
	return self;
}


- (id) initWithLoc:(CMProfileLocation*)loc
{
	CMProfileRef		ref = 0;
	
	if (noErr == CMOpenProfile(&ref, loc))
	{
		self = [self initializeWithRef:ref];
		CMCloseProfile(ref);
	}
	else
	{
		NSLog(@"CMOpenProfile failed\n"); NSBeep();
		[self autorelease];
		self = nil;
	}
	return self;
}


- (id) initWithData:(NSData*)data
{
	CMProfileLocation	loc = {cmBufferBasedProfile};
	
	_data = [data retain];
	loc.u.bufferLoc.size = [data length];
	loc.u.bufferLoc.buffer = (void*)[data bytes];
	return [self initWithLoc:&loc];
}


- (id) initWithInfo:(CMProfileIterateData*)info;
{
	if ( (self = [super init]) != nil )
	{
		_header = info->header;
		_location = info->location;
		
		if (info->uniCodeNameCount > 1)
			_name = [NSString stringWithCharacters:info->uniCodeName length:info->uniCodeNameCount - 1];
		else if (info->name[0])
			_name = [NSString stringWithCString:&(info->name[1]) length:info->name[0]];
		else
			_name = [NSString stringWithCString:info->asciiName];
		
		[_name retain];
	}
	return self;
}

- (id) initWithSpace:(OSType)space
{
	CMProfileRef		ref = 0;
	
	if (noErr == CMGetDefaultProfileBySpace(space, &ref))
	{
		[self initializeWithRef:ref];
		CMCloseProfile(ref);
	}
	else
	{
		NSLog(@"CMGetDefaultProfileBySpace failed\n"); NSBeep();
		[self autorelease];
		self = nil;
	}
	return self;
}

- (id) initWithUse:(OSType)use
{
	CMProfileRef		ref = 0;
	
	if (noErr == CMGetDefaultProfileByUse(use, &ref))
	{
		[self initializeWithRef:ref];
		CMCloseProfile(ref);
	}
	else
	{
		NSLog(@"CMGetDefaultProfileByUse failed\n"); NSBeep();
		[self autorelease];
		self = nil;
	}
	return self;
}


- (id) copyWithZone:(NSZone*)zone
{
	id copy = nil;
	
	if ([self isDirty])
	{
		CMProfileRef ref = nil;
		if (noErr == CMCopyProfile(&ref, nil, [self profRef]))
		{
			copy = [[Profile allocWithZone:zone] initWithRef:ref];
			CMCloseProfile(ref);
		}
	}
	else
	{
		CMProfileLocation loc;
		[self profLocation:&loc];
		copy = [[Profile allocWithZone:zone] initWithLoc:&loc];
	}
	
	return copy;
}


- (void) dealloc
{
	[self closeWithSaving:NO];
	[_name release];
	[_data release];
	[super dealloc];
}


#pragma mark -


- (id) description
{
    return (_name ? _name : [super description]);
}

- (void) setDescription:(NSString*)name
{
	NSData*			dataA;
	UniChar*		ustr = nil;
	UniCharCount	ulen;
	
	if (name==nil) return;
	
	[_name autorelease];
	_name = [name retain];
	
	dataA = [name dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	
	ulen = [name length]+1;
	ustr = calloc(ulen, 2);
	[name getCharacters:ustr];
	
	// rename
	(void)CMSetProfileDescriptions([self profRef],
			[dataA bytes],[dataA length]+1,  nil,0,  ustr,ulen);
	
	free(ustr);
}

- (UInt32) profSize;
	{ return _header.size; }

- (UInt32) profVers;
	{ return _header.profileVersion & 0xFFF00000; }

- (OSType) profSpace
	{ return _header.dataColorSpace; }

- (OSType) profClass
	{ return _header.profileClass; }

- (void) setProfClass:(OSType)c
{
	if (_header.profileClass != c)
	{
		_header.profileClass = c;
		CMSetProfileHeader([self profRef], (CMAppleProfileHeader*)&_header);
	}
}

- (OSType) profConnSpace
	{ return _header.profileConnectionSpace; }


- (void) profLocation:(CMProfileLocation*)loc
	{ *loc = _location; }

- (NSString*) profLocationStr
{
    CFURLRef 	url = 0L;
    NSString*	str = nil;
	CMProfileLocation	loc = _location;
	
	if (loc.locType == cmFileBasedProfile)
	{
		url = _CFCreateURLFromFSSpec(0L, &(loc.u.fileLoc.spec), false);
		str = (NSString*) CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
		CFRelease(url);
		[str autorelease];
    }
	else if (loc.locType == cmPathBasedProfile)
	{
		str = [NSString stringWithUTF8String:loc.u.pathLoc.path];
	}
	
	return str;
}

- (NSString*) profLocationStrPretty;
{
    NSString*	str = nil;
	
	str = [self profLocationStr];
	
	str = [str stringByStandardizingPath];
	str = [str stringByAbbreviatingWithTildeInPath];
	// fix /automount/Network/ here
	if ([str hasPrefix:@"/automount/Network/" ])
			str = [NSString stringWithFormat:@"/Network/%@", 
						[str substringFromIndex:19 ] ];
	
	return str;
}


- (BOOL)isEqual:(id)obj;
{
    if ([obj isKindOfClass:[self class]])
    {
        CMProfileLocation a,b;
        [self profLocation:&a];
        [obj profLocation:&b];
        
        if (a.locType==b.locType && a.locType==cmFileBasedProfile)
		{
			FSSpec* fs1 = &(a.u.fileLoc.spec);
			FSSpec* fs2 = &(b.u.fileLoc.spec);
			return (((*fs1).vRefNum == (*fs2).vRefNum) &&
					((*fs1).parID   == (*fs2).parID) &&
					((*fs1).name[0]  == (*fs2).name[0]) &&
					(strncmp((*fs1).name+1, (*fs2).name+1, (*fs1).name[0]) == 0));
		}
		return false;
    }
	return [super isEqual:obj];
}


- (NSCalendarDate*) profCreation
{
    CMDateTime		c = _header.dateTime;
    //NSTimeZone*	gmt = [NSTimeZone timeZoneWithName:@"GMT"];
    NSTimeZone*		loc = [NSTimeZone localTimeZone]; // systemTimeZone, defaultTimeZone

	// Convert date to NSCalendarDate
	if (c.year < 200) c.year += 1900;
	return [NSCalendarDate dateWithYear:c.year
								  month:c.month
									day:c.dayOfTheMonth
								   hour:c.hours
								 minute:c.minutes
								 second:c.seconds
							   timeZone:loc];
}

- (CMProfileRef) profRef
{
	[self open];
	return _ref;
}

- (void) open
{
	if (_ref) return;
	
	if (CMOpenProfile(&_ref, &_location))
		NSLog(@"CMOpenProfile errored\n");
}

- (BOOL) isDirty
{
	Boolean modified = NO;
	if (_ref)	
		CMProfileModified(_ref, &modified);
	return modified;
}

- (void) closeWithSaving:(BOOL)save
{
	if (!_ref) return;
	
	if (save && [self isDirty])
	{
		if (CMUpdateProfile(_ref))
			NSLog(@"CMUpdateProfile errored\n");
	}
	
	if (CMCloseProfile(_ref))
		NSLog(@"CMCloseProfile errored\n");
	
	_ref = 0L;
}


#pragma mark -


typedef struct {
	id			delegate;
	SEL			didEndSelector;
	void*		contextInfo;
	NSString*	pref;
} profChooseRec;


+ (void) profileChoose:(id) sender
		modalForWindow:(NSWindow*) window
		 modalDelegate:(id) delegate 
		didEndSelector:(SEL) didEndSelector 
		   contextInfo:(void*) contextInfo
{
	NSOpenPanel*	panel = [NSOpenPanel openPanel];
	NSArray*		types = [NSArray arrayWithObjects: @"icc", @"pf", @"icm", @"'prof'", 0];
	profChooseRec*	info = nil;
	
	info = (profChooseRec*)malloc(sizeof(profChooseRec));
	info->delegate = delegate;
	info->didEndSelector = didEndSelector;
	info->contextInfo = contextInfo;
	info->pref = [[NSUserDefaults standardUserDefaults] stringForKey:@"NSDefaultOpenDirectory"];
	[info->pref retain];
	
	//[panel setDelegate:self]; // use shouldShowFilename
	[panel beginSheetForDirectory:@"/Library/ColorSync/Profiles/"
							 file:nil
							types:types 
				   modalForWindow:window 
					modalDelegate:self 
				   didEndSelector:@selector(openPanelDidEnd:result:contextInfo:) 
					  contextInfo:info];
}


+ (BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename
{	//CFShow(filename);
    return YES;
}


+ (void)openPanelDidEnd:(NSOpenPanel*)panel result:(int)result
                        contextInfo:(void *)contextInfo
{
	Profile*			ref = nil;
	profChooseRec*		info = (profChooseRec*)contextInfo;
	void (*f)(id,SEL, id,int,void*);
	
	[Profile performSelector:@selector(restoreDefaults:) withObject:info->pref afterDelay:0];
	
	f = (void (*)(id,SEL, id,int,void*))[info->delegate methodForSelector:info->didEndSelector];
	
	if (result == NSOKButton)
	{
		ref = [Profile profileWithPath:[[panel filenames] objectAtIndex:0]];
	}
	
	f(info->delegate,info->didEndSelector, ref,result,info->contextInfo);
	
	free(info);
}


+ (void) restoreDefaults:(id)val
{
	[[NSUserDefaults standardUserDefaults] 
		setObject:val forKey:@"NSDefaultOpenDirectory"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[val release];
}


- (void) saveProfileCopyModalForWindow:(NSWindow *)window
		 modalDelegate:(id) delegate 
		didEndSelector:(SEL) didEndSelector 
		   contextInfo:(void*) contextInfo
{
	NSSavePanel*	panel = [NSSavePanel savePanel];
///	NSString*		pref = nil;
//	pref  = [[NSUserDefaults standardUserDefaults] stringForKey:@"NSDefaultOpenDirectory"];
	
	profChooseRec*	info = nil;
	
	info = (profChooseRec*)malloc(sizeof(profChooseRec));
	info->delegate = delegate;
	info->didEndSelector = didEndSelector;
	info->contextInfo = contextInfo;
	info->pref = [[NSUserDefaults standardUserDefaults] stringForKey:@"NSDefaultOpenDirectory"];
	[info->pref retain];
	
	[panel setRequiredFileType:@"icc"];
	[panel setCanSelectHiddenExtension:YES];
	[panel beginSheetForDirectory:@"~/Library/ColorSync/Profiles/" 
							 file:[self description] 
				   modalForWindow:window
					modalDelegate:self
				   didEndSelector:@selector(savePanelDidEnd:result:contextInfo:)
					  contextInfo:info];
}


- (void)savePanelDidEnd:(NSSavePanel *)panel result:(int)result contextInfo:(void*)contextInfo
{
	CMError				err = noErr;
	CMProfileRef		temp = nil;
	Profile*			copy = nil;
	profChooseRec*		info = (profChooseRec*)contextInfo;
	
	[Profile performSelector:@selector(restoreDefaults:) withObject:info->pref afterDelay:0];
	
	if (result == NSOKButton)
	{
		NSString*			path;
		NSString*			name;
		BOOL				locOK;
		CMProfileLocation	loc = {cmPathBasedProfile};
		
		path = [panel filename];
		name = [[path lastPathComponent] stringByDeletingPathExtension];
		
		locOK = [path getFileSystemRepresentation:loc.u.pathLoc.path maxLength:255];
		require(locOK, bail);
		
		err = CMCopyProfile(&temp, &loc, [self profRef]);
		require_noerr(err, bail);
		
		copy = [Profile profileWithRef:temp];
		[copy setDescription:name];
		[copy closeWithSaving:YES];
	}
	
	void (*f)(id,SEL, id,int,void*);
	f = (void (*)(id,SEL, id,int,void*))[info->delegate methodForSelector:info->didEndSelector];
	if (f)
		f(info->delegate,info->didEndSelector, copy,result,info->contextInfo);
	
bail:
		
	free(info);
	if (temp) CMCloseProfile(temp);
}


#pragma mark -

#pragma options align=mac68k
typedef struct {
	OSType					cmm;
	UInt32					flags;			// specify quality, lookup only, no gamut checking ...
	UInt32					flagsMask;		// which bits of 'flags' to use to override profile
	UInt32					profileCount;	// how many ProfileSpecs in the following set
	NCMConcatProfileSpec	profileSpecs[2];// Variable. Ordered from Source -> Dest
} NCMConcatProfileSet2;
#pragma options align=reset

+ (Profile*) profileWithSource:(Profile*)srcProf andAbstract:(Profile*)absProf
{
	Profile*				ref = nil;
	CMError					err = noErr;
	Profile*				abs;
	CMProfileRef			prof = nil;
	NCMConcatProfileSet2	set = { 0,  // default cmm
									0x20000, cmQualityMask, // best qual
									2}; // two profs
	
	// make a copy of abs so we can modify it
	abs = [absProf copy];
	if (abs==nil) return nil;
	
	// change class to colorspace
	[abs setProfClass:cmOutputClass];
	err = CMSetProfileElementReference([abs profRef], 'A2B0', 'B2A0');
	if (err) NSLog(@"CMSetProfileElementReference failed (%d)\n", err);
	err = CMSetProfileElementReference([abs profRef], 'A2B0', 'A2B1');
	err = CMSetProfileElementReference([abs profRef], 'A2B0', 'A2B2');
	err = CMSetProfileElementReference([abs profRef], 'B2A0', 'B2A1');
	err = CMSetProfileElementReference([abs profRef], 'B2A0', 'B2A2');
	
	// Add a dummy gamut tag to the profile so the the CMM doesnt complain
	const UInt32 gamt[] = {	'mft2', 0,  // typeDescriptor, reserved
							0x03010200, // inputChannels, outputChannels, gridPoints, reserved2
							0x00010000, 0x00000000, 0x00000000, // matrix
							0x00000000, 0x00010000, 0x00000000,
							0x00000000, 0x00000000, 0x00010000,
							0x00020002, // inputTableEntries, outputTableEntries
							0x0000FFFF, 0x0000FFFF, 0x0000FFFF, //inputTable
							0x00000000, 0x00000000, // CLUT
							0xFFFFFFFF, 0xFFFFFFFF, // CLUT
							0xFFFFFFFF}; // outputTable
	err = CMSetProfileElement([abs profRef], 'gamt', 21*4, gamt);
	if (err) NSLog(@"CMSetProfileElement failed (%d)\n", err);
	
	set.profileSpecs[0].renderingIntent = kUseProfileIntent;
	set.profileSpecs[0].transformTag = kDeviceToPCS;
	set.profileSpecs[0].profile = [srcProf profRef];
	
	set.profileSpecs[1].renderingIntent = kUseProfileIntent;
	set.profileSpecs[1].transformTag = kPCSToDevice;
	set.profileSpecs[1].profile = [abs profRef];
	
	err = NCWNewLinkProfile(&prof, nil, (NCMConcatProfileSet*)&set, nil, nil);
	if (err) NSLog(@"NCWNewLinkProfile failed (%d)\n", err);
	
	// remove pseq tag
	CMRemoveProfileElement(prof, cmProfileSequenceDescTag);
	
	// add wtpt tag
	CMXYZType	xyzType;
	xyzType.typeDescriptor = EndianU32_NtoB(cmSigXYZType);
	xyzType.reserved = 0L;
	xyzType.XYZ[0].X = EndianS32_NtoB(0x0F6D6);
	xyzType.XYZ[0].Y = EndianS32_NtoB(0x10000);
	xyzType.XYZ[0].Z = EndianS32_NtoB(0x0D32D);
	err = CMSetProfileElement(prof, cmMediaWhitePointTag, sizeof(CMXYZType), &xyzType);
	
	// update the header
	CM2Header	head;
	CMGetProfileHeader(prof, (CMAppleProfileHeader*)&head);
	head.profileClass = cmInputClass;
	head.deviceManufacturer = 0;
	head.white.X = 0x0F6D6;
	head.white.Y = 0x10000;
	head.white.Z = 0x0D32D;
	CMSetProfileHeader(prof, (CMAppleProfileHeader*)&head);
	
	// Fix up the profile if the source was grey
	if (head.dataColorSpace==cmGrayData && head.profileConnectionSpace==cmLabData)
	{
		UInt32			lutSize = 0;
		UInt16*			lutData = nil;
		CMLut16Type*	lut = nil;
		CMCurveType*	curv = nil;
		UInt32			curvSize = 0;
		UInt32			i;
		
		// try to make a kTRC tag from the L values in the 'A2B0' tag
		err = CMGetProfileElement(prof, 'A2B0', &lutSize, nil);
		if (!err)
		{
			lutData = malloc(lutSize);
			lut = (CMLut16Type*)lutData;
			err = CMGetProfileElement(prof, 'A2B0', &lutSize, lutData);
			if (!err && lut->typeDescriptor==cmSigLut16Type &&
				lut->inputChannels==1 && lut->outputChannels==3 &&
				lut->inputTableEntries==2 && lut->outputChannels==2)
			{
				curvSize = 12 +2*lut->gridPoints;
				curv = (CMCurveType*) malloc(curvSize);
				curv->countValue = lut->gridPoints;
				for (i=0; i<lut->gridPoints; i++)
					curv->data[i] = lutData[28 + 3*i];
				CMRemoveProfileElement(prof, 'A2B0');
			}
		}
		
		// in not just use a linear kTRC tag
		if (curv == nil)
		{
			curvSize = sizeof(CMCurveType);
			curv = (CMCurveType*) malloc(curvSize);
			curv->countValue = 1;
			curv->data[0] = 1<<8;
		}
		
		curv->typeDescriptor = cmSigCurveType;
		curv->reserved = 0;
		CMSetProfileElement(prof, 'kTRC', curvSize, curv);
		
		if (lut) free(lut);
		if (curv) free(curv);
	}
	
	ref = [Profile profileWithRef:prof]; 
	
	return ref;
}

@end
