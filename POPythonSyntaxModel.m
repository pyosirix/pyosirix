//
//  POPythonSyntaxModel.m
//  pyOsiriX

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

#import "POPythonSyntaxModel.h"

@implementation POPythonSyntaxModel

@synthesize commentAttributes, constantAttributes, exceptionAttributes, functionAttributes, keywordAttributes, numericAttributes, osirixAttributes, textAttributes, stringAttributes;

- (id)init
{
	self = [super init];
	if (self) {
		[self loadKeywordDefinitions];
		[self loadDefaultAttributes];
	}
	return self;
}

- (void) loadKeywordDefinitions
{
	if (keywordDefinitions) {
		return;
	}
	NSString *loc = [[NSBundle bundleForClass:[self class]] pathForResource:@"pythonKeywords" ofType:@"plist"];
	keywordDefinitions = [[NSDictionary dictionaryWithContentsOfFile:loc] retain];
}

- (NSDictionary *) defaultsDictionaryFromAttibute:(NSDictionary *)att
{
	NSColor *col = [att valueForKey:POPSM_COLOR_KEY];
	NSFont *font = [att valueForKey:POPSM_FONT_KEY];
	
	NSNumber *r = [NSNumber numberWithFloat:[col redComponent]];
	NSNumber *g = [NSNumber numberWithFloat:[col greenComponent]];
	NSNumber *b = [NSNumber numberWithFloat:[col blueComponent]];
	NSNumber *a = [NSNumber numberWithFloat:[col alphaComponent]];
	NSDictionary *colDict = [NSDictionary dictionaryWithObjectsAndKeys:r, @"r", g, @"g", b, @"b", a, @"a", nil];
	
	NSString *fontName = [font fontName];
	NSNumber *fontSize = [NSNumber numberWithFloat:[font pointSize]];
	NSDictionary *fontDict = [NSDictionary dictionaryWithObjectsAndKeys:fontName, @"name", fontSize, @"size", nil];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:fontDict, POPSM_FONT_KEY, colDict, POPSM_COLOR_KEY, nil];
}

- (NSDictionary *) attributeFromDefaultsDictionary:(NSDictionary *)dict
{
	NSDictionary *colDict = [dict valueForKey:POPSM_COLOR_KEY];
	NSDictionary *fontDict = [dict valueForKey:POPSM_FONT_KEY];
	
	NSNumber *r = [colDict valueForKey:@"r"];
	NSNumber *g = [colDict valueForKey:@"g"];
	NSNumber *b = [colDict valueForKey:@"b"];
	NSNumber *a = [colDict valueForKey:@"a"];
	NSColor *col = [NSColor colorWithCalibratedRed:[r floatValue] green:[g floatValue] blue:[b floatValue] alpha:[a floatValue]];
	
	NSString *fontName = [fontDict valueForKey:@"name"];
	NSNumber *fontSize = [fontDict valueForKey:@"size"];
	NSFont *font = [NSFont fontWithName:fontName size:[fontSize floatValue]];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, col, POPSM_COLOR_KEY, nil];
}

- (void) loadDefaultAttributes
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	
	//Comments font
	if ([defs valueForKey:POPSM_COMMENTS]) {
		commentAttributes = [[self attributeFromDefaultsDictionary:[defs valueForKey:POPSM_COMMENTS] ]retain];
	}
	else {
		NSFont *font = [[NSFont fontWithName:@"Menlo-Regular" size:12.0] retain];
		NSColor *color = [[NSColor colorWithCalibratedRed:0.6 green:0.6 blue:0.6 alpha:1.0] retain];
		commentAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
		[defs setObject:[self defaultsDictionaryFromAttibute:commentAttributes] forKey:POPSM_COMMENTS];
	}
	
	//Python constants font
	if ([defs valueForKey:POPSM_CONTANTS]) {
		constantAttributes = [[self attributeFromDefaultsDictionary:[defs valueForKey:POPSM_CONTANTS] ]retain];
	}
	else {
		NSFont *font = [[NSFont fontWithName:@"Menlo-Regular" size:12.0] retain];
		NSColor *color = [[NSColor colorWithCalibratedRed:0.5 green:0.0 blue:1.0 alpha:1.0] retain];
		constantAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
		[defs setObject:[self defaultsDictionaryFromAttibute:constantAttributes] forKey:POPSM_CONTANTS];
	}
	
	//Python exceptions font
	if ([defs valueForKey:POPSM_EXCEPTIONS]) {
		exceptionAttributes = [[self attributeFromDefaultsDictionary:[defs valueForKey:POPSM_EXCEPTIONS] ]retain];
	}
	else {
		NSFont *font = [[NSFont fontWithName:@"Menlo-Regular" size:12.0] retain];
		NSColor *color = [[NSColor colorWithCalibratedRed:0.0 green:0.6 blue:0.5 alpha:1.0] retain];
		exceptionAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
		[defs setObject:[self defaultsDictionaryFromAttibute:exceptionAttributes] forKey:POPSM_EXCEPTIONS];
	}
	
	//Python functions font
	if ([defs valueForKey:POPSM_FUNCTIONS]) {
		functionAttributes = [[self attributeFromDefaultsDictionary:[defs valueForKey:POPSM_FUNCTIONS] ]retain];
	}
	else {
		NSFont *font = [[NSFont fontWithName:@"Menlo-Regular" size:12.0] retain];
		NSColor *color = [[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:1.0 alpha:1.0] retain];
		functionAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
		[defs setObject:[self defaultsDictionaryFromAttibute:functionAttributes] forKey:POPSM_FUNCTIONS];
	}
	
	//Python keywords font
	if ([defs valueForKey:POPSM_KEYWORDS]) {
		keywordAttributes = [[self attributeFromDefaultsDictionary:[defs valueForKey:POPSM_KEYWORDS]]retain];
	}
	else {
		NSFont *font = [[NSFont fontWithName:@"Menlo-Regular" size:12.0] retain];
		NSColor *color = [[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:1.0 alpha:1.0] retain];
		keywordAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
		[defs setObject:[self defaultsDictionaryFromAttibute:keywordAttributes] forKey:POPSM_KEYWORDS];
	}
	
	//Number font
	if ([defs valueForKey:POPSM_NUMBERS]) {
		numericAttributes = [[self attributeFromDefaultsDictionary:[defs valueForKey:POPSM_NUMBERS]]retain];
	}
	else {
		NSFont *font = [[NSFont fontWithName:@"Menlo-Regular" size:12.0] retain];
		NSColor *color = [[NSColor colorWithCalibratedRed:0.55 green:0.6 blue:0.0 alpha:1.0] retain];
		numericAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
		[defs setObject:[self defaultsDictionaryFromAttibute:numericAttributes] forKey:POPSM_NUMBERS];
	}
	
	//OsiriX keywords font
	if ([defs valueForKey:POPSM_OSIRIX]) {
		osirixAttributes = [[self attributeFromDefaultsDictionary:[defs valueForKey:POPSM_OSIRIX] ]retain];
	}
	else {
		NSFont *font = [[NSFont fontWithName:@"Menlo-Regular" size:12.0] retain];
		NSColor *color = [[NSColor colorWithCalibratedRed:0.0 green:0.6 blue:0.55 alpha:1.0] retain];
		osirixAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
		[defs setObject:[self defaultsDictionaryFromAttibute:osirixAttributes] forKey:POPSM_OSIRIX];
	}
	
	//Plain text font
	if ([defs valueForKey:POPSM_PLAINTEXT]) {
		textAttributes = [[self attributeFromDefaultsDictionary:[defs valueForKey:POPSM_PLAINTEXT] ]retain];
	}
	else {
		NSFont *font = [[NSFont fontWithName:@"Menlo-Regular" size:12.0] retain];
		NSColor *color = [[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0] retain];
		textAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
		[defs setObject:[self defaultsDictionaryFromAttibute:textAttributes] forKey:POPSM_PLAINTEXT];
	}
	
	//String font
	if ([defs valueForKey:POPSM_STRINGS]) {
		stringAttributes = [[self attributeFromDefaultsDictionary:[defs valueForKey:POPSM_STRINGS] ]retain];
	}
	else {
		NSFont *font = [[NSFont fontWithName:@"Menlo-Regular" size:12.0] retain];
		NSColor *color = [[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:1.0] retain];
		stringAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
		[defs setObject:[self defaultsDictionaryFromAttibute:stringAttributes] forKey:POPSM_STRINGS];
	}
	
}

- (NSDictionary *) pythonSyntaxAttributesForWord:(NSString *)word
{
	if ([[keywordDefinitions objectForKey:@"keywords"] containsObject:word])
		return keywordAttributes;
	if ([[keywordDefinitions objectForKey:@"functions"] containsObject:word])
		return functionAttributes;
	if ([[keywordDefinitions objectForKey:@"exceptions"] containsObject:word])
		return exceptionAttributes;
	if ([[keywordDefinitions objectForKey:@"constants"] containsObject:word])
		return constantAttributes;
	if ([[keywordDefinitions objectForKey:@"osirix"] containsObject:word])
		return textAttributes; //For now do not color these words...
	return textAttributes;
}

- (void)setCommentAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault
{
	NSFont *font = [attributes valueForKey:POPSM_FONT_KEY];
	NSColor *color = [attributes valueForKey:POPSM_COLOR_KEY];
	if (!font || !color) {
		return;
	}
	if (commentAttributes)
		[commentAttributes release];
	commentAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
	[[NSUserDefaults standardUserDefaults] setObject:[self defaultsDictionaryFromAttibute:commentAttributes] forKey:POPSM_COMMENTS];
}

- (void)setConstantAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault
{
	NSFont *font = [attributes valueForKey:POPSM_FONT_KEY];
	NSColor *color = [attributes valueForKey:POPSM_COLOR_KEY];
	if (!font || !color) {
		return;
	}
	if (constantAttributes)
		[constantAttributes release];
	constantAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
	[[NSUserDefaults standardUserDefaults] setObject:[self defaultsDictionaryFromAttibute:constantAttributes] forKey:POPSM_CONTANTS];
}

- (void)setExceptionAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault
{
	NSFont *font = [attributes valueForKey:POPSM_FONT_KEY];
	NSColor *color = [attributes valueForKey:POPSM_COLOR_KEY];
	if (!font || !color) {
		return;
	}
	if (exceptionAttributes)
		[exceptionAttributes release];
	exceptionAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
	[[NSUserDefaults standardUserDefaults] setObject:[self defaultsDictionaryFromAttibute:exceptionAttributes] forKey:POPSM_EXCEPTIONS];
}

- (void)setFunctionAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault
{
	NSFont *font = [attributes valueForKey:POPSM_FONT_KEY];
	NSColor *color = [attributes valueForKey:POPSM_COLOR_KEY];
	if (!font || !color) {
		return;
	}
	if (functionAttributes)
		[functionAttributes release];
	functionAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
	[[NSUserDefaults standardUserDefaults] setObject:[self defaultsDictionaryFromAttibute:functionAttributes] forKey:POPSM_FUNCTIONS];
}

- (void)setKeywordAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault
{
	NSFont *font = [attributes valueForKey:POPSM_FONT_KEY];
	NSColor *color = [attributes valueForKey:POPSM_COLOR_KEY];
	if (!font || !color) {
		return;
	}
	if (keywordAttributes)
		[keywordAttributes release];
	keywordAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
	[[NSUserDefaults standardUserDefaults] setObject:[self defaultsDictionaryFromAttibute:keywordAttributes] forKey:POPSM_KEYWORDS];
}

- (void)setNumberAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault
{
	NSFont *font = [attributes valueForKey:POPSM_FONT_KEY];
	NSColor *color = [attributes valueForKey:POPSM_COLOR_KEY];
	if (!font || !color) {
		return;
	}
	if (numericAttributes)
		[numericAttributes release];
	numericAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
	[[NSUserDefaults standardUserDefaults] setObject:[self defaultsDictionaryFromAttibute:numericAttributes] forKey:POPSM_NUMBERS];
}

- (void)setOsirixAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault
{
	NSFont *font = [attributes valueForKey:POPSM_FONT_KEY];
	NSColor *color = [attributes valueForKey:POPSM_COLOR_KEY];
	if (!font || !color) {
		return;
	}
	if (osirixAttributes)
		[osirixAttributes release];
	osirixAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
	[[NSUserDefaults standardUserDefaults] setObject:[self defaultsDictionaryFromAttibute:osirixAttributes] forKey:POPSM_OSIRIX];
}

- (void)setPlaintextAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault
{
	NSFont *font = [attributes valueForKey:POPSM_FONT_KEY];
	NSColor *color = [attributes valueForKey:POPSM_COLOR_KEY];
	if (!font || !color) {
		return;
	}
	if (textAttributes)
		[textAttributes release];
	textAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
	[[NSUserDefaults standardUserDefaults] setObject:[self defaultsDictionaryFromAttibute:textAttributes] forKey:POPSM_PLAINTEXT];
}

- (void)setStringAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault
{
	NSFont *font = [attributes valueForKey:POPSM_FONT_KEY];
	NSColor *color = [attributes valueForKey:POPSM_COLOR_KEY];
	if (!font || !color) {
		return;
	}
	if (stringAttributes)
		[stringAttributes release];
	stringAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:font, POPSM_FONT_KEY, color, POPSM_COLOR_KEY, nil] retain];
	[[NSUserDefaults standardUserDefaults] setObject:[self defaultsDictionaryFromAttibute:stringAttributes] forKey:POPSM_STRINGS];
}

@end
