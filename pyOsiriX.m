//
//  pyOsiriX.m
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

#import "pyOsiriX.h"
#import "pyBrowserController.h"
#import "pyViewerController.h"
#import "pyVRController.h"
#import "pyLog.h"
#import "pyWait.h"
#import "pyDCMPix.h"
#import "pyROI.h"
#import "pyDicomImage.h"
#import "pyDicomSeries.h"
#import "pyDicomStudy.h"
#import "pyOsiriXType.h"

#import <OsiriXAPI/BrowserController.h>
#import <OsiriXAPI/ViewerController.h>
#import <OsiriXAPI/VRController.h>

PyObject *pyOsiriX_currentBrowser(PyObject *self, PyObject *args)
{
    BrowserController *currBC = [BrowserController currentBrowser];
    return [pyBrowserController pythonObjectWithInstance:currBC];
}

PyObject *pyOsiriX_frontmostDisplayed2DViewer(PyObject *self, PyObject *args)
{
    ViewerController *currV = [ViewerController frontMostDisplayed2DViewer];
	PyObject *oV;
	if (currV) {
		oV = [pyViewerController pythonObjectWithInstance:currV];
	}
	else {
		Py_INCREF(Py_None);
		oV = Py_None;
	}
    return oV;
}

PyObject *pyOsiriX_getDisplayed2DViewers(PyObject *self, PyObject *args)
{
    NSMutableArray *vs = [ViewerController getDisplayed2DViewers];
    PyObject *tuple = PyTuple_New([vs count]);
    for (int i = 0; i < [vs count]; i++) {
        PyTuple_SetItem(tuple, i, [pyViewerController pythonObjectWithInstance:[vs objectAtIndex:i]]);
    }
    return tuple;
}

PyObject *pyOsiriX_frontmostVRController(PyObject *self, PyObject *args)
{
    for( NSWindow *win in [NSApp orderedWindows])
    {
        NSWindowController *wc = [win windowController];
        if( [wc isKindOfClass:[VRController class]])
            return [pyVRController pythonObjectWithInstance:(VRController *)wc];
    }
    
    Py_INCREF(Py_None);
    return Py_None;
}

PyObject *pyOsiriX_getDisplayedVRControllers(PyObject *self, PyObject *args)
{
    NSMutableArray *wcs = [NSMutableArray array];
    for( NSWindow *win in [NSApp orderedWindows])
    {
        NSWindowController *wc = [win windowController];
        if( [wc isKindOfClass:[VRController class]])
            [wcs addObject:wc];
    }
    if ([wcs count] == 0) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    PyObject *tuple = PyTuple_New([wcs count]);
    for (int i = 0; i < [wcs count]; i++) {
        PyTuple_SetItem(tuple, i, [pyVRController pythonObjectWithInstance:[wcs objectAtIndex:i]]);
    }
    return tuple;
}

PyObject *pyOsiriX_runAlertPanel(PyObject *self, PyObject *args, PyObject *kwds)
{
    static char *kwlist[] = {"message", "informativeText", "firstButton", "secondButton", "thirdButton", NULL};
        
    char * message;
    char * information = NULL;
    char * firstButton = "OK";
    char * secondButton = NULL;
    char * thirdButton =  NULL;
    
    if (!PyArg_ParseTupleAndKeywords(args, kwds, "s|sssss", kwlist, &message, &information, &firstButton, &secondButton, &thirdButton))
    {
            return NULL;
    }
    
    NSAlert *sheet = [[NSAlert alloc] init];
    [sheet setMessageText:[NSString stringWithUTF8String:message]];
    [sheet addButtonWithTitle:[NSString stringWithUTF8String:firstButton]];
    if (information != NULL)
        [sheet setInformativeText:[NSString stringWithUTF8String:information]];
    if (secondButton != NULL)
        [sheet addButtonWithTitle:[NSString stringWithUTF8String:secondButton]];
    if (thirdButton != NULL)
        [sheet addButtonWithTitle:[NSString stringWithUTF8String:thirdButton]];

    NSModalResponse res = [sheet runModal];
    
    char **strPtr;
    switch (res) {
        case NSAlertFirstButtonReturn:
            strPtr = &firstButton;
            break;
        case NSAlertSecondButtonReturn:
            strPtr = &secondButton;
            break;
        case NSAlertThirdButtonReturn:
            strPtr = &thirdButton;
            break;
        default:
            strPtr = &firstButton;
            break;
    }
    
    PyObject *buttonPressed = PyString_FromString(*strPtr);
    [sheet release];
    return buttonPressed;
}

PyObject *pyOsiriX_selectPath(PyObject *self, PyObject *args, PyObject *kwds)
{
    static char *kwlist[] = {"dirs", "extension", "title", NULL};
	
    int dirs = 0;
    char *ext = NULL;
	char *title = "pyOsiriX: Please select a path";
    
    if (!PyArg_ParseTupleAndKeywords(args, kwds, "|iss", kwlist, &dirs, &ext, &title))
    {
		return NULL;
    }
	
	NSOpenPanel *oPanel = [[NSOpenPanel alloc] init];
	[oPanel setCanChooseDirectories:(dirs > 0)];
	[oPanel setCanChooseFiles:TRUE];
	[oPanel setCanHide:FALSE];
	[oPanel setTitle:[NSString stringWithUTF8String:title]];
	[oPanel setPrompt:@"Select"];
	if (ext != NULL)
		[oPanel setAllowedFileTypes:[NSArray arrayWithObjects:[NSString stringWithUTF8String:ext], nil]];
	
	NSUInteger ret = [oPanel runModal];
	
	NSURL *url = nil;
	switch (ret) {
		case NSFileHandlingPanelOKButton:
			url = [oPanel URL];
			break;
			
		default:
			break;
	}
	
	PyObject *path;
	if (url != nil) {
		path = PyString_FromString([[url path] UTF8String]);
	}
	else {
		Py_INCREF(Py_None);
		path = Py_None;
	}
	
	[oPanel release];
	return path;
}

PyDoc_STRVAR(currentBrowser_doc,
			 "\n"
			 "Provides access to the OsiriX dicom browser.\n"
			 "\n"
			 "Args:\n"
			 "   None.\n"
			 "\n"
			 "Returns:\n"
			 "    BrowserController: The OsiriX dicom browser instance.\n"
			 "\n"
			 "Example:\n"
			 "    >>> bc = osirix.currentBrowser()");

PyDoc_STRVAR(frontmostViewer_doc,
			 "\n"
			 "Provides access to the currently selected 2D dicom viewer.\n"
			 "\n"
			 "Args:\n"
			 "   None.\n"
			 "\n"
			 "Returns:\n"
			 "    ViewerController: The currently active 2D viewer instance.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vc = osirix.frontmostViewer()");

PyDoc_STRVAR(getDisplayed2DViewers_doc,
			 "\n"
			 "Provides a tuple with each element providing a reference to an open 2D viewer.\n"
			 "\n"
			 "Args:\n"
			 "   None.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: A tuple with each element containing a ViewerController instance.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vcs = osirix.getDisplayed2DViewers()");

PyDoc_STRVAR(frontmostVRController_doc,
			 "\n"
			 "Provides access to the currently selected 3D volume render controller.\n"
			 "\n"
			 "Args:\n"
			 "   None.\n"
			 "\n"
			 "Returns:\n"
			 "    VRController: The currently active 3D volume controller instance.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vrc = osirix.frontmostVRController()");

PyDoc_STRVAR(getDisplayedVRControllers_doc,
			 "\n"
			 "Provides a tuple with each element providing a reference to an open 3D viewer.\n"
			 "\n"
			 "Args:\n"
			 "   None.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: A tuple with each element containing a VRController instance.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vrcs = osirix.getDisplayedVRControllers()");

PyDoc_STRVAR(runAlertPanel_doc,
			 "\n"
			 "Run a modal alert panel and obtain user feedback via up to three customisable buttons.\n"
			 "A message and corresponding information can also be displayed and provided to the user.\n"
			 "\n"
			 "Args:\n"
			 "   message(str): The message to provide to the user.\n"
			 "   informativeText(Optional[str]): Additional information for the user.\n"
			 "   firstButton(Optional[str]): The text to display in the first (default) option.\n"
			 "	                             Defaults to \"OK\".\n"
			 "   secondButton(Optional[str]): The text to display in the second option.\n"
			 "	                              Defaults to None.\n"
			 "   thirdButton(Optional[str]): The text to display in the third option.\n"
			 "	                             Defaults to None.\n"
			 "\n"
			 "Returns:\n"
			 "    str: The text displayed by the button that the user selects.\n"
			 "\n"
			 "Example:\n"
			 "    >>> firstButtonStr = \"OK\"\n"
			 "    >>> secondButtonStr = \"Cancel\"\n"
			 "    >>> pressedButtonStr = osirix.runAlertPanel(\"Should I do Something?\",\n"
			 "                           firstButton = firstButtonStr, secondButton = secondButtonStr)\n"
			 "    >>> if pressedButtonStr == firstButtonStr:\n"
			 "    ...     doSomething(...)\n"
			 );

PyDoc_STRVAR(selectPath_doc,
			 "\n"
			 "Run a modal window prompting the user to select a file/directory path.\n"
			 "It is possible to allow selection all file types or a single file type.\n"
			 "It is also possible to define whether directories can be returned.\n"
			 "\n"
			 "Args:\n"
			 "   dirs(Optional[bool]): Are directory path allowed?\n"
			 "   extension(Optional[str]): The extension of allowed file types. Ignore for all file types \n"
			 "   title(Optional[str]): Set the displayed title of the path selection window.\n"
			 "\n"
			 "Returns:\n"
			 "    str: The selected path.  Set to None if user cancels selction.\n"
			 "\n"
			 "Example:\n"
			 "    >>> #Prints the contents of a python file.\n"
			 "    >>> import io"
			 "    >>> path = osirix.selectPath(dirs = False, extension = \"py\")\n"
			 "    >>> if path:\n"
			 "    ...     fl = open(path, 'r')\n"
			 "    ...     print fl.read()\n"
			 "    ...     fl.close()\n"
			 );



static PyMethodDef osirixModuleMethods[] =
{
    {"currentBrowser", pyOsiriX_currentBrowser, METH_NOARGS, currentBrowser_doc},
    {"frontmostViewer", pyOsiriX_frontmostDisplayed2DViewer, METH_NOARGS, frontmostViewer_doc},
    {"getDisplayed2DViewers", pyOsiriX_getDisplayed2DViewers, METH_NOARGS, getDisplayed2DViewers_doc},
    {"frontmostVRController", pyOsiriX_frontmostVRController, METH_NOARGS, frontmostVRController_doc},
    {"getDisplayedVRControllers", pyOsiriX_getDisplayedVRControllers, METH_NOARGS, getDisplayedVRControllers_doc},
    {"runAlertPanel", (PyCFunction)pyOsiriX_runAlertPanel, METH_VARARGS|METH_KEYWORDS, runAlertPanel_doc},
	{"selectPath", (PyCFunction)pyOsiriX_selectPath, METH_VARARGS|METH_KEYWORDS, selectPath_doc},
    {NULL, NULL, 0, NULL}
};

PyDoc_STRVAR(osirix_doc,
			 "\n"
			 "pyOsiriX is a python extension to the OsiriX dicom image viewer.\n"
			 "For more information and examples of its use please visit: \n"
			 "         https://sites.google.com/site/pyosirix/\n"
			 "\n"
			 "The 'osirix' module contains all functions and classes required to interact with OsiriX.\n"
			 "It should be noted that, and with good reason, explicit initilisation of most classes is not allowed.\n"
			 "Generally speaking, the functions contained within should be used to provide access to OsiriX data.\n"
			 "Where exceptions are made this is noted in the documentation for the class.\n"
			 "\n"
			 "Please provide any feedback via the pages on our website and stay safe!\n");

PyMODINIT_FUNC initosirix()
{
    PyObject *m = Py_InitModule4("osirix", osirixModuleMethods, osirix_doc, NULL, PYTHON_API_VERSION);
	if (m == NULL) {
		pyOsiriXLog("Error: Could not initialise osirix module");
		PyErr_SetString(PyExc_ImportError, "Could not initialise the osirix module. Please contact us.");
		return;
	}
	[pyBrowserController initTypeInModule:m];
	[pyVRController initTypeInModule:m];
	[pyViewerController initTypeInModule:m];
	[pyLog initTypeInModule:m];
	[pyWait initTypeInModule:m];
	[pyDCMPix initTypeInModule:m];
	[pyROI initTypeInModule:m];
	[pyDicomImage initTypeInModule:m];
	[pyDicomSeries initTypeInModule:m];
	[pyDicomStudy initTypeInModule:m];
}

@implementation pyOsiriX

+ (void)initModule
{
    initosirix();
}

@end
