//
//  pyOsiriXFilter.m
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

#import <OsiriXAPI/browserController.h>

#import "pyOsiriXFilter.h"

static NSString * pythonToolbarItemIdentifier = @"pythonToolbarButton";

NSString *const pluginName = @"pyOsiriX";
BOOL pluginInitialised = NO;

//TODO - This is a bit of a hack for now but seems to work

BOOL runLoop;

PyDoc_STRVAR(startRuntimeLoop_doc,
			 "\n"
			 "When running installed python scripts, this stops the python environment from terminating\n"
			 "after the script file has been run.  This is required for scirpts that involve user feedback (e.g. matplotlib widgets).\n"
			 "Note: You MUST call stopRuntimeLoop() after this function has been called.\n"
			 "Not doing so will result in a hung python environment and you will need to use the\n"
			 "\"Clean Python Environment\" feature of the pyOsiriX plugin from the plugins menu.\n"
			 "This has no effect if the script is run from the Python file editor, but can be included for testing.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    None.\n"
			 "\n"
			 "Example:\n"
			 "    >>> startRuntimeLoop()\n"
			 "    ...    operations that require user feedback to terminate the python runtime\n"
			 "    >>> stopRuntimeLoop()\n"
			 );

PyObject * startRuntimeLoop()
{
    runLoop = YES;
    Py_INCREF(Py_None);
    return Py_None;
}

PyDoc_STRVAR(stopRuntimeLoop_doc,
			 "\n"
			 "This terminates the call to startRuntimeLoop() and allows the python environment\n"
			 "to clean itself so that it may be used again.\n"
			"This has no effect if the script is run from the Python file editor, but can be included for testing.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    None.\n"
			 "\n"
			 "Example:\n"
			 "    >>> startRuntimeLoop()\n"
			 "    ...    operations that require user feedback to terminate the python runtime\n"
			 "    >>> stopRuntimeLoop()\n"
			 );

PyObject * stopRuntimeLoop()
{
    if (runLoop){
        [pyRuntime endPythonEnvironment];
        runLoop = NO;
    }
    Py_INCREF(Py_None);
    return Py_None;
}

PyMethodDef startLoopDef = {"startRuntimeLoop", (PyCFunction)startRuntimeLoop, METH_NOARGS, startRuntimeLoop_doc};

PyMethodDef stopLoopDef = {"stopRuntimeLoop", (PyCFunction)stopRuntimeLoop, METH_NOARGS, stopRuntimeLoop_doc};

@implementation pyOsiriXFilter

- (void)dealloc
{
    [pyRuntime release];
    [scriptManager release];
    [super dealloc];
}

- (void)initPlugin
{
    //Called when OsiriX is started
    pyRuntime = [[PORuntime alloc] init];
    scriptManager = [[POScriptManager alloc] init]; //For now this does nothing
}

-(void)scriptEditorWindowWillClose:(NSNotification *)note
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:[scriptEditorController window]];
    [scriptEditorController release];
	[pyRuntime endPythonEnvironment];
    scriptEditorController = nil;
}

-(void) startPythonTerminal
{
    if (scriptEditorController) {
        //Put in front
        [[scriptEditorController window] makeKeyAndOrderFront:self];
        return;
    }
    
    if ([pyRuntime runtimeActive]) {
        NSRunAlertPanel(pluginName, @"Cannot run more than one python interpreter at a time", @"OK", nil, nil);
        return; //This check is very important
    }
    
    // Load and Run the window
    // Make sure we listen for when it closes!!
    scriptEditorController = [[POScriptEditorController alloc] initWithWindowNibName:POScriptEditorNIBName];
    
    PyObject *pyStartLoopFunc = PyCFunction_New(&startLoopDef, NULL);
    PyObject *pyStopLoopFunc = PyCFunction_New(&stopLoopDef, NULL);
    PyObject *globalNamespace = PyModule_GetDict(PyImport_AddModule("__main__"));
    PyDict_SetItem(globalNamespace, PyString_FromString("startRuntimeLoop"), pyStartLoopFunc);
    PyDict_SetItem(globalNamespace, PyString_FromString("stopRuntimeLoop"), pyStopLoopFunc);
    Py_DECREF(pyStopLoopFunc);
    Py_DECREF(pyStartLoopFunc);
    
    if (scriptEditorController) {
        NSRect scrSize = [[NSScreen mainScreen] frame];
        scrSize.origin.y += 0.4*scrSize.size.height;
        scrSize.size.height *= 0.6;
        scrSize.size.width *= 0.5;
        [[scriptEditorController window] setFrame:scrSize display:YES];
        [scriptEditorController showWindow:self];
        [[scriptEditorController window] makeKeyAndOrderFront:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scriptEditorWindowWillClose:) name: NSWindowWillCloseNotification object:[scriptEditorController window]];
    }
}

-(void)runScript:(id)sender
{
    if ([pyRuntime runtimeActive]) {
        NSRunAlertPanel(pluginName, @"Cannot run more than one python interpreter at a time", @"OK", nil, nil);
        return;
    }
    NSMenuItem *item = (NSMenuItem *)sender;
    NSString *name = [item title];
    NSString *script = [scriptManager getScriptWithName:name];
    if (script == nil) {
        NSRunAlertPanel(pluginName, @"Could not find the specified script, it may no longer exist. \rPlease restart OsiriX.", @"OK", nil, nil);
        return;
    }
    
    //Now need to run this script
    PyObject *log = [POErrorAlertLog newErrorAlertLog];
    NSError *err;
    BOOL ok = [pyRuntime startPythonEnvironmentWithStdOut:NULL andStdErr:log :&err];
    if (!ok) {
        Py_DECREF(log);
        NSLog(@"%@", err);
        return;
    }
    Py_DECREF(log);
    
    runLoop = NO;
    PyObject *pyStartLoopFunc = PyCFunction_New(&startLoopDef, NULL);
    PyObject *pyStopLoopFunc = PyCFunction_New(&stopLoopDef, NULL);
    PyObject *globalNamespace = PyModule_GetDict(PyImport_AddModule("__main__"));
    PyDict_SetItem(globalNamespace, PyString_FromString("startRuntimeLoop"), pyStartLoopFunc);
    PyDict_SetItem(globalNamespace, PyString_FromString("stopRuntimeLoop"), pyStopLoopFunc);
    Py_DECREF(pyStopLoopFunc);
    Py_DECREF(pyStartLoopFunc);
    
    [pyRuntime runSimpleScriptInCurrentEnvironment:script];
    if (!runLoop) {
        [pyRuntime endPythonEnvironment];
    }
}

-(NSToolbarItem *)toolbarItemForItemIdentifier: (NSString *)itemIdent forViewer:(ViewerController *)vc
{
    if ([itemIdent isEqualToString:pythonToolbarItemIdentifier]) {
        NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
        [toolbarItem setLabel: NSLocalizedString(@"pyOsiriX", nil)];
        [toolbarItem setPaletteLabel: NSLocalizedString(@"pyOsiriX", nil)];
        [toolbarItem setToolTip: NSLocalizedString(@"Run python scripting environment", nil)];
        
        [[NSBundle bundleForClass:[self class]] loadNibNamed:@"pyOsiriXMenuItem" owner:self topLevelObjects:nil];
        
        [popUp removeAllItems];
        NSMenu *menu = [[NSMenu alloc] init];
        
        NSMenuItem *item0 = [[[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""] autorelease];
        [menu addItem:item0];
        
        NSMenuItem *startTermItem = [[[NSMenuItem alloc] initWithTitle:@"Start python terminal" action:@selector(startPythonTerminal) keyEquivalent:@""] autorelease];
        [menu addItem:startTermItem];
        [startTermItem setTarget:self];
        
        NSMenuItem *sep = [NSMenuItem separatorItem];
        [menu addItem:sep];
        
        NSArray *scriptHeaders = [scriptManager scriptHeaders];
        if (scriptHeaders != nil) {
            for (NSString *allowedType in [POScriptManager allowedTypes]) {
                NSMutableArray *names = [NSMutableArray array];
                for (NSDictionary *header in scriptHeaders) {
                    NSString *type = [header objectForKey:@"type"];
                    if ([type isEqualToString:allowedType]) {
                        [names addObject:[header objectForKey:@"name"]];
                    }
                }
                if ([names count] > 0) {
                    [names sortUsingComparator:^NSComparisonResult(NSString *name1, NSString *name2){
                        return [name1 compare:name2];
                    }];
                    NSMenuItem *scriptTypeItem = [[[NSMenuItem alloc] initWithTitle:allowedType action:nil keyEquivalent:@""] autorelease];
                    [menu addItem:scriptTypeItem];
                    NSMenu *scriptTypeMenu = [[[NSMenu alloc] init] autorelease];
                    [scriptTypeItem setSubmenu:scriptTypeMenu];
                    for (NSString *name in names) {
                        NSMenuItem *scriptItem = [[[NSMenuItem alloc] initWithTitle:name action:@selector(runScript:) keyEquivalent:@""] autorelease];
                        [scriptTypeMenu addItem:scriptItem];
                        [scriptItem setTarget:self];
                    }
                }
            }
        }
        
        [popUp setMenu:menu];
        [menu release];
        
        [toolbarItem setView: pythonButton];
        [toolbarItem setMinSize:NSMakeSize(NSWidth([pythonButton frame]), NSHeight([pythonButton frame]))];
        [toolbarItem setMaxSize:NSMakeSize(NSWidth([pythonButton frame]), NSHeight([pythonButton frame]))];
        return toolbarItem;
    }
    return 0;
}

-(NSArray *)toolbarAllowedIdentifiersForViewer:(ViewerController *)vc
{
    return [NSArray arrayWithObject:pythonToolbarItemIdentifier];
}

-(NSToolbarItem *)toolbarItemForItemIdentifier: (NSString *)itemIdent forBrowserController: (BrowserController *)bc
{
    if ([itemIdent isEqualToString:pythonToolbarItemIdentifier]) {
        NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
        [toolbarItem setLabel: NSLocalizedString(@"pyOsiriX", nil)];
        [toolbarItem setPaletteLabel: NSLocalizedString(@"pyOsiriX", nil)];
        [toolbarItem setToolTip: NSLocalizedString(@"Run python scripting environment", nil)];
        
        [[NSBundle bundleForClass:[self class]] loadNibNamed:@"pyOsiriXMenuItem" owner:self topLevelObjects:nil];
        
        [popUp removeAllItems];
        NSMenu *menu = [[NSMenu alloc] init];
        
        NSMenuItem *item0 = [[[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""] autorelease];
        [menu addItem:item0];
        
        NSMenuItem *startTermItem = [[[NSMenuItem alloc] initWithTitle:@"Start python terminal" action:@selector(startPythonTerminal) keyEquivalent:@""] autorelease];
        [menu addItem:startTermItem];
        [startTermItem setTarget:self];
        
        NSMenuItem *sep = [NSMenuItem separatorItem];
        [menu addItem:sep];
        
        NSArray *scriptHeaders = [scriptManager scriptHeaders];
        if (scriptHeaders != nil) {
            for (NSString *allowedType in [POScriptManager allowedTypes]) {
                NSMutableArray *names = [NSMutableArray array];
                for (NSDictionary *header in scriptHeaders) {
                    NSString *type = [header objectForKey:@"type"];
                    if ([type isEqualToString:allowedType]) {
                        [names addObject:[header objectForKey:@"name"]];
                    }
                }
                if ([names count] > 0) {
                    [names sortUsingComparator:^NSComparisonResult(NSString *name1, NSString *name2){
                        return [name1 compare:name2];
                    }];
                    NSMenuItem *scriptTypeItem = [[[NSMenuItem alloc] initWithTitle:allowedType action:nil keyEquivalent:@""] autorelease];
                    [menu addItem:scriptTypeItem];
                    NSMenu *scriptTypeMenu = [[[NSMenu alloc] init] autorelease];
                    [scriptTypeItem setSubmenu:scriptTypeMenu];
                    for (NSString *name in names) {
                        NSMenuItem *scriptItem = [[[NSMenuItem alloc] initWithTitle:name action:@selector(runScript:) keyEquivalent:@""] autorelease];
                        [scriptTypeMenu addItem:scriptItem];
                        [scriptItem setTarget:self];
                    }
                }
            }
        }
        
        [popUp setMenu:menu];
        [menu release];
        
        [toolbarItem setView: pythonButton];
        [toolbarItem setMinSize:NSMakeSize(NSWidth([pythonButton frame]), NSHeight([pythonButton frame]))];
        [toolbarItem setMaxSize:NSMakeSize(NSWidth([pythonButton frame]), NSHeight([pythonButton frame]))];
        return toolbarItem;
    }
    return 0;
}

-(NSArray *)toolbarAllowedIdentifiersForBrowserController:(BrowserController *)bc
{
	return [NSArray arrayWithObject:pythonToolbarItemIdentifier];
}

-(NSToolbarItem *)toolbarItemForItemIdentifier: (NSString *)itemIdent forVRViewer:(VRController *)vrc
{
    if ([itemIdent isEqualToString:pythonToolbarItemIdentifier]) {
        NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
        [toolbarItem setLabel: NSLocalizedString(@"pyOsiriX", nil)];
        [toolbarItem setPaletteLabel: NSLocalizedString(@"pyOsiriX", nil)];
        [toolbarItem setToolTip: NSLocalizedString(@"Run python scripting environment", nil)];
        
        [[NSBundle bundleForClass:[self class]] loadNibNamed:@"pyOsiriXMenuItem" owner:self topLevelObjects:nil];
        
        [popUp removeAllItems];
        NSMenu *menu = [[NSMenu alloc] init];
        
        NSMenuItem *item0 = [[[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""] autorelease];
        [menu addItem:item0];
        
        NSMenuItem *startTermItem = [[[NSMenuItem alloc] initWithTitle:@"Start python terminal" action:@selector(startPythonTerminal) keyEquivalent:@""] autorelease];
        [menu addItem:startTermItem];
        [startTermItem setTarget:self];
        
        NSMenuItem *sep = [NSMenuItem separatorItem];
        [menu addItem:sep];
        
        NSArray *scriptHeaders = [scriptManager scriptHeaders];
        if (scriptHeaders != nil) {
            for (NSString *allowedType in [POScriptManager allowedTypes]) {
                NSMutableArray *names = [NSMutableArray array];
                for (NSDictionary *header in scriptHeaders) {
                    NSString *type = [header objectForKey:@"type"];
                    if ([type isEqualToString:allowedType]) {
                        [names addObject:[header objectForKey:@"name"]];
                    }
                }
                if ([names count] > 0) {
                    [names sortUsingComparator:^NSComparisonResult(NSString *name1, NSString *name2){
                        return [name1 compare:name2];
                    }];
                    NSMenuItem *scriptTypeItem = [[[NSMenuItem alloc] initWithTitle:allowedType action:nil keyEquivalent:@""] autorelease];
                    [menu addItem:scriptTypeItem];
                    NSMenu *scriptTypeMenu = [[[NSMenu alloc] init] autorelease];
                    [scriptTypeItem setSubmenu:scriptTypeMenu];
                    for (NSString *name in names) {
                        NSMenuItem *scriptItem = [[[NSMenuItem alloc] initWithTitle:name action:@selector(runScript:) keyEquivalent:@""] autorelease];
                        [scriptTypeMenu addItem:scriptItem];
                        [scriptItem setTarget:self];
                    }
                }
            }
        }
        
        [popUp setMenu:menu];
        [menu release];
        
        [toolbarItem setView: pythonButton];
        [toolbarItem setMinSize:NSMakeSize(NSWidth([pythonButton frame]), NSHeight([pythonButton frame]))];
        [toolbarItem setMaxSize:NSMakeSize(NSWidth([pythonButton frame]), NSHeight([pythonButton frame]))];
        return toolbarItem;
    }
    return 0;
}

-(NSArray *)toolbarAllowedIdentifiersForVRViewer:(VRController *)vrc
{
    return [NSArray arrayWithObject:pythonToolbarItemIdentifier];
}

- (void)packageWindowWillClose:(NSNotification *)note
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:[packageController window]];
    [packageController release];
    packageController = nil;
}

- (void)scriptWindowWillClose:(NSNotification *)note
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:[scriptWindowController window]];
    [scriptWindowController release];
    scriptWindowController = nil;
}

- (void)runPackageManager
{
    if (packageController) {
        [[packageController window] makeKeyAndOrderFront:nil];
        return;
    }
    packageController = [[POPackageWindowController alloc] initWithWindowNibName:@"POPackageWindow"];
    [packageController showWindow:self];
    [[packageController window] makeKeyAndOrderFront:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(packageWindowWillClose:) name: NSWindowWillCloseNotification object:[packageController window]];
}

- (void)runScriptManager
{
	if (scriptWindowController) {
        [[scriptWindowController window] makeKeyAndOrderFront:nil];
        return;
    }
    scriptWindowController = [[POScriptWindowController alloc] initWithWindowNibName:@"POScriptWindow"];
    [scriptWindowController showWindow:self];
    [[scriptWindowController window] makeKeyAndOrderFront:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scriptWindowWillClose:) name: NSWindowWillCloseNotification object:[scriptWindowController window]];
}

- (long) filterImage:(NSString*) menuName
{
    if ([menuName isEqualToString:@"Start Terminal"]) {
        [self startPythonTerminal];
    }
	else if ([menuName isEqualToString:@"Script Manager"])
	{
		[self runScriptManager];
	}
    else if ([menuName isEqualToString:@"Package Manager"]){
        [self runPackageManager];
    }
	else{
		if ([pyRuntime runtimeActive]) {
			[pyRuntime endPythonEnvironment];
			runLoop = NO;
		}
	}
    return 0;
}

@end