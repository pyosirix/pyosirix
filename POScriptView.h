//
//  POScriptView.h
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

#import <Cocoa/Cocoa.h>
#import "POPythonSyntaxModel.h"

@interface POTextRange : NSObject
{
	NSUInteger location;
	NSUInteger length;
}
@property NSUInteger location, length;
+ rangeFromNSRange:(NSRange)rng;
+ rangeWithLocation:(NSUInteger)loc andLength:(NSUInteger)len;
- (id)initWithLocation:(NSUInteger)loc andLength:(NSUInteger)len;
@end

@interface POScriptView : NSTextView <NSTextFinderClient>
{
	NSMutableArray *linePositions;
	NSRange rangeOfTextToBeInsterted;
	
	NSMutableArray *longStringLocations;
	
	POPythonSyntaxModel *syntaxModel; //This must be set once the view is loaded.
	
	NSCharacterSet *octalCharacters;
	NSCharacterSet *hexCharacters;
	NSCharacterSet *numericCharacters;
	NSCharacterSet *newLineCharacters;
	NSCharacterSet *indentCharacters;
	NSCharacterSet *decimalCharacters;
	NSCharacterSet *binaryCharacters;
	NSCharacterSet *identifierCharacters;
	NSCharacterSet *commentCharacters;
	NSArray *stringPrefixes;
	
	BOOL changeIsPartOfLongString;
}

@property (retain) POPythonSyntaxModel *syntaxModel;

- (int)numberOfLines;
- (int)lineNumberForCharacterPosition:(NSInteger)pos;
- (int)lineNumber;
- (NSArray *)lineNumbersForRange:(NSRange)range;
- (NSArray *)lineNumbersForSelectedRange;
- (void)selectAndDisplayLine:(int)lineNo;
- (NSMutableArray *)linePositions;

- (void) indentSelectedRange;
- (void) undentSelectedRange;
- (void) commentSelectedRange;
- (void) uncommentSelectedRange;

@end
