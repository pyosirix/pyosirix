//
//  PORulerView.m
//  pyOsiriX
//

/*
 Copyright (c) 2016, The Institute of Cancer Research and The Royal Marsden.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 * Neither the name of the copyright holder nor the names of its contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "PORulerView.h"

#define RULE_MARGIN 5.0

@implementation PORulerView

- (id) initWithScrollView:(NSScrollView *)scrollView orientation:(NSRulerOrientation)orientation textView:(POScriptView *)tv
{
	self = [super initWithScrollView:scrollView orientation:orientation];
	if(!self){
		return nil;
	}
	
	textView = [tv retain];
	[self setClientView:textView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSTextDidChangeNotification object:textView];
	
	font = [NSFont labelFontOfSize:9.0];
	[font retain];
	
	color = [NSColor colorWithCalibratedWhite:0.45 alpha:1.0];
	[color retain];
	
	labelAttributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, color, NSForegroundColorAttributeName, nil];
	[labelAttributes retain];
	
	[self setRuleThickness:30.0];
	[self setReservedThicknessForMarkers:0.0];
	[self setReservedThicknessForAccessoryView:0.0];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[textView release];
	[font release];
	[color release];
	[labelAttributes retain];
	[super dealloc];
}

- (void)textDidChange:(NSNotification *)notification
{
	[self setNeedsDisplay:YES];
	[[self scrollView] tile]; //Required to redraw the ruler with a differnt width
}

- (CGFloat)requiredThickness
{
    int lineCount = [textView numberOfLines];
    int nDigits = (unsigned)log10(lineCount) + 1;
	NSMutableString *sampleString = [NSMutableString string];
    for (int i = 0; i < nDigits; i++)
        [sampleString appendString:@"8"];
    NSSize stringSize = [sampleString sizeWithAttributes:labelAttributes];
    return ceilf(stringSize.width + RULE_MARGIN * 2);
}

- (void) drawHashMarksAndLabelsInRect:(NSRect)rect
{
	NSString				*labelText;
	NSUInteger			rectCount;
	NSRectArray				rects;
	float					ypos;
	NSSize					stringSize;

	NSLayoutManager *layoutManager = [textView layoutManager];
	NSTextContainer *container = [textView textContainer];
	
	//The vertical offset of the textView
	float vOffset = [textView textContainerInset].height;
	
	// The range of characters currently visible
	NSRect visibleRect = [[[self scrollView] contentView] bounds];
	NSRange glyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:container];
	NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];

	charRange.length++;
	
	NSMutableArray *linePos = [textView linePositions];
	NSUInteger nLines = [linePos count];
	
	NSRect rulerBounds = [self bounds];
	
	for (NSUInteger line = [textView lineNumberForCharacterPosition:charRange.location]; line <= nLines; line++)
	{
		NSUInteger index = [[linePos objectAtIndex:line-1] unsignedIntValue];
		
		if (NSLocationInRange(index, charRange))
		{
			rects = [layoutManager rectArrayForCharacterRange:NSMakeRange(index, 0)
								 withinSelectedCharacterRange:NSMakeRange(NSNotFound, 0)
											  inTextContainer:container
													rectCount:&rectCount];
			if (rectCount > 0)
			{
				ypos = vOffset + NSMinY(rects[0]) - NSMinY(visibleRect);
				
				//The actual text to show
				labelText = [NSString stringWithFormat:@"%lu", (unsigned long)line];
				
				//The size of the text to display
				stringSize = [labelText sizeWithAttributes:labelAttributes];
				
				//Find the drawing rect and draw it
				float x = NSWidth(rulerBounds) - stringSize.width - RULE_MARGIN;
				float w = NSWidth(rulerBounds);
				float y = ypos + (NSHeight(rects[0]) - stringSize.height) / 2.0;
				float h = NSHeight(rects[0]);
				NSRect labelRect = NSMakeRect(x, y, w, h);
				[labelText drawInRect:labelRect withAttributes:labelAttributes];
			}
		}
		if (index > NSMaxRange(charRange))
		{
			break;
		}
	}
}

@end
