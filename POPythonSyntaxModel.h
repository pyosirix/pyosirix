//
//  POPythonSyntaxModel.h
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

#import <Foundation/Foundation.h>

#define POPSM_KEYWORDS @"pyosirix_keyword_attributes"
#define POPSM_FUNCTIONS @"pyosirix_function_attributes"
#define POPSM_OSIRIX @"pyosirix_osirix_attributes"
#define POPSM_EXCEPTIONS @"pyosirix_exception_attributes"
#define POPSM_CONTANTS @"pyosirix_constant_attributes"
#define POPSM_PLAINTEXT @"pyosirix_plaintext_attributes"
#define POPSM_STRINGS @"pyosirix_string_attributes"
#define POPSM_COMMENTS @"pyosirix_comment_attributes"
#define POPSM_NUMBERS @"pyosirix_number_attributes"

#define POPSM_FONT_KEY @"font"
#define POPSM_COLOR_KEY @"color"

@interface POPythonSyntaxModel : NSObject
{
	//Container for the python keywords
	NSDictionary *keywordDefinitions;

	//Containers for the Attributes of each syntax type
	//Each dictionary will be of the form
	//	att = {"font":(NSFont *)font, "color":(NSColor *)color}
	NSDictionary *keywordAttributes;
	NSDictionary *functionAttributes;
	NSDictionary *osirixAttributes;
	NSDictionary *exceptionAttributes;
	NSDictionary *constantAttributes;
	NSDictionary *textAttributes;
	NSDictionary *stringAttributes;
	NSDictionary *commentAttributes;
	NSDictionary *numericAttributes;
}

@property (retain) NSDictionary *keywordAttributes, *functionAttributes, *osirixAttributes, *exceptionAttributes, *constantAttributes, *textAttributes, *stringAttributes, *commentAttributes, *numericAttributes;

- (NSDictionary *) pythonSyntaxAttributesForWord:(NSString *)w;

- (void)setCommentAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault;
- (void)setConstantAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault;
- (void)setExceptionAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault;
- (void)setFunctionAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault;
- (void)setKeywordAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault;
- (void)setNumberAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault;
- (void)setOsirixAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault;
- (void)setPlaintextAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault;
- (void)setStringAttributes:(NSDictionary *)attributes :(BOOL)registerAsDefault;

@end
