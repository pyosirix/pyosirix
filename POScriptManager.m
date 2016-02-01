//
//  POScriptManager.m
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

#import "POScriptManager.h"
#import "pyOsiriXFilter.h"
#import "POErrorCodes.h"
#import "POKeychain.h"

NSString * const POScriptManagerErrorDomain = @"com.InstituteOfCancerResearch.pyOsiriX.POScriptManagerErrorDomain";

@implementation POScriptManager

@synthesize managerReady, scriptHeaders;

#pragma mark Invisible utilities

+ (NSInteger)alertWithMessageText:(NSString *)message :(NSString *)firstButton :(NSString *)secondButton :(NSString *)thirdButton :(NSString *)informativeTextWithFormat, ...
{
	NSAlert *alert = [[NSAlert alloc] init];
	if (message)
		[alert setMessageText:message];
	if (firstButton)
		[alert addButtonWithTitle:firstButton];
	if (secondButton)
		[alert addButtonWithTitle:secondButton];
	if (thirdButton)
		[alert addButtonWithTitle:thirdButton];
	if (informativeTextWithFormat)
	{
		va_list args;
		va_start(args, informativeTextWithFormat);
		NSString *infText = [[NSString alloc] initWithFormat:informativeTextWithFormat arguments:args];
		[alert setInformativeText:infText];
		[infText release];
		va_end(args);
	}
	[alert setAlertStyle:NSWarningAlertStyle];
	
	NSInteger response = (NSInteger)[alert runModal];
	[alert release];
	return response;
}

+ (NSString *) pluginDirectory
{
    return [NSString stringWithFormat:@"%@/Library/Application Support/OsiriX/Plugins/Python", NSHomeDirectory()];
}

+ (NSString *)pathForScriptNamed: (NSString *)name
{
    return [NSString stringWithFormat:@"%@/%@.py", [POScriptManager pluginDirectory], name];
}

+ (NSURL *)urlForScriptNamed: (NSString *)name
{
    return [NSURL fileURLWithPath:[POScriptManager pathForScriptNamed:name]];
}

- (void) setHeaderError:(NSError **)error withReason:(NSString *)reason
{
    *error = [NSError errorWithDomain:POScriptManagerErrorDomain
                                 code:PYOSIRIXERR_SCRIPTINSTALL
                             userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Could not install script as plugin", nil), NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil]];
}

- (void) setInstallScriptError:(NSError **)error withReason:(NSString *)reason
{
    *error = [NSError errorWithDomain:POScriptManagerErrorDomain
                                 code:PYOSIRIXERR_SCRIPTINSTALL
                             userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Could not install script.", nil), NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil]];
}

- (void) ensureDirectory
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *pluginDir = [NSString stringWithFormat:@"%@/Library/Application Support/OsiriX/Plugins/Python", NSHomeDirectory()];
    
    BOOL isDir;
    if (![fm fileExistsAtPath:pluginDir isDirectory:&isDir] || !isDir) {
        NSError *error;
        BOOL dirPresent = [fm createDirectoryAtPath:pluginDir withIntermediateDirectories:YES attributes:nil error:&error];
        if (!dirPresent) {
            managerReady = NO;
            NSLog(@"Could not detect/create python script folder\r%@", error);
        }
    }
    managerReady = YES;
}

- (void)loadCurrentScriptHeaders
{
	if (scriptHeaders != nil) {
		[scriptHeaders release];
	}
    NSString *pluginDir = [POScriptManager pluginDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    NSArray *fileList = [fm contentsOfDirectoryAtPath:pluginDir error:&error];
    
    NSMutableArray *validFiles = [NSMutableArray array];
    for (NSString *file in fileList) {
        if ([[file pathExtension] isEqualToString:@"py"])
            [validFiles addObject:file];
    }
    if ([validFiles count] == 0) {
        scriptHeaders = nil;
        return;
    }
    
    NSMutableArray *headers = [NSMutableArray array];
    for (NSString *file in validFiles) {
        NSString *fullPath = [NSString stringWithFormat:@"%@/%@", pluginDir, file];
        NSDictionary *dict = [self readHeaderInfoForScriptFile:fullPath];
        if (dict != nil) {
            [headers addObject:dict];
        }
    }
    if ([headers count] > 0)
        scriptHeaders = [[NSArray arrayWithArray:headers] retain];
    else
        scriptHeaders = nil;
}

- (id)init
{
    self = [super init];
	if (!self) {
        return  nil;
    }
    [self ensureDirectory];
    scriptHeaders = nil;
    [self loadCurrentScriptHeaders];
    return self;
}

- (void)dealloc
{
    if (scriptHeaders)
        [scriptHeaders release];
    [super dealloc];
}

#pragma mark -
#pragma mark Tools to get access to installed scripts

- (NSArray *)scriptHeaders
{
	return [NSArray arrayWithArray:scriptHeaders];
}

- (BOOL)scriptPresentWithName:(NSString *)name
{
    return [self scriptPresentWithName:name :nil];
}

- (BOOL)scriptPresentWithName:(NSString *)name :(NSDictionary **)header
{
    for (NSDictionary *scriptHeader in scriptHeaders) {
        if ([[scriptHeader valueForKey:@"name"] isEqualToString:name]) {
            if (header != nil) {
                *header = scriptHeader;
            }
            return YES;
        }
    }
    return NO;
}

- (NSArray *) scriptNamesForType:(NSString *)type
{
    NSMutableArray *names = [NSMutableArray array];
    for (NSDictionary *header in scriptHeaders) {
        [header objectForKey:@"type"];
        if ([[header objectForKey:@"type"] isEqualToString:type]) {
            [names addObject:[header objectForKey:@"name"]];
        }
    }
    if ([names count] > 0) {
        [names sortUsingComparator:^NSComparisonResult(NSString *name1, NSString *name2){
            return [name1 compare:name2];
        }];
        return [NSArray arrayWithArray:names];
    }
    return nil;
}

- (NSString *)getScriptWithName:(NSString *)name
{
    if (![self scriptPresentWithName:name]) {
        return nil;
    }
    NSURL *url = [POScriptManager urlForScriptNamed:name];
    NSError *error;
    NSString *script = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    if (!script) {
        return nil;
    }
    return script;
}

#pragma mark -
#pragma mark Tools to read script headers

//These need to be fast, therefore read byte streams
//This should be used on files already installed by the system.  No error report given
//For checking headers of new scripts use the checkHeader method
- (NSDictionary *) readHeaderInfoForScriptName:(NSString *)name
{
    return [self readHeaderInfoForScriptFile:[NSString stringWithFormat:@"%@/%@.py", [POScriptManager pluginDirectory], name]];
}

- (NSDictionary *) readHeaderInfoForScriptURL:(NSURL *)url
{
    return [self readHeaderInfoForScriptFile:[url absoluteString]];
}

- (NSDictionary *) readHeaderInfoForScriptFile:(NSString *)file
{
    FILE *fl = fopen([file UTF8String], "r");
    
    //Check the header info still exists
    char headerInfoBuff[12];
    fread(headerInfoBuff, 1, 11, fl);
    headerInfoBuff[11] = '\0';
    if (![[NSString stringWithUTF8String:headerInfoBuff] isEqualToString:@"#HeaderInfo"]) {
        return nil;
    }
    
    //Read to end of line
    char garbage = ' ';
    while (garbage != '\n') {
        fread(&garbage, 1, 1, fl);
    }
    
    //Find the type
    char *typeBuff = malloc(7);
    fread(typeBuff, 1, 6, fl);
    typeBuff[6] = '\0';
    if (![[NSString stringWithUTF8String:typeBuff] isEqualToString:@"#type="]) {
        free(typeBuff);
        return nil;
    }
    free(typeBuff);
    
    typeBuff = malloc(100);
    int sz = 100;
    int idx = 0;
    while (true) {
        if (idx >= sz) {
            sz += 100;
            typeBuff = realloc(typeBuff, sz); //TODO Should add checks here that memory has not run out
        }
        char temp[1];
        fread(temp, 1, 1, fl);
        if (temp[0] == '\n')
            break;
        else
        {
            typeBuff[idx] = temp[0];
            idx++;
        }
    }
    char *type = malloc(idx + 1);
    memcpy(type, typeBuff, idx);
    type[idx] = '\0';
    free(typeBuff);
    
    //Find the name
    char *nameBuff = malloc(7);
    fread(nameBuff, 1, 6, fl);
    nameBuff[6] = '\0';
    if (![[NSString stringWithUTF8String:nameBuff] isEqualToString:@"#name="]) {
        free(nameBuff);
        return nil;
    }
    free(nameBuff);
    
    nameBuff = malloc(100);
    sz = 100;
    idx = 0;
    while (true) {
        if (idx >= sz) {
            sz += 100;
            nameBuff = realloc(nameBuff, sz); //TODO Should add checks here that memory has not run out
        }
        char temp[1];
        fread(temp, 1, 1, fl);
        if (temp[0] == '\n')
            break;
        else
        {
            nameBuff[idx] = temp[0];
            idx++;
        }
    }
    char *name = malloc(idx + 1);
    memcpy(name, nameBuff, idx);
    name[idx] = '\0';
    free(nameBuff);

    
    //Find the version
    char *versionBuff = malloc(10);
    fread(versionBuff, 1, 9, fl);
    versionBuff[9] = '\0';
    if (![[NSString stringWithUTF8String:versionBuff] isEqualToString:@"#version="]) {
        free(versionBuff);
        return nil;
    }
    free(versionBuff);
    
    versionBuff = malloc(100);
    sz = 100;
    idx = 0;
    while (true) {
        if (idx >= sz) {
            sz += 100;
            versionBuff = realloc(versionBuff, sz); //TODO Should add checks here that memory has not run out
        }
        char temp[1];
        fread(temp, 1, 1, fl);
        if (temp[0] == '\n')
            break;
        else
        {
            versionBuff[idx] = temp[0];
            idx++;
        }
    }
    char *version = malloc(idx + 1);
    memcpy(version, versionBuff, idx);
    version[idx] = '\0';
    free(versionBuff);
    
    //Find the author
    char *authorBuff = malloc(9);
    fread(authorBuff, 1, 8, fl);
    authorBuff[8] = '\0';
    if (![[NSString stringWithUTF8String:authorBuff] isEqualToString:@"#author="]) {
        free(authorBuff);
        return nil;
    }
    free(authorBuff);
    
    authorBuff = malloc(100);
    sz = 100;
    idx = 0;
    while (true) {
        if (idx >= sz) {
            sz += 100;
            authorBuff = realloc(authorBuff, sz); //TODO Should add checks here that memory has not run out
        }
        char temp[1];
        fread(temp, 1, 1, fl);
        if (temp[0] == '\n')
            break;
        else
        {
            authorBuff[idx] = temp[0];
            idx++;
        }
    }
    char *author = malloc(idx + 1);
    memcpy(author, authorBuff, idx);
    author[idx] = '\0';
    free(authorBuff);
    
    NSDictionary *headerInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:name], @"name",
            [NSString stringWithUTF8String:type], @"type", [NSString stringWithUTF8String:version], @"version", [NSString stringWithUTF8String:author], @"author", nil];
    
    free(name);
    free(type);
    free(version);
    free(author);
    
    return headerInfo;
}

#pragma mark -
#pragma mark Access to allowed script types

+ (NSArray *)allowedTypes //TODO - Should this be set up as an enumerated list?
{
    return [NSArray arrayWithObjects:
            @"ImageFilter",
            @"ROITool",
            @"DicomTool",
            nil];
}

+ (BOOL)typeAllowed:(NSString *)type
{
    for (NSString *aType in [POScriptManager allowedTypes]) {
        if ([aType isEqualToString:type])
            return YES;
    }
    return NO;
}

+ (NSString *)stringTemplateForType:(NSString *)type
{
    if (![POScriptManager typeAllowed:type]) {
        return nil;
    }
    NSString *template = [NSString stringWithFormat:@"#HeaderInfo\n#type=%@\n#name=NewScriptTemplate\n#version=0.0.1\n#author=%@\n#EndHeaderInfo", type, NSUserName()];
    if ([type isEqualToString:@"ImageFilter"]) {
        template = [NSString stringWithFormat:@"%@\n\n%@\n%@",
                    template,
                    @"viewerController = osirix.frontmostViewer()",
                    @"newViewer = viewerController.copyViewerWindow()"];
    }
    if ([type isEqualToString:@"ROITool"]) {
        template = [NSString stringWithFormat:@"%@\n\n%@\n%@",
                    template,
                    @"viewerController = osirix.frontmostViewer()",
                    @"selectedROIs = viewerController.selectedROIs()"];
    }
    if ([type isEqualToString:@"DicomTool"]) {
        template = [NSString stringWithFormat:@"%@\n\n%@\n%@\n%@\n%@\n%@",
                    template,
                    @"import dicom",
                    @"viewerController = osirix.frontmostViewer()",
                    @"pix = viewerController.curDCM()",
                    @"dcm = dicom.read_file(pix.sourceFile)",
                    @"osirix.runAlertPanel('Patient Name', information = dcm.PatientName, defaultButton = 'OK')"];
    }
    return template;
}

#pragma mark -
#pragma mark Tools to install python scripts

- (BOOL) checkHeader:(NSString *)script headerInfo:(NSDictionary **)dict error:(NSError **)error
{
    //First check there actually is  header block
    NSArray *lineArr = [script componentsSeparatedByString:@"\n"];
    if ([lineArr count] < 6) {
        [self setHeaderError:error withReason:NSLocalizedString(@"Not enough header info found", nil)];
        return NO;
    }
    
    if (![(NSString *)[lineArr objectAtIndex:0] isEqualToString:@"#HeaderInfo"]) {
        [self setHeaderError:error withReason:NSLocalizedString(@"First line does not contain string #HeaderInfo", nil)];
        return NO;
    }
    
    if (![(NSString *)[lineArr objectAtIndex:5] isEqualToString:@"#EndHeaderInfo"]) {
        [self setHeaderError:error withReason:NSLocalizedString(@"Sixth line does not contain string #EndHeaderInfo", nil)];
        return NO;
    }
    
    //Now check that the relevant info is given
    
    //Script type
    NSString *line = [lineArr objectAtIndex:1];
    NSArray *lineEls = [line componentsSeparatedByString:@"="];
    if ([lineEls count] < 2) {
        [self setHeaderError:error withReason:NSLocalizedString(@"No type defined", nil)];
        return NO;
    }
    NSString *infoType = [lineEls objectAtIndex:0];
    if (![infoType isEqualToString:@"#type"]) {
        [self setHeaderError:error withReason:NSLocalizedString(@"Second line does not contain string #type", nil)];
        return NO;
    }
    NSString *scriptType = [lineEls objectAtIndex:1];
    
    NSArray *allowedTypes = [POScriptManager allowedTypes];
    BOOL valid = NO;
    for (NSString *t in allowedTypes) {
        if ([scriptType isEqualToString:t])
            valid = YES;
    }
    if (!valid) {
        [self setHeaderError:error withReason:NSLocalizedString(@"Type is not valid", nil)];
        return NO;
    }
    
    //Script name
    line = [lineArr objectAtIndex:2];
    lineEls = [line componentsSeparatedByString:@"="];
    if ([lineEls count] < 2) {
        [self setHeaderError:error withReason:NSLocalizedString(@"No name defined", nil)];
        return NO;
    }
    infoType = [lineEls objectAtIndex:0];
    if (![infoType isEqualToString:@"#name"]) {
        [self setHeaderError:error withReason:NSLocalizedString(@"Third line does not contain string #name", nil)];
        return NO;
    }
    NSString *scriptName = [lineEls objectAtIndex:1];
    
    //Script version
    line = [lineArr objectAtIndex:3];
    lineEls = [line componentsSeparatedByString:@"="];
    if ([lineEls count] < 2) {
        [self setHeaderError:error withReason:NSLocalizedString(@"No version defined", nil)];
        return NO;
    }
    infoType = [lineEls objectAtIndex:0];
    if (![infoType isEqualToString:@"#version"]) {
        [self setHeaderError:error withReason:NSLocalizedString(@"Fourth line does not contain string #version", nil)];
        return NO;
    }
    NSString *scriptVersion = [lineEls objectAtIndex:1];
    
    //Script author
    line = [lineArr objectAtIndex:4];
    lineEls = [line componentsSeparatedByString:@"="];
    if ([lineEls count] < 2) {
        [self setHeaderError:error withReason:NSLocalizedString(@"No author defined", nil)];
        return NO;
    }
    infoType = [lineEls objectAtIndex:0];
    if (![infoType isEqualToString:@"#author"]) {
        [self setHeaderError:error withReason:NSLocalizedString(@"Fifth line does not contain string #author", nil)];
        return NO;
    }
    NSString *scriptAuthor = [lineEls objectAtIndex:1];
    
    *dict = [NSDictionary dictionaryWithObjectsAndKeys:scriptType, @"type", scriptName, @"name", scriptVersion, @"version", scriptAuthor, @"author", nil];
    
    return YES;
}

- (BOOL) removeScriptWithName:(NSString *)name
{
	NSString *path = [POScriptManager pathForScriptNamed:name];
	NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
		NSError *err;
		if (![fm removeItemAtPath:path error:&err]) {
			NSLog(@"POScriptManager: Could not remove script at path: %@\nError given:%@", path, err);
			return NO;
		}
		[self loadCurrentScriptHeaders];
		return YES;
	}
	return NO;
}

- (void) removeScriptsWithNames:(NSArray *)names
{
	BOOL successfullyRemoved = NO;
	for (NSString *name in names) {
		NSString *path = [POScriptManager pathForScriptNamed:name];
		NSFileManager *fm = [NSFileManager defaultManager];
		if ([fm fileExistsAtPath:path]) {
			NSError *err;
			if (![fm removeItemAtPath:path error:&err]) {
				NSLog(@"POScriptManager: Could not remove script at path: %@\nError given:%@", path, err);
			}
			else
				successfullyRemoved = YES;
		}
	}
	if (successfullyRemoved)
		[self loadCurrentScriptHeaders];
}

- (BOOL) installScriptFromURL:(NSURL *)url withError:(NSError **)error
{
    NSString *script = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:error];
    if (!script) {
        return NO;
    }
    return [self installScriptFromString:script withError:error];
}

- (BOOL) installScriptFromString:(NSString *)script withError:(NSError **)error
{
    if (!managerReady) {
        [self setInstallScriptError:error withReason:@"Manager not set up"];
        return NO;
    }
    
    NSString *pluginDir = [POScriptManager pluginDirectory];
    
    NSDictionary *headerInfo;
    BOOL OK = [self checkHeader:script headerInfo:&headerInfo error:error];
    if (!OK)
	{
		return NO;
	}
    
    NSString *scriptName = [headerInfo valueForKey:@"name"];
    NSString *scriptFile = [NSString stringWithFormat:@"%@/%@.py", pluginDir, scriptName];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:scriptFile]) {
        NSDictionary *prevHeaderInfo = [self readHeaderInfoForScriptFile:scriptFile];
        if (prevHeaderInfo) {
			NSInteger response = [POScriptManager alertWithMessageText:pluginName :@"OK" :@"Cancel" :nil :@"Do you wish to replace\r%@ v. %@\rwith\r%@ v. %@?",  [prevHeaderInfo objectForKey:@"name"], [prevHeaderInfo objectForKey:@"version"], [headerInfo objectForKey:@"name"], [headerInfo objectForKey:@"version"]];
			if (response == NSAlertSecondButtonReturn) {
				return YES;
			}
        }
    }
    
    OK = [script writeToFile:scriptFile atomically:YES encoding:NSUTF8StringEncoding error:error];
    if (!OK)
	{
        return NO;
	}
    
	[self loadCurrentScriptHeaders];
	
    return YES;
}

@end
