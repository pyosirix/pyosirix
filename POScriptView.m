//
//  POScriptView.m
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

#import "POScriptView.h"
#import <Carbon/Carbon.h>

#pragma mark POTextRange implementation

@implementation POTextRange

@synthesize location, length;

-(id)initWithLocation:(NSUInteger)loc andLength:(NSUInteger)len
{
	if (![super init]) {
		return nil;
	}
	self.location = loc;
	self.length = len;
	return self;
}

+(POTextRange *)rangeFromNSRange:(NSRange)rng
{
	return [[[POTextRange alloc] initWithLocation:rng.location andLength:rng.length] autorelease];
}

+(POTextRange *)rangeWithLocation:(NSUInteger)loc andLength:(NSUInteger)len
{
	return [[[POTextRange alloc] initWithLocation:loc andLength:len] autorelease];
}

- (NSRange)range
{
	return NSMakeRange([self location], [self length]);
}

@end

# pragma mark -
# pragma mark POScriptView implementation

@implementation POScriptView

@synthesize syntaxModel;

- (void)updateLongStringLocations
{
	NSString *content = [self string];
	[longStringLocations removeAllObjects];
	
	NSUInteger loc = 0;
	
	POTextRange *currRange = nil;
	
	//TODO - Need to include the ''' longstring format also!
	while (loc < [content length]) {
		NSRange rng = [content rangeOfString:@"\"\"\"" options:NSLiteralSearch range:NSMakeRange(loc, [content length]-loc)];
		if (rng.location != NSNotFound) {
			if (currRange)
			{
				currRange.length = rng.location+3-currRange.location;
				loc = rng.location + 3;
				currRange = nil;
			}
			else
			{
				currRange = [POTextRange rangeWithLocation:rng.location andLength:3];
				loc = rng.location + 3;
				[longStringLocations addObject:currRange];
			}
		}
		else {
			if (currRange)
			{
				currRange.length = [content length] - currRange.location;
				loc = [content length];
				currRange = nil;
			}
			else
			{
				loc = [content length];
			}
		}
	}
}

- (NSArray *)lineNumbersForRange:(NSRange)range
{
	NSMutableArray *lines = [NSMutableArray array];
	NSString *str = [self string];
	NSUInteger lineNo = [self lineNumberForCharacterPosition:range.location], index = range.location, end = NSMaxRange(range);
	do{
		[lines addObject:[NSNumber numberWithInteger:lineNo]];
		lineNo++;
		index = NSMaxRange([str lineRangeForRange:NSMakeRange(index, 0)]);
	}while(index < end);
	
	return [NSArray arrayWithArray:lines];
}

- (NSArray *)lineNumbersForSelectedRange
{
	return [self lineNumbersForRange:[self selectedRange]];
}

- (void)awakeFromNib
{
	[self setGrammarCheckingEnabled:NO];
	[self setAutomaticQuoteSubstitutionEnabled:NO];
	linePositions = [[NSMutableArray alloc] init];
	longStringLocations = [[NSMutableArray alloc] init];
	
	newLineCharacters = [[NSCharacterSet newlineCharacterSet] retain];
	indentCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"\t"] retain];
	octalCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"01234567"] retain];
	hexCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] retain];
	binaryCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"01"] retain];
	decimalCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] retain];
	numericCharacters = [[NSCharacterSet characterSetWithCharactersInString:@".ej0123456789"] retain];
	identifierCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"] retain];
	stringPrefixes = [[NSArray arrayWithObjects:@"r", @"u", @"ur", @"R", @"U", @"UR", @"Ur", @"uR", @"b", @"B", @"br", @"Br", @"bR", @"BR", nil] retain];
	commentCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"#"] retain];
	
	[self updateLinePositions];
}

- (void) dealloc
{
	[linePositions release];
	[longStringLocations release];
	if (syntaxModel)
		[syntaxModel release];
	
	[newLineCharacters release];
	[octalCharacters release];
	[hexCharacters release];
	[binaryCharacters release];
	[decimalCharacters release];
	[numericCharacters release];
	[identifierCharacters release];
	[stringPrefixes release];
	[commentCharacters release];
	
	[super dealloc];
}

- (int)lineNumberForCharacterPosition:(NSInteger)pos
{
	int lineNo = 1;
	const char *str = [[self string] UTF8String];
	NSUInteger end = (pos < [[self string] length])?pos:[[self string] length];
	for (int i = 0; i < end; i++)
	{
		if (str[i] == '\n')
			lineNo++;
	}
	
	return lineNo;
}

- (void)setString:(NSString *)string
{
	[super setString:string];
	rangeOfTextToBeInsterted = NSMakeRange(0, [string length]);
	[self didChangeText];
}

- (int)lineNumber
{
	NSInteger curPos = [[[self selectedRanges] objectAtIndex:0] rangeValue].location;
	return [self lineNumberForCharacterPosition:curPos];
}

- (void)updateLinePositions
{
	[linePositions removeAllObjects];
	
	NSString *str = [self string];
	NSUInteger index = 0, stringLength = [str length];
	do
	{
		NSRange lineRange = [str lineRangeForRange:NSMakeRange(index, 0)];
		index = NSMaxRange(lineRange);
		[linePositions addObject:[NSNumber numberWithInteger:lineRange.location]];
	}while(index < stringLength);
	
	//Check for final newline
	if (stringLength > 0){
		if ([str characterAtIndex:stringLength-1] == '\n')
			[linePositions addObject:[NSNumber numberWithInteger:stringLength]];
	}
}

- (NSMutableArray *)linePositions
{
	return linePositions;
}

- (void)didChangeText
{
	[[self textStorage] beginEditing];
	[self updateLinePositions];
	[self updateLongStringLocations];
	[self updateSyntaxInRange:rangeOfTextToBeInsterted];
	[[self textStorage] endEditing];
	[super didChangeText];
}

- (void) undentRange:(POTextRange *)oRange
{
	NSString *content = [self string];
	if ([content length] == 0)
		return;
	
	[[self textStorage] beginEditing];
	NSRange newRange = [oRange range];
	int idx = (int)newRange.location;
	
	//Wind back to start of line
	unichar curChar;
	while (idx > 0)
	{
		idx--;
		curChar = [content characterAtIndex:idx];
		if ([newLineCharacters characterIsMember:curChar])
		{
			idx++;
			break;
		}
	}
	
	if ([content characterAtIndex:idx] == '\t') {
		[self replaceCharactersInRange:NSMakeRange(idx, 1) withString:@""];
		newRange.location = newRange.location - 1;
	}
	
	BOOL newlineFound = NO;
	while (idx < newRange.location + newRange.length && idx < [content length]) {
		if (newlineFound)
		{
			if ([content characterAtIndex:idx] == '\t') {
				[self replaceCharactersInRange:NSMakeRange(idx, 1) withString:@""];
				newRange.length = newRange.length - 1;
			}
			newlineFound = NO;
		}
		curChar = [content characterAtIndex:idx];
		if ([newLineCharacters characterIsMember:curChar])
			newlineFound = YES;
		idx++;
	}
	[[self textStorage] endEditing];
	[self setSelectedRange:newRange]; //This is a little lazy but seems to work
	[self setNeedsDisplay:YES];
	
	[[self undoManager] registerUndoWithTarget:self selector:@selector(indentRange:) object:[POTextRange rangeFromNSRange:newRange]];
}

- (void) indentRange:(POTextRange *)oRange
{
	NSString *content = [self string];
	if ([content length] == 0)
		return;
	
	[[self textStorage] beginEditing];
	NSRange newRange = [oRange range];
	int idx = (int)newRange.location;
	
	//Wind back to start of line
	unichar curChar;
	while (idx > 0)
	{
		idx--;
		curChar = [content characterAtIndex:idx];
		if ([newLineCharacters characterIsMember:curChar])
		{
			idx++;
			break;
		}
	}
	
	[self replaceCharactersInRange:NSMakeRange(idx, 0) withString:@"\t"];
	newRange.location = newRange.location + 1;
	idx++;
	
	BOOL newlineFound = NO;
	while (idx < newRange.location + newRange.length) {
		if (newlineFound)
		{
			[self replaceCharactersInRange:NSMakeRange(idx, 0) withString:@"\t"];
			newRange.length = newRange.length + 1;
			idx++;
			newlineFound = NO;
		}
		curChar = [content characterAtIndex:idx];
		if ([newLineCharacters characterIsMember:curChar])
			newlineFound = YES;
		idx++;
	}
	[[self textStorage] endEditing];
	[self setSelectedRange:newRange];
	[self setNeedsDisplay:YES];
	
	[[self undoManager] registerUndoWithTarget:self selector:@selector(undentRange:) object:[POTextRange rangeFromNSRange:newRange]];
}

- (void) indentSelectedRange
{
	[self indentRange:[POTextRange rangeFromNSRange:[self selectedRange]]];
}

- (void) undentSelectedRange
{
	[self undentRange:[POTextRange rangeFromNSRange:[self selectedRange]]];
}

- (void) uncommentRange:(POTextRange *)oRange
{
	NSString *content = [self string];
	if ([content length] == 0)
		return;
	
	[[self textStorage] beginEditing];
	NSRange newRange = [oRange range];
	int idx = (int)newRange.location;
	
	//Wind back to start of line
	unichar curChar;
	while (idx > 0)
	{
		idx--;
		curChar = [content characterAtIndex:idx];
		if ([newLineCharacters characterIsMember:curChar])
		{
			idx++;
			break;
		}
	}
	
	if ([content characterAtIndex:idx] == '#') {
		[self replaceCharactersInRange:NSMakeRange(idx, 1) withString:@""];
		newRange.location = newRange.location - 1;
	}
	
	BOOL newlineFound = NO;
	while (idx < newRange.location + newRange.length && idx < [content length]) {
		if (newlineFound)
		{
			if ([content characterAtIndex:idx] == '#') {
				[self replaceCharactersInRange:NSMakeRange(idx, 1) withString:@""];
				newRange.length = newRange.length - 1;
			}
			newlineFound = NO;
		}
		curChar = [content characterAtIndex:idx];
		if ([newLineCharacters characterIsMember:curChar])
			newlineFound = YES;
		idx++;
	}
	[[self textStorage] endEditing];
	
	[self updateSyntaxInRange:newRange];
	[self setSelectedRange:newRange]; //This is a little lazy but seems to work
	[self setNeedsDisplay:YES];
	
	[[self undoManager] registerUndoWithTarget:self selector:@selector(commentRange:) object:[POTextRange rangeFromNSRange:newRange]];
}

- (void) commentRange:(POTextRange *)oRange
{
	NSString *content = [self string];
	if ([content length] == 0)
		return;
	
	[[self textStorage] beginEditing];
	NSRange newRange = [oRange range];
	int idx = (int)newRange.location;
	
	//Wind back to start of line
	unichar curChar;
	while (idx > 0)
	{
		idx--;
		curChar = [content characterAtIndex:idx];
		if ([newLineCharacters characterIsMember:curChar])
		{
			idx++;
			break;
		}
	}
	
	[self replaceCharactersInRange:NSMakeRange(idx, 0) withString:@"#"];
	newRange.location = newRange.location + 1;
	idx++;
	
	BOOL newlineFound = NO;
	while (idx < newRange.location + newRange.length) {
		if (newlineFound)
		{
			[self replaceCharactersInRange:NSMakeRange(idx, 0) withString:@"#"];
			newRange.length = newRange.length + 1;
			idx++;
			newlineFound = NO;
		}
		curChar = [content characterAtIndex:idx];
		if ([newLineCharacters characterIsMember:curChar])
			newlineFound = YES;
		idx++;
	}
	[[self textStorage] endEditing];
	
	[self updateSyntaxInRange:newRange];
	[self setSelectedRange:newRange];
	[self setNeedsDisplay:YES];
	
	[[self undoManager] registerUndoWithTarget:self selector:@selector(uncommentRange:) object:[POTextRange rangeFromNSRange:newRange]];
}


- (void) commentSelectedRange
{
	[self commentRange:[POTextRange rangeFromNSRange:[self selectedRange]]];
}

- (void) uncommentSelectedRange
{
	[self uncommentRange:[POTextRange rangeFromNSRange:[self selectedRange]]];
}

- (int)numberOfLines
{
	NSString *str = [self string];
	NSUInteger numberOfLines, index, stringLength = [str length];
	for (index = 0, numberOfLines = 0; index < stringLength; numberOfLines++)
		index = NSMaxRange([str lineRangeForRange:NSMakeRange(index, 0)]);
	return (int)numberOfLines;
}

- (void)selectAndDisplayLine:(int)lineNo
{
	int maxLine = [self numberOfLines];
	if(lineNo > maxLine)
		return;
	NSMutableArray *positions = [self linePositions];
	int pos = (int)[[positions objectAtIndex:lineNo-1] integerValue];
	int pos2;
	if (lineNo < maxLine)
		pos2 = (int)[[positions objectAtIndex:lineNo] integerValue];
	else
		pos2 = (int)[[self string] length];
	NSRange selectionRange = NSMakeRange(pos, pos2-pos);
	[self setSelectedRange:selectionRange];
	[self scrollRangeToVisible:selectionRange];
}

- (void)insertNewline:(id)sender
{
	NSInteger curPos = [[[self selectedRanges] objectAtIndex:0] rangeValue].location;
	if (curPos == 0)
	{
		[super insertNewline:sender];
		return;
	}
		
	NSString *str = [self string];
	NSString *line = [str substringWithRange:[str lineRangeForRange:NSMakeRange(curPos, 0)]];
	
	int nTabs;
	for(nTabs = 0; nTabs < [line length]; nTabs++)
	{
		if (![[line substringWithRange:NSMakeRange(nTabs, 1)] isEqualToString:@"\t"])
			 break;
	}
	if([[str substringWithRange:NSMakeRange(curPos-1, 1)] isEqualToString:@":"])
		nTabs++;
	
	[super insertNewline:sender];
	for(int i = 0; i < nTabs; i++)
		[self insertTab:self];
}

- (BOOL)shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	rangeOfTextToBeInsterted = NSMakeRange(affectedCharRange.location, [replacementString length]);
	return [super shouldChangeTextInRange:affectedCharRange replacementString:replacementString];;
}

- (void)updateSyntaxInRange:(NSRange)range
{
	if (!syntaxModel)
		return; //Cannot do anything so don't recolour the text
	
	NSString *content = [self string];
	
	//Wind backward to start of line/start of content
	NSUInteger loc = range.location;
	unichar curChar = '0';
	while (loc > 0)
	{
		curChar = [content characterAtIndex:loc-1];
		if ([newLineCharacters characterIsMember:curChar])
			break;
		else
			loc--;
	}
	
	//Wind forward to end of line/end of content
	NSInteger length = range.length + range.location - loc;
	while (loc + length < [content length]) {
		curChar = [content characterAtIndex:loc+length];
		if ([newLineCharacters characterIsMember:curChar])
			break;
		else
			length++;
	}
	
	NSInteger curPosition = loc;
	curChar = '0';
	while (curPosition < loc+length) {
		//Find the next character in the string
		curChar = [content characterAtIndex:curPosition];
		
		//Is it a comment?
		if (curChar == '#') {
			//Comment out the rest of the line (not in a string literal)
			NSUInteger end = curPosition+1;
			while (!(curChar == '\n') && end < [content length]) {
				curChar = [content characterAtIndex:end];
				end++;
			}
			NSRange rangeToEnd = NSMakeRange(curPosition, end-curPosition);
			NSDictionary *attributes = [syntaxModel commentAttributes];
			NSFont *f = [attributes objectForKey:POPSM_FONT_KEY];
			NSColor *c = [attributes objectForKey:POPSM_COLOR_KEY];
			[self.textStorage addAttributes:@{NSFontAttributeName: f, NSForegroundColorAttributeName: c} range:rangeToEnd];
			curPosition = end;
			continue; //Nothing else to see here
		}
		
		//Is it a double quotation?
		if (curChar == '"') {
			NSUInteger end = curPosition+1;
			
			//Find the end of the string and color accordingly
			curChar = '0'; //Forget this first case
			while (curChar != '"' && curChar != '\n' && end < [content length]) {
				curChar = [content characterAtIndex:end];
				end++;
			}
			
			//Are there any string prefixes?
			if (curPosition > 0)
			{
				unichar preceedingChar = [content characterAtIndex:curPosition-1];
				if ([stringPrefixes containsObject:[NSString stringWithFormat:@"%c", preceedingChar]])
				{
					curPosition--;
					if (curPosition > 0) {
						unichar secondPreceedingChar = [content characterAtIndex:curPosition-1];
						if ([identifierCharacters characterIsMember:secondPreceedingChar]) {
							if ([stringPrefixes containsObject:[NSString stringWithFormat:@"%c%c", secondPreceedingChar, preceedingChar]]) {
								curPosition--;
							}
						}
					}
				}
			}
			
			NSRange rangeToNext = NSMakeRange(curPosition, end-curPosition);
			NSDictionary *attributes = [syntaxModel stringAttributes];
			NSFont *f = [attributes objectForKey:POPSM_FONT_KEY];
			NSColor *c = [attributes objectForKey:POPSM_COLOR_KEY];
			[self.textStorage addAttributes:@{NSFontAttributeName: f, NSForegroundColorAttributeName: c} range:rangeToNext];
			curPosition = end;
			continue;
		}
		
		//Is it a single quotation?
		if (curChar == '\'') {
			//Find the end of the string and color accordingly
			NSUInteger end = curPosition+1;
			curChar = '0'; //Forget this first case
			while (!(curChar == '\'') && !(curChar == '\n') && end < [content length]) {
				curChar = [content characterAtIndex:end];
				end++;
			}
			
			//Are there any string prefixes?
			if (curPosition > 0)
			{
				unichar preceedingChar = [content characterAtIndex:curPosition-1];
				if ([stringPrefixes containsObject:[NSString stringWithFormat:@"%c", preceedingChar]])
				{
					curPosition--;
					if (curPosition > 0) {
						unichar secondPreceedingChar = [content characterAtIndex:curPosition-1];
						if ([identifierCharacters characterIsMember:secondPreceedingChar]) {
							if ([stringPrefixes containsObject:[NSString stringWithFormat:@"%c%c", secondPreceedingChar, preceedingChar]]) {
								curPosition--;
							}
						}
					}
				}
			}
			
			NSRange rangeToNext = NSMakeRange(curPosition, end-curPosition);
			NSDictionary *attributes = [syntaxModel stringAttributes];
			NSFont *f = [attributes objectForKey:POPSM_FONT_KEY];
			NSColor *c = [attributes objectForKey:POPSM_COLOR_KEY];
			[self.textStorage addAttributes:@{NSFontAttributeName: f, NSForegroundColorAttributeName: c} range:rangeToNext];
			curPosition = end;
			continue;
		}
		
		//Is it a number?
		if ([decimalCharacters characterIsMember:curChar]) {
			//Need to watch out for instances of '.', 'e'. Can only have one of each and the former must appear before the latter.  Also, '+' and '-' allowed immediately following 'e'.
			BOOL hexFound = NO, octFound = NO, binaryFound = NO;
			BOOL eFound = NO, dotFound = NO;
			
			NSUInteger end = curPosition+1;
			
			//Is it binary, octal or hexadecimal?
			if (curChar == '0'){
				if (end < [content length])
				{
					unichar nextChar = [content characterAtIndex:end];
					if (nextChar == 'x' || nextChar == 'X')
					{
						hexFound = YES;
						end++;
					}
					else if (nextChar == 'b' || nextChar == 'B')
					{
						binaryFound = YES;
						end++;
					}
					else if (nextChar == 'o' || nextChar == 'O')
					{
						octFound = YES;
						end++;
					}
				}
			}
			
			NSCharacterSet *pyNumeric;
			if (octFound)
				pyNumeric = octalCharacters;
			else if (hexFound)
				pyNumeric = hexCharacters;
			else if (binaryFound)
				pyNumeric = binaryCharacters;
			else
				pyNumeric = numericCharacters;
			
			while ([pyNumeric characterIsMember:curChar] && end < [content length])
			{
				curChar = [content characterAtIndex:end];
				
				if (![pyNumeric characterIsMember:curChar])
					break; //This can occur for the very following number if ignored.
				
				//are they creating a float?
				if (curChar == 'e') {
					if (eFound)
						break; //Second 'e' encountered
					
					//Is there a ± after?
					if (end < [content length]-1) {
						unichar nextChar = [content characterAtIndex:end+1];
						if (nextChar == '+' || nextChar == '-') {
							end++;
						}
					}
					eFound = YES;
				}
				
				if (curChar == '.') {
					if (dotFound || eFound)
						break; //Cant be two decimals or a floating exponent
					dotFound = YES;
				}
				end++;
			}
			NSRange numericRange = NSMakeRange(curPosition, end-curPosition);
			NSDictionary *attributes = [syntaxModel numericAttributes];
			NSFont *f = [attributes objectForKey:POPSM_FONT_KEY];
			NSColor *c = [attributes objectForKey:POPSM_COLOR_KEY];
			[self.textStorage addAttributes:@{NSFontAttributeName: f, NSForegroundColorAttributeName: c} range:numericRange];
			curPosition = end;
			continue;
		}
		
		//Is it an identifier?
		if ([identifierCharacters characterIsMember:curChar]) {
			NSUInteger end = curPosition;
			NSString *str = [self string];
			
			//Fast forward to the end of the word
			while (end < [str length] ) {
				curChar = [str characterAtIndex:end];
				if (![identifierCharacters characterIsMember:curChar])
					break;
				end++;
			}
			NSRange wordRange = NSMakeRange(curPosition, end-curPosition);
			NSString *word = [str substringWithRange:wordRange];
			NSDictionary *attributes = [syntaxModel pythonSyntaxAttributesForWord:word];
			if (attributes)
			{
				//Update the word font
				NSFont *f = [attributes objectForKey:POPSM_FONT_KEY];
				NSColor *c = [attributes objectForKey:POPSM_COLOR_KEY];
				[self.textStorage addAttributes:@{NSFontAttributeName: f, NSForegroundColorAttributeName: c} range:wordRange];
			}
			curPosition = end;
			continue;
		}
		
		//Should be a symbol by this point.  Carry on to next character.
		NSRange pRange = NSMakeRange(curPosition, 1);
		NSDictionary *attributes = [syntaxModel textAttributes];
		NSFont *f = [attributes objectForKey:POPSM_FONT_KEY];
		NSColor *c = [attributes objectForKey:POPSM_COLOR_KEY];
		[self.textStorage addAttributes:@{NSFontAttributeName: f, NSForegroundColorAttributeName: c} range:pRange];
		curPosition++;
	}
}

@end
