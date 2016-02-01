//
//  pyBrowserController.m
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

#import "pyBrowserController.h"
#import "pyDicomImage.h"
#import "pyDicomSeries.h"
#import "pyDicomStudy.h"

# pragma mark -
# pragma mark pyBrowserControllerObject initialization/deallocation

static void pyBrowserController_dealloc(pyBrowserControllerObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

# pragma mark -
# pragma mark pyBrowserControllerObject str/repr

static PyObject *pyBrowserController_str(pyBrowserControllerObject *self)
{
	NSString *str = [NSString stringWithFormat:@"BrowserController object.  The main database window of OsiriX."];
	PyObject *ostr = PyString_FromString([str UTF8String]);
	if (ostr == NULL) {
		Py_INCREF(Py_None);
		return Py_None;
	}
	return ostr;
}

# pragma mark -
# pragma mark pyBrowserControllerObject methods

PyDoc_STRVAR(BrowserControllerDatabaseSelection_doc,
			 "\n"
			 "Return current selection of DicomStudy and DiscomSeries instances currently selected in the database window.\n"
			 "\n"
			 "Args:\n"
			 "    None\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: A tuple of all selected DicomStudy and DicomSeries instances.\n"
			 );

static PyObject *pyBrowserController_databaseSelection(pyBrowserControllerObject *self)
{
    BrowserController *bc = self->obj;
    NSArray *array = [bc databaseSelection];
    if ([array count] == 0) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    PyObject *tup = PyTuple_New([array count]);
    int idx = 0;
    for (id obj in array) {
        if ([obj isKindOfClass:[DicomImage class]])
        {
            PyObject *o = [pyDicomImage pythonObjectWithInstance:(DicomImage *)obj];
            PyTuple_SetItem(tup, idx, o);
        }
        else if ([obj isKindOfClass:[DicomSeries class]])
        {
            PyObject *o = [pyDicomSeries pythonObjectWithInstance:(DicomSeries *)obj];
            PyTuple_SetItem(tup, idx, o);
        }
        else if ([obj isKindOfClass:[DicomStudy class]])
        {
            PyObject *o = [pyDicomStudy pythonObjectWithInstance:(DicomStudy *)obj];
            PyTuple_SetItem(tup, idx, o);
        }
        else
        {
            NSString *str = [NSString stringWithFormat:@"Invalid selection %@ encountered", [obj className]];
            PyErr_SetString(PyExc_TypeError, [str UTF8String]);
            Py_DECREF(tup);
            return NULL;
        }
        idx++;
    }
    return tup;
}

PyDoc_STRVAR(BrowserControllerCopyFilesIntoDatabaseIfNeeded_doc,
			 "\n"
			 "Import a list of dicom files into the database.  If they are already present, this operation is a no-op.\n"
			 "Note that this method will make a COPY of the files and store them in the currently active database.\n"
			 "\n"
			 "Args:\n"
			 "    filenames (list): A list of absolute paths for the dicom files to be added.\n"
			 "\n"
			 "Returns:\n"
			 "    None.\n"
			 );

static PyObject *pyBrowserController_copyFilesIntoDatabaseIfNeeded(pyBrowserControllerObject *self, PyObject *args)
{
    PyObject *list;
    if (!PyArg_ParseTuple(args, "O!", &PyList_Type, &list)) {
        return NULL;
    }
    
    int nFiles = PyList_Size(list);
    if (nFiles < 1) {
        PyErr_SetString(PyExc_ValueError, "Empty list of files given");
        return NULL;
    }
    
    NSMutableArray *files = [NSMutableArray array];
    for (int i = 0; i < nFiles; i++) {
        PyObject *str = PyList_GetItem(list, i);
        if (!PyString_Check(str)) {
            PyErr_SetString(PyExc_ValueError, "The list of filenames must contain only strings");
            return NULL;
        }
        NSString *path = [NSString stringWithUTF8String:PyString_AsString(str)];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            NSString *err = [NSString stringWithFormat:@"File at path %@ does not exist.  Ignoring.", path];
            PyErr_Warn(PyExc_Warning, [err UTF8String]);
        }
        else
        {
            [files addObject:path];
        }
    }
    
    BrowserController *bc = self->obj;
    [bc copyFilesIntoDatabaseIfNeeded:files options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"COPYDATABASE", [NSNumber numberWithInt:0], @"COPYDATABASEMODE", [NSNumber numberWithBool:YES], @"async", nil]];
	Py_INCREF(Py_None);
	return Py_None;
}

static PyMethodDef pyBrowserControllerMethods[] =
{
    {"databaseSelection", (PyCFunction)pyBrowserController_databaseSelection, METH_NOARGS, BrowserControllerDatabaseSelection_doc},
	{"copyFilesIntoDatabaseIfNeeded", (PyCFunction)pyBrowserController_copyFilesIntoDatabaseIfNeeded, METH_VARARGS, BrowserControllerCopyFilesIntoDatabaseIfNeeded_doc},
    {NULL}
};

# pragma mark -
# pragma mark pyBrowserControllerType definition

PyDoc_STRVAR(BrowserController_doc,
			 "A python implementation of the OsiriX 'BrowserController' class.\n"
			 "This class is used to obtain access to studies, series and images within the OsiriX database.\n"
			 "Furthermore, this class provides a simple method to import dicom images into the OsiriX database"
			 "Instances of this class may not be created.  Instead instances are accessed\n"
			 "via functions defined in the osirix module\n"
			 "\n"
			 "Example Usage:\n"
			 "    >>> import osirix\n"
			 "    >>> bc = osirix.currentBrowser()\n"
			 "    >>> print bc.databaseSelection\n"
			 );

PyTypeObject pyBrowserControllerType =
{
    PyObject_HEAD_INIT(NULL)
    0,
    "osirix.BrowserController",
    sizeof(pyBrowserControllerObject),
    0,
    (destructor)pyBrowserController_dealloc,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    (reprfunc)pyBrowserController_str,
    0,
    0,
    0,
    Py_TPFLAGS_DEFAULT,
    BrowserController_doc,
    0,
    0,
    0,
    0,
    0,
    0,
    pyBrowserControllerMethods,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
};

# pragma mark -
# pragma mark pyBrowserController implementation

@implementation pyBrowserController

+ (void)initTypeInModule:(PyObject *)module
{
    if (PyType_Ready(&pyBrowserControllerType) < 0) {
        return;
    }
    Py_INCREF(&pyBrowserControllerType);
    PyModule_AddObject(module, "BrowserController", (PyObject*)&pyBrowserControllerType);
}

+ (PyObject *)pythonObjectWithInstance:(id)obj
{
    if ([obj class] != [BrowserController class]) {
        return NULL;
    }
    
    pyBrowserControllerObject *o = PyObject_New(pyBrowserControllerObject, &pyBrowserControllerType);
    o->obj = [obj retain];
    return (PyObject *)o;
}

@end
