//
//  POScriptEditorController.m
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

#import "POScriptEditorController.h"
#import "pyOsiriXFilter.h"
#import "PORulerView.h"
#import <OsiriXAPI/Notifications.h>

#define FILE_SAVE_CONTEXT @"file_save_context"

NSString *POScriptEditorNIBName = @"POScriptEditorWindow";

@implementation POScriptEditorController

@synthesize currFilePath;

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

+ (NSString *)chooseSaveFilePath
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setCanCreateDirectories:YES];
    [savePanel setTitle:pluginName];
    [savePanel setMessage:@"Please choose a file to save to"];
    [savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"py"]];
    
    if ( [savePanel runModal] == NSOKButton )
    {
        return [[savePanel URL] absoluteString];
    }
    else
        return nil;
}

+ (NSString *)chooseOpenFilePath
{
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:YES];
    [openDlg setCanChooseDirectories:NO];
    [openDlg setPrompt:@"Select"];
    [openDlg setTitle:pluginName];
    [openDlg setMessage:@"Please select .py file"];
    [openDlg setAllowedFileTypes:[NSArray arrayWithObject:@"py"]];
    
    if ( [openDlg runModal] == NSOKButton )
    {
        NSArray* files = [openDlg URLs];
        if ([files count] != 1)
			[POScriptEditorController alertWithMessageText:pluginName :@"OK" :nil :nil :@"Cannot load more than one .py file!\nLoading file named: %@" ];
        return [[files objectAtIndex:0] absoluteString];
    }
    else
        return nil;
}

- (void)updateWindowTitle
{
	if ([self window] && currFilePath) {
		NSArray *subStr = [currFilePath componentsSeparatedByString:@"/"];
		[[self window] setTitle:[subStr objectAtIndex:[subStr count]-1]];
	}
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
		contextInfo:(void *)contextInfo
{
	if (contextInfo == FILE_SAVE_CONTEXT) {
		if (returnCode == NSAlertFirstButtonReturn) {
			[self saveCurrentText:self];
			[[self window] close];
		}
		if (returnCode == NSAlertSecondButtonReturn) {
			[[self window] close];
		}
	}
	
}

- (void)windowWillClose:(NSNotification *)notification
{
	if (textFinder)
		[textFinder release];
	[pyRuntime endPythonEnvironment];
}

- (BOOL)windowShouldClose:(id)sender
{
	if ([[self window] isDocumentEdited]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"Save"];
		[alert addButtonWithTitle:@"Don't Save"];
		[alert addButtonWithTitle:@"Cancel"];
		[alert setMessageText:@"You have unsaved changes.  Do you wish to save them?"];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:FILE_SAVE_CONTEXT];
		return NO;
	}
	return YES;
}

- (void)viewDidChangeText:(NSNotification *)note
{
	[[self window] setDocumentEdited:YES];
}

- (void)osirixWillClose:(NSNotification *)note
{
	if([[self window] isDocumentEdited])
	{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"Save"];
		[alert addButtonWithTitle:@"Don't Save"];
		[alert setMessageText:@"You have unsaved changes.  Do you wish to save them?"];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		if ([alert runModal] == NSAlertFirstButtonReturn) {
			[self saveCurrentText:self];
		}
	}
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	
	PyObject *log = [pyLog pythonObjectWithInstance:pythonLogView];
    NSError *err;
    BOOL ok = [pyRuntime startPythonEnvironmentWithStdOut:log andStdErr:log :&err];
	Py_DECREF(log);
    if (!ok) {
        NSLog(@"Could not load viewer. Reason: %@", err);
        [self close];
        return;
    }
    
	NSScrollView *sV = [pythonInput enclosingScrollView];
	textFinder = [[NSTextFinder alloc] init];
	[textFinder setClient:pythonInput];
	[textFinder setFindBarContainer:sV];
	[pythonInput setUsesFindBar:YES];
	[pythonInput setIncrementalSearchingEnabled:YES];
	[sV setFindBarPosition:NSScrollViewFindBarPositionBelowContent];
	
	[pythonLogView setEditable:FALSE];
    [pythonLogView setRichText: NO];
    [pythonInput setRichText: NO];
    [pythonInput setAutomaticQuoteSubstitutionEnabled:NO];
    [pythonInput setAutomaticSpellingCorrectionEnabled:NO];
    [pythonInput setAutomaticTextReplacementEnabled:NO];
    [pythonInput setAutomaticLinkDetectionEnabled:NO];
    [pythonLogView setFont: [NSFont fontWithName: @"Monaco" size: 12]];
    [pythonInput setFont: [NSFont fontWithName: @"Monaco" size: 12]];
	
	PORulerView *rv = [[PORulerView alloc] initWithScrollView:sV orientation:NSVerticalRuler textView:pythonInput];
	[sV setVerticalRulerView:rv];
	[sV setRulersVisible:TRUE];
	
	POPythonSyntaxModel *syntaxModel = [[POPythonSyntaxModel alloc] init];
	[pythonInput setSyntaxModel:syntaxModel];
	[syntaxModel release];
	
	NSNotificationCenter *dc = [NSNotificationCenter defaultCenter];
	[dc addObserver:self selector:@selector(osirixWillClose:) name:NSApplicationWillTerminateNotification object:nil];
	[dc addObserver:self selector:@selector(viewDidChangeText:) name:NSTextDidChangeNotification object:pythonInput];
	
	[[self window] makeFirstResponder:pythonInput];
	
}

- (IBAction)saveCurrentText:(id)sender
{
	if (currFilePath) {
		NSError *outputErr;
		BOOL saveOK = [[pythonInput string] writeToURL:[NSURL URLWithString:currFilePath] atomically:YES encoding:NSUTF8StringEncoding error:&outputErr];
		if (!saveOK) {
			[POScriptEditorController alertWithMessageText:pluginName :@"OK" :nil :nil :@"Could not save file: %@",  [outputErr description]];
			return;
		}
		[[self window] setDocumentEdited:NO];
	}
	else
		[self saveCurrentTextAs:sender];
}

- (IBAction)saveCurrentTextAs:(id)sender
{
	NSString *newFilePath = [POScriptEditorController chooseSaveFilePath];
	if (!newFilePath)
		return;
	
	[self setCurrFilePath:newFilePath];
	
	NSError *outputErr;
    BOOL saveOK = [[pythonInput string] writeToURL:[NSURL URLWithString:currFilePath] atomically:YES encoding:NSUTF8StringEncoding error:&outputErr];
    if (!saveOK) {
		[POScriptEditorController alertWithMessageText:pluginName :@"OK" :nil :nil :@"Could not save file: %@",  [outputErr description]];
        return;
    }
	[self updateWindowTitle];
	[[self window] setDocumentEdited:NO];
}

- (IBAction)openFile:(id)sender
{
	if (![[pythonInput string] isEqualToString:@""]) {
		NSInteger response = [POScriptEditorController alertWithMessageText:pluginName :@"OK" :@"Cancel" :nil :@"Text is already loaded.  Are you sure you want to remove?"];
        if (response == NSAlertSecondButtonReturn) {
            return;
        }
    }
    
    NSString *file = [POScriptEditorController chooseOpenFilePath];
	
	if (file) {
		NSError *inputErr;
		NSString *fileContents = [NSString stringWithContentsOfURL:[NSURL URLWithString:file] encoding:NSUTF8StringEncoding error:&inputErr];
		if (!fileContents) {
			[POScriptEditorController alertWithMessageText:pluginName :@"OK" :nil :nil :@"Could not load file: %@",  [inputErr description]];
			return;
		}
		
		[pythonInput setString:fileContents];
		[self setCurrFilePath:file];
		[self updateWindowTitle];
	}
}

- (IBAction)commentSelection:(id)sender
{
	[pythonInput commentSelectedRange];
}

- (IBAction)uncommentSelection:(id)sender
{
	[pythonInput uncommentSelectedRange];
}


- (IBAction)indentSelection:(id)sender
{
	[pythonInput indentSelectedRange];
}

- (IBAction)undentSelection:(id)sender
{
	[pythonInput undentSelectedRange];
}

- (IBAction)runPython:(id)sender
{
	//Clear the original log
    [pythonLogView setString:@""];
    
    //Get the input command
    NSString *script = [pythonInput string];
	
    //Run the command
    [pyRuntime runSimpleScriptInCurrentEnvironment:script]; //No return value as python will deal with errors at this point.
}

- (IBAction)displayInfo:(id)sender
{
	[POScriptEditorController alertWithMessageText:pluginName :@"OK" :nil :nil :@"This plugin is not FDA approved nor CE marked.\nPlease use with caution!\nFor more info run 'help(osirix)' in the pyOsiriX terminal or see our website:\nhttps://sites.google.com/site/pyosirix/"];
}

- (IBAction)installScript:(id)sender
{
	NSString *script = [pythonInput string];
    NSError *err;
    BOOL ok = [scriptManager installScriptFromString:script withError:&err];
    if (!ok) {
		[POScriptEditorController alertWithMessageText:pluginName :@"OK" :nil :nil :@"%@\r%@", [[err userInfo] valueForKey:NSLocalizedDescriptionKey], [[err userInfo] valueForKey:NSLocalizedFailureReasonErrorKey]];
        return;
    }
	else {
    NSDictionary *dict;
    [scriptManager checkHeader:script headerInfo:&dict error:&err];
	[POScriptEditorController alertWithMessageText:pluginName :@"OK" :nil :nil :@"Script %@ scuccessfully installed.\rPlease restart OsiriX to use.", [dict valueForKey:@"name"]];
	}
}

- (IBAction)addTemplate:(id)sender
{
	if (![[pythonInput string] isEqualToString:@""]) {
        NSInteger response = [POScriptEditorController alertWithMessageText:pluginName :@"OK" :@"Cancel" :nil :@"Text is already loaded.  Are you sure you want to remove?"];
        if (response == NSAlertSecondButtonReturn) {
            return;
        }
    }
    
    NSMenuItem *item = (NSMenuItem *)sender;
    NSString *type = [item title];
    [pythonInput setString:[POScriptManager stringTemplateForType:type]];
}

- (IBAction)findText:(id)sender
{
	[textFinder performAction:NSTextFinderActionShowFindInterface];
}

- (void)goToLine:(NSNotification *)note
{
	int lineNo = [lController lineNumber];
	if (lineNo > [pythonInput numberOfLines]) {
		NSBeep();
		return;
	}
	[pythonInput selectAndDisplayLine:lineNo];
}

- (void)goToLineControllerWillClose:(NSNotification *)note
{
	if (lController) {
		[lController release];
		lController = nil;
	}
}

- (IBAction)goToLineRequest:(id)sender
{
	if (lController) {
		[[lController window] makeKeyAndOrderFront:self];
		return;
	}
	lController = [[POGoToLineController alloc] init];
	[lController showWindow:self];
	NSNotificationCenter *dCenter = [NSNotificationCenter defaultCenter];
	[dCenter addObserver:self selector:@selector(goToLine:) name:POGoToLineNotification object:lController];
	[dCenter addObserver:self selector:@selector(goToLineControllerWillClose:) name:NSWindowWillCloseNotification object:[lController window]];
}

@end
