//
//  PORuntime.m
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

#import "PORuntime.h"
#import "pyOsiriX.h"
#import "pyViewerController.h"
#import "pyDCMPix.h"
#import "pyROI.h"
#import "pyWait.h"
#import "pyLog.h"
#import "pyVRController.h"
#import "pyBrowserController.h"
#import "pyDicomImage.h"
#import "pyDicomSeries.h"
#import "pyDicomStudy.h"

#import "POErrorCodes.h"
#import "POSimpleLog.h"
#import "POPackageManager.h"

NSString * const pythonRuntimeErrorDomain = @"com.InstituteOfCancerResearch.pyOsiriX.pythonRuntimeErrorDomain";

PORuntime * pyRuntime = nil;

@implementation PORuntime

@synthesize pythonInitialized, runtimeActive;

+ (NSArray *) vitalNamespaceObjects
{
    return [NSArray arrayWithObjects:
            @"__builtins__",
            @"__name__",
            @"__doc__",
            @"__package__", nil];
}

- (void) setRuntimeError:(NSError **)error withReason:(NSString *)reason
{
    *error = [NSError errorWithDomain:pythonRuntimeErrorDomain
                                 code:PYOSIRIXERR_RUNTIME
                             userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Could not start runtime", nil), NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil]];
}

- (void)importExternalModules
{
    //Performing these intial imports on load can speed things up later.
    PyRun_SimpleString("import osirix, dicom, numpy, matplotlib");
    PyRun_SimpleString("import matplotlib.pyplot as pl");
    PyRun_SimpleString("import numpy as np");
}

- (NSString *)getSysPath
{
    POPackageManager *pPM = [POPackageManager packageManager];
    NSArray *vitals = [pPM requiredPackages];
    vitals = [pPM appendPythonEggstoPaths:vitals];
    
    NSMutableString *path = [NSMutableString stringWithFormat:@""];
    for (NSString *pack in vitals) {
        [path appendFormat:@"%@:", pack];
    }
    
    NSArray *userPackages = [pPM getUserPackages];
    if (userPackages) {
        userPackages = [pPM appendPythonEggstoPaths:userPackages];
        for (NSString *pack in userPackages) {
            [path appendFormat:@"%@:", pack];
        }
    }
    
    return [NSString stringWithString:path];
}

- (void)updateSysPath
{
    if (!pythonInitialized) {
        return;
    }
    NSString *path = [self getSysPath];
    PySys_SetPath((char *)[path UTF8String]);
}

- (void)initPythonEnvironment
{
    @try {
        //Should only be called once during OsiriX startup -> Need to make sure it is called by initPlugin.
        //Initialise the Python environment and register all new types
        NSString *frameworks = [[NSBundle bundleForClass:[self class]] privateFrameworksPath];
        NSString *homeStr = [NSString stringWithFormat:@"%@/Python.framework/Versions/2.7/", frameworks];
        
        Py_SetPythonHome((char *)[homeStr UTF8String]);
        Py_Initialize();
		
        //Register the osirix module
        [pyOsiriX initModule];
		
		//Import these on application launch.  Will appear seamless later on.
		[self importExternalModules];
        
        pythonInitialized = YES;
        
        [self updateSysPath];
    }
    @catch (NSException *exception) {
        //If something goes wrong allow OsiriX to continue!
        NSLog(@"Could not initialiase python environment: %@", [exception description]);
        if (Py_IsInitialized()) {
            Py_Finalize();
        }
        pythonInitialized = NO;
    }
}

- (void)dealloc
{
    if (Py_IsInitialized()) {
        Py_Finalize(); //This should always be the case unless another plugin has initialised!!
    }
    Py_DECREF(globalNamespace);
    Py_DECREF(default_log);
    [super dealloc];
}

- (id) init
{
    if (pyRuntime) {
        return nil; //Cannot instantiate more than one instance
    }
    
    self = [super init];
    if (!self) {
        return nil;
    }
    [self initPythonEnvironment];
    default_log = [POSimpleLog newPythonLog]; //This object is owned
    return self;
}

- (BOOL) startPyhtonEnvironment:(NSError **)error
{
    return [self startPythonEnvironmentWithStdOut:NULL andStdErr:NULL :error];
}

- (BOOL) startPythonEnvironmentWithStdOut:(PyObject *)sout andStdErr:(PyObject *)serr :(NSError **)error
{
    if (runtimeActive) {
        if (error != nil) {
            [self setRuntimeError:error withReason:@"Runtime already active"];
        }
        return NO;
    }
    
    //A pointer to the global dictionary
    globalNamespace = PyModule_GetDict(PyImport_AddModule("__main__"));
    
    if (sout != NULL)
        PySys_SetObject("stdout", sout);
    else
        PySys_SetObject("stdout", default_log);
    
    if (serr != NULL)
        PySys_SetObject("stderr", serr);
    else
        PySys_SetObject("stderr", default_log);
    
	[self importExternalModules];
    runtimeActive = YES;
    return YES;
}

- (void) endPythonEnvironment
{
    if (!runtimeActive) {
        return;
    }
    
    //Clean the envirnoment of anything added by the user.
    int Nkeys = PyDict_Size(globalNamespace);
    PyObject *keys = PyDict_Keys(globalNamespace);
    if (Nkeys > 4) {
        NSArray *vitalObjects = [PORuntime vitalNamespaceObjects];
        for (int i = 0; i < Nkeys; i++) {
            PyObject *key = PyList_GetItem(keys, i);
            NSString *nsKey = [NSString stringWithUTF8String:PyString_AsString(key)];
            BOOL remove = YES;
            for (NSString *vO in vitalObjects) {
                if ([vO isEqualToString:nsKey])
                    remove = NO;
            }
            if (remove) {
                PyDict_DelItem(globalNamespace, key);
            }
        }
    }
    PySys_SetObject("stdout", NULL);
    PySys_SetObject("stderr", NULL);
    globalNamespace = NULL;
    runtimeActive = NO;
}

- (int) runSimpleScriptInCurrentEnvironment:(NSString *)script
{
	@try {
		PyObject *v = PyRun_StringFlags([script cStringUsingEncoding:NSUTF8StringEncoding], Py_file_input, globalNamespace, globalNamespace, NULL);
		if (v == NULL) {
			PyErr_Print();
			return -1; //Error occured
		}
		Py_DECREF(v);
		if (Py_FlushLine())
			PyErr_Clear();
		return 0; //OK
	}
	@catch (NSException *exception) {
		NSLog(@"Could not run script!");
		return -1;
	}
}

@end
