
#import "ManipPanel.h"


ManipPanel *gInstance = nil;



@implementation MySliderCell



- (void)drawBarInside:(NSRect)aRect flipped:(BOOL)flipped;
{
	NSRect	r1, r2, r;
	
	// hue (to be passed to NSColor) as a function of hue (from Lch)
	const double hout[38] = {
			/*-180*/	0.480584, 0.492457, 0.502968, 0.513126, 0.522015, 0.529465,
			/*-120*/	0.537198, 0.544165, 0.553417, 0.563801, 0.576760, 0.594309,
			/* -60*/	0.622204, 0.743805, 0.800960, 0.844257, 0.873563, 0.895303,
			/*   0*/	0.913255, 0.930445, 0.946599, 0.965092, 1.021211, 1.062576,
			/*  60*/	1.084419, 1.102613, 1.119818, 1.138914, 1.161275, 1.188374,
			/* 120*/	1.219935, 1.265371, 1.385199, 1.417790, 1.444444, 1.466429,
			/* 180*/	1.480584, 1.492457};
	
	[super drawBarInside:aRect flipped:flipped];
	
	r1 = [self rectOfTickMarkAtIndex:0];
	r2 = [self rectOfTickMarkAtIndex:[self numberOfTickMarks]-1];
	
	double alpha = ([self isEnabled]) ? 1.0 : 0.5;
	
	for( r=r1; r.origin.x<=r2.origin.x; r.origin.x++ )
	{
		double h;
		
		// convert slider tick coods to [-180 .. 180]
		h = (r.origin.x - r1.origin.x) * 360.0 / (r2.origin.x - r1.origin.x);
		h -= 180.0;
		
		// Linear interpolation of above table
		int i = (h+180)/10;
		double f = (h - (double)(i*10-180)) / 10.0;
		h = f*hout[i+1] + (1.0-f)*hout[i];
		
		// normalize to [0..1]
		if (h>1)
			h -= 1.0;
		
		[[NSColor colorWithDeviceHue:h saturation:1 brightness:1 alpha:alpha] set];
		[NSBezierPath fillRect:r];
	}
}

@end



@implementation ManipPanelGroup

- (BOOL) enabled
	{ return !_disabled; }

- (void) setEnabled:(BOOL)b animate:(BOOL)animate
{
	NSArray*	subviews = [self subviews];
	unsigned	i, count = [subviews count];
	id			o;
	NSWindow*	w = [self window];
	NSRect		f = [w frame];
	float		delta;
	
	if (_origH == 0)
		_origH = [self frame].size.height;
	
	if ([self enabled] == b)
		return;
	
	_disabled = !b;
	
	subviews = [[self superview] subviews];
	count = [subviews count];
	
	for (i=0; i<count; i++)
		if ((o = [subviews objectAtIndex:i]))
		{
			if (o == self)
				[o setAutoresizingMask:NSViewHeightSizable];
			else if ([o frame].origin.y < [self frame].origin.y)
				[o setAutoresizingMask:NSViewMaxYMargin];
			else if ([o frame].origin.y > [self frame].origin.y)
				[o setAutoresizingMask:NSViewMinYMargin];
		}
	
	delta = _origH-1;
	if (b) delta = -delta;
	f.origin.y += delta;
	f.size.height -= delta;
	
	[w setFrame:f display:YES animate:animate];
	
	for (i=0; i<count; i++)
		if ((o = [subviews objectAtIndex:i]))
			[o setAutoresizingMask:NSViewNotSizable];
}

@end



@implementation ManipPanel

+ (ManipPanel*) sharedManipPanel
{
    if (gInstance==nil)
	    gInstance = [[self alloc] init];
    return gInstance;
}


- (void) awakeFromNib;
{
    if (gInstance==nil)
	    gInstance = self;
	
	[self setWorld:nil];
	
	[self setBecomesKeyOnlyIfNeeded:YES];

	[[_srcPop menu] setAutoenablesItems:NO];
	
	[_srcPop addToolTipRect:[_srcPop bounds] owner:self userData:(void*)imSrc];
	[_absPop addToolTipRect:[_absPop bounds] owner:self userData:(void*)imAbs];
	[_prfPop addToolTipRect:[_prfPop bounds] owner:self userData:(void*)imPrf];
	[_dstPop addToolTipRect:[_dstPop bounds] owner:self userData:(void*)imDst];
	
	{
		NSSliderCell*	old = [_sLimitLo cell];
		MySliderCell*	cell = [MySliderCell new];
		
		[cell setTag:[old tag]];
		[cell setTarget:[old target]];
		[cell setAction:[old action]];
		[cell setControlSize:[old controlSize]];
		[cell setMinValue:[old minValue]];
		[cell setMaxValue:[old maxValue]];
		[cell setNumberOfTickMarks:[old numberOfTickMarks]];
		[cell setTickMarkPosition:[old tickMarkPosition]];
		[_sLimitLo setCell:cell];
		
		old = [_sLimitHi cell];
		cell = [MySliderCell new];
		
		[cell setTag:[old tag]];
		[cell setTarget:[old target]];
		[cell setAction:[old action]];
		[cell setControlSize:[old controlSize]];
		[cell setMinValue:[old minValue]];
		[cell setMaxValue:[old maxValue]];
		[cell setNumberOfTickMarks:[old numberOfTickMarks]];
		[cell setTickMarkPosition:[old tickMarkPosition]];
		[_sLimitHi setCell:cell];
	}
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self selector:@selector(notification:)
		name:NSWindowDidResignMainNotification
		object:nil];
}


- (void) notification:(NSNotification*)n
{
	NSDocument*	curDoc;
	curDoc = [[NSDocumentController sharedDocumentController] currentDocument];
	if (curDoc == nil)
		[self setWorld:nil];
	// printf("%p resigned main\n", curDoc);
}


- (id)world
	{ return _world; }

- (void)setWorld:(ManipWorld*)w;
{
	[_world autorelease];
	_world = [w retain];
	[self updateUI:NO];
}


- (void)updateUI:(BOOL)animate
{
	BOOL	onoffPops = (_world != nil);
	BOOL	onoffCustAbs = ([_world abstactMode] == imCustom);
	BOOL	onoffCustSrc = ([_world sourceMode] == imCustom);
	BOOL	onoffLims = (onoffCustAbs && [_world custLimitOn]);
	BOOL	hasEmbedded = ([_world embeddedProf] != nil);
	
	[_srcPop setEnabled:onoffPops];
	[_absPop setEnabled:onoffPops];
	[_prfPop setEnabled:onoffPops];
	[_dstPop setEnabled:onoffPops];
	
	[_srcPop selectItemAtIndex: (!onoffPops) ? -1 :
			[[_srcPop menu] indexOfItemWithTag:[_world sourceMode]]];

	[_absPop selectItemAtIndex: (!onoffPops) ? -1 :
			[[_absPop menu] indexOfItemWithTag:[_world abstactMode]]];

	[_prfPop selectItemAtIndex: (!onoffPops) ? -1 :
			[[_prfPop menu] indexOfItemWithTag:[_world proofMode]]];

	[_dstPop selectItemAtIndex: (!onoffPops) ? -1 :
			[[_dstPop menu] indexOfItemWithTag:[_world destMode]]];
	
	[[[_srcPop menu] itemWithTag:imEmbedded] setEnabled:hasEmbedded];
	
	[_sLimitLo setEnabled:onoffLims];
	[_sLimitHi setEnabled:onoffLims];
	
	[_sBrightDks setFloatValue:_world ? [_world custValForIndex:0] : 0 ];
	[_sBrightMds setFloatValue:_world ? [_world custValForIndex:1] : 0 ];
	[_sBrightLts setFloatValue:_world ? [_world custValForIndex:2] : 0 ];
	[_sTintDks   setFloatValue:_world ? [_world custValForIndex:3] : 0 ];
	[_sTintMds   setFloatValue:_world ? [_world custValForIndex:4] : 0 ];
	[_sTintLts   setFloatValue:_world ? [_world custValForIndex:5] : 0 ];
	[_sHue       setFloatValue:_world ? [_world custValForIndex:6] : 0 ];
	[_sSat       setFloatValue:_world ? [_world custValForIndex:7] : 0 ];
	[_sLimitLo   setFloatValue:_world ? [_world custValForIndex:8] : 0 ];
	[_sLimitHi   setFloatValue:_world ? [_world custValForIndex:9] : 0 ];
	[_sLimitOn   setState:_world ? [_world custLimitOn] : 0 ];
	
	[_sHueRed setFloatValue:_world ? [_world custValForIndex:kvalHueRed] : 0 ];
	[_sHueGrn setFloatValue:_world ? [_world custValForIndex:kvalHueGrn] : 0 ];
	[_sHueBlu setFloatValue:_world ? [_world custValForIndex:kvalHueBlu] : 0 ];
	[_sSatRed setFloatValue:_world ? [_world custValForIndex:kvalSatRed] : 0 ];
	[_sSatGrn setFloatValue:_world ? [_world custValForIndex:kvalSatGrn] : 0 ];
	[_sSatBlu setFloatValue:_world ? [_world custValForIndex:kvalSatBlu] : 0 ];
	[_sBrightRed setFloatValue:_world ? [_world custValForIndex:kvalBrightRed] : 0 ];
	[_sBrightGrn setFloatValue:_world ? [_world custValForIndex:kvalBrightGrn] : 0 ];
	[_sBrightBlu setFloatValue:_world ? [_world custValForIndex:kvalBrightBlu] : 0 ];
	
	[_groupAbs setEnabled:onoffCustAbs animate:animate];
	[_groupSrc setEnabled:onoffCustSrc animate:animate];
}


- (void) popupAction:(id)sender
{
	OSType	tag = [[sender selectedItem] tag];
	
	if (tag == imOther)
	{
		[Profile profileChoose:sender modalForWindow:self modalDelegate:self 
				didEndSelector:@selector(profileChooseDidEnd:result:contextInfo:) contextInfo:sender];
	}
	else if (tag == imAuto)
	{
		if (sender == _srcPop) [_world _autoSource];
		if (sender == _absPop) [_world _autoAbstract];
		[self updateUI:YES];
	}
	else
	{
		if (sender == _srcPop) [_world setSourceMode:tag];
		if (sender == _absPop) [_world setAbstractMode:tag];
		if (sender == _prfPop) [_world setProofMode:tag];
		if (sender == _dstPop) [_world setDestMode:tag];
		[self updateUI:YES];
	}
}

- (void) sliderAction:(id)sender
{
	[_world setCustVal:[sender floatValue] forIndex:[sender tag]];
	[self updateUI:NO];
}


- (void) buttonAction:(id)sender
{
	OSType	tag = [sender tag];
	
	switch (tag)
	{
		case 0:
		[[_world getProfForUse:imAbs] saveProfileCopyModalForWindow:self
					modalDelegate:nil didEndSelector:nil contextInfo:nil];
		break;
		
		case 1:
		[_world _autoAbstract];
		[self updateUI:YES];
		break;
		
		case 2:
		[_world zeroAbstract];
		[self updateUI:YES];
		break;
		
		case 3:
		[[_world getProfForUse:imSrc] saveProfileCopyModalForWindow:self
					modalDelegate:nil didEndSelector:nil contextInfo:nil];
		break;
		
		case 4:
		[_world _autoSource];
		[self updateUI:YES];
		break;
		
		case 5:
		[_world zeroSource];
		[self updateUI:YES];
		break;
		
		case 6:
		{
		// TO DO: this should be released at some point
		// after the save process is complete
		Profile* prof = [[_world getProfForUse:imSrcAbs] retain];
		[prof saveProfileCopyModalForWindow:self
					modalDelegate:nil didEndSelector:nil contextInfo:nil];
		}
		break;
		
		default:
		NSBeep();
		break;
	}
}


- (void) limitOnAction:(id)sender
{
	[_world setCustLimitOn:[sender state]];
	[self updateUI:YES];
}


- (void)profileChooseDidEnd:(Profile*)ref result:(int)result
                        contextInfo:(void *)contextInfo;
{
	id		sender = (id)contextInfo;
	
	if (result==NSOKButton && ref)
	{
		if (sender == _srcPop) [_world setSourceProf:ref];
		if (sender == _absPop) [_world setAbstractProf:ref];
		if (sender == _prfPop) [_world setProofProf:ref];
		if (sender == _dstPop) [_world setDestProf:ref];
	}
		
	[self updateUI:YES];
}


- (NSString*) view:(NSView *)v stringForToolTip:(NSToolTipTag)tag point:(NSPoint)p userData:(void *)data
	{ return [[_world getProfForUse:(long)data] profLocationStrPretty]; }

@end
