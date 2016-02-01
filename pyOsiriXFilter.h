//
//  pyOsiriXFilter.h
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

#include <Python/Python.h>
#import <Foundation/Foundation.h>
#import <OsiriXAPI/PluginFilter.h>

#import <OsiriXAPI/BrowserController.h>

#import "PORuntime.h"
#import "POScriptEditorController.h"
#import "POScriptManager.h"
#import "POPackageWindowController.h"
#import "POScriptWindowController.h"
#import "POErrorAlertLog.h"

extern NSString* const pluginName;

@interface pyOsiriXFilter : PluginFilter {
    IBOutlet NSView *pythonButton;
    IBOutlet NSPopUpButton *popUp;
    POScriptEditorController *scriptEditorController;
    POPackageWindowController *packageController;
	POScriptWindowController *scriptWindowController;
}

-(NSToolbarItem *)toolbarItemForItemIdentifier: (NSString *)itemIdent forViewer:(ViewerController *)vc;
-(NSArray *)toolbarAllowedIdentifiersForViewer:(ViewerController *)vc;

-(NSToolbarItem *)toolbarItemForItemIdentifier: (NSString *)itemIdent forBrowserController:(BrowserController *)bc;
-(NSArray *)toolbarAllowedIdentifiersForBrowserController:(BrowserController *)bc;

-(NSToolbarItem *)toolbarItemForItemIdentifier: (NSString *)itemIdent forVRViewer:(VRController *)vrc;
-(NSArray *)toolbarAllowedIdentifiersForVRViewer:(VRController *)vrc;

-(long)filterImage:(NSString*) menuName;

-(void) startPythonTerminal;
-(void) runScript:(id)sender;

@end
