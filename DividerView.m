
#import "DividerView.h"


@implementation DividerView

- (void) _init
{
	_divide = 0.5;
	_divideSide = 0;
}

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder])
		[self _init];
    return self;
}

- (id) initWithFrame: (NSRect)frame
{
    if (self = [super initWithFrame:frame])
		[self _init];
    return self;
}


- (BOOL)isOpaque
	{ return YES; }


- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent;
	{ return NO; }

- (void)mouse:(NSEvent*)event
{
	NSRect	r = [self subviewFrame];
	NSPoint	p = [event locationInWindow];
	p = [self convertPoint:p fromView:nil];
	
	if (!NSPointInRect(p, r))
	{
		float rB = r.origin.y;
		float rT = rB + r.size.height;
		float rL = r.origin.x;
		float rR = rL + r.size.width;
		
		if (p.y < rB)
		{
			_divideSide=2;
			_divide = (rR-p.x)/r.size.width;
		}
		else if (p.x < rL)
		{
			_divideSide=3;
			_divide = (p.y-rB)/r.size.height;
		}
		else if (p.y > rT)
		{
			_divideSide=0;
			_divide = (p.x-rL)/r.size.width;
		}
		else // (p.x > rR)
		{
			_divideSide=1;
			_divide = (rT-p.y)/r.size.height;
		}
		
		if (_divide < 0.05) _divide = 0.0;
		if (_divide > 0.95) _divide = 1.0;
		
		[self setNeedsDisplay:YES];
	}
}


- (void)mouseDown:(NSEvent*)event
	{ [self mouse:event]; }

- (void)mouseDragged:(NSEvent*)event;
	{ [self mouse:event]; }

- (void)mouseUp:(NSEvent*)event;
	{ [self mouse:event]; }



- (NSRect) subviewFrame
	{ return [[[self subviews] objectAtIndex:0] frame]; }


- (void) drawRect:(NSRect)clipRect
{
	NSRect			bounds = [self bounds];
	NSRect			rect = [self subviewFrame];
	NSBezierPath*	arc = nil;
	NSPoint			p1,p2,p3;
	
	///if ([[NSGraphicsContext currentContext] isDrawingToScreen])
	{
		[[NSColor colorWithDeviceWhite:0.5 alpha:1.0] set];
		[NSBezierPath fillRect:bounds];
	}
	
	[[NSColor colorWithDeviceWhite:0.8 alpha:1.0] set];
	
	if (_sideBySide==1)
	{
		p1.x = bounds.origin.x + bounds.size.width/2;
		p2.x = bounds.origin.x + bounds.size.width/2;
		p1.y = bounds.origin.y;
		p2.y = bounds.origin.y + bounds.size.height;
	}
	else if (_sideBySide==2)
	{
		p1.y = bounds.origin.y + bounds.size.height/2;
		p2.y = bounds.origin.y + bounds.size.height/2;
		p1.x = bounds.origin.x;
		p2.x = bounds.origin.x + bounds.size.width;
	}
	else
	{
		p1.x = bounds.origin.x;
		p1.y = bounds.origin.y;
		p2.x = bounds.origin.x + bounds.size.width;
		p2.y = bounds.origin.y + bounds.size.height;
		
		if (_divideSide == 0)
			p1.x = p2.x = rect.origin.x + rect.size.width*_divide;
		else if (_divideSide == 1)
			p1.y = p2.y = rect.origin.y + rect.size.height*(1.0-_divide);
		else if (_divideSide == 2)
			p1.x = p2.x = rect.origin.x + rect.size.width*(1.0-_divide);
		else if (_divideSide == 3)
			p1.y = p2.y = rect.origin.y + rect.size.height*_divide;
		
		if (_divideSide == 0)
			{ p3=p2; p3.y-=10; }
		else if (_divideSide == 1)
			{ p3=p2; p3.x-=10; }
		else if (_divideSide == 2)
			{ p3=p1; p3.y+=10; }
		else if (_divideSide == 3)
			{ p3=p1; p3.x+=10; }
			
		arc = [NSBezierPath bezierPath];
		[arc appendBezierPathWithArcWithCenter:p3 radius:6.0
				startAngle:270.0 - 90.0*_divideSide 
				  endAngle: 90.0 - 90.0*_divideSide];
		[arc fill];
	}
		
	[NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
}

- (float) divide
	{ return _divide; }

- (int) divideSide;
	{ return _divideSide; }

- (int) sideBySide
	{ return _sideBySide; }


- (void)keyDown:(NSEvent *)event;
{
	if ([[event characters] characterAtIndex:0] == '\t')
	{
		NSWindow*	w = [self window];
		NSRect		r = [w frame];
		NSRect		subRect = [self subviewFrame];
		
		if (_sideBySide==2)
			_sideBySide=0;
		else
			_sideBySide++;
		
		if (_sideBySide==1)
		{
			r.size.width += subRect.size.width;
			r.origin.x -= subRect.size.width/2;
		}
		else if (_sideBySide==2)
		{
			r.size.width -= subRect.size.width/2;
			r.size.height += subRect.size.height;
			r.origin.x += subRect.size.width/4;
			r.origin.y -= subRect.size.height;
		}
		else
		{
			r.size.height -= subRect.size.height/2;
			r.origin.y += subRect.size.height/2;
		}
		
		[w setFrame:r display:YES];
	}	
	else
		[super keyDown:event];
}



@end
