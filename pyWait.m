//
//  pyWait.m
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

#import "pyWait.h"

# pragma mark -
# pragma mark pyWaitObject initialization/deallocation

static void pyWait_dealloc(pyWaitObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

# pragma mark -
# pragma mark pyWaitObject str/repr

static PyObject *pyWait_repr(pyWaitObject *self)
{
	NSProgressIndicator *pi = [self->obj progress];
	double maxValue = [pi maxValue];
	double curValue = [pi doubleValue];
	NSString *str = [NSString stringWithFormat:@"Wait instance with maximum value: %f.2\nCurrent value: %f.2", maxValue, curValue];
	return PyString_FromString([str UTF8String]);
}

# pragma mark -
# pragma mark pyWaitObject getters/setters

PyDoc_STRVAR(waitMaxAttr_doc,
			 "A float representing the maximum value of the progress indicator.  This property cannot be set.");

static PyObject *pyWait_getMax(pyWaitObject *self)
{
	NSProgressIndicator *pi = [self->obj progress];
	double max = [pi maxValue];
	return PyFloat_FromDouble(max);
}

PyDoc_STRVAR(waitFloatAttr_doc,
			 "A float representing the current value of the progress indicator.  This property cannot be set.");

static PyObject *pyWait_getFloat(pyWaitObject *self)
{
	NSProgressIndicator *pi = [self->obj progress];
	double cur = [pi doubleValue];
	return PyFloat_FromDouble(cur);
}

static PyGetSetDef pyWait_getsetters[] =
{
	{"maxValue", (getter)pyWait_getMax, NULL, waitMaxAttr_doc, NULL},
	{"floatValue", (getter)pyWait_getFloat, NULL, waitFloatAttr_doc, NULL},
    {NULL}
};

# pragma mark -
# pragma mark pyWaitObject methods

PyDoc_STRVAR(waitIncrementBy_doc,
			 "\n"
			 "Increment the progress by the amount specified.\n"
			 "\n"
			 "Args:\n"
			 "   floatValue (float): The value by which to increase the progress bar\n"
			 "\n"
			 "Returns:\n"
			 "    None.\n"
			 "\n"
			 "Example:\n"
			 "    >>> wait.incrementBy(1.0)\n"
			 );

static PyObject *pyWait_incrementBy(pyWaitObject *self, PyObject *args)
{
    float inc;
    if (!PyArg_ParseTuple(args, "f", &inc))
    {
        return NULL;
    }
    [self->obj incrementBy:inc];
    
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef pyWaitMethods[] =
{
    {"incrementBy", (PyCFunction)pyWait_incrementBy, METH_VARARGS, waitIncrementBy_doc},
    {NULL}
};

# pragma mark -
# pragma mark pyWaitType definition

PyDoc_STRVAR(wait_doc,
			 "A python implementation of the OsiriX 'Wait' class.\n"
			 "This class is used to update a progress indicator / progress bar.\n"
			 "Instances of this class may not be created.  Instead see the documatation\n"
			 "for osirix.ViewerController for creation methods therein\n"
			 "\n"
			 "Example Usage:\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> w = vc.startWaitProgressWindow(\"Counting 1, 2, ..., 100\", 100)\n"
			 "    >>> for i in range(100):\n"
			 "    >>>     doSomething(...)\n"
			 "    >>>     w.incrementBy(1.0)\n"
			 "    >>> vc.endWaitWindow(w)\n"
			 );

PyTypeObject pyWaitType =
{
    PyObject_HEAD_INIT(NULL)
    0,
    "osirix.Wait",
    sizeof(pyWaitObject),
    0,
    (destructor)pyWait_dealloc,
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
    (reprfunc)pyWait_repr,
    0,
    0,
    0,
    Py_TPFLAGS_DEFAULT,
    wait_doc,
    0,
    0,
    0,
    0,
    0,
    0,
    pyWaitMethods,
    0,
    pyWait_getsetters,
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
# pragma mark pyWait implementation

@implementation pyWait

+ (void)initTypeInModule:(PyObject *)module
{
    if (PyType_Ready(&pyWaitType) < 0) {
        return;
    }
    Py_INCREF(&pyWaitType);
    PyModule_AddObject(module, "Wait", (PyObject*)&pyWaitType);
}

+ (PyObject *)pythonObjectWithInstance:(id)obj
{
    if ([obj class] != [Wait class]) {
        return NULL;
    }
    
    pyWaitObject *o = PyObject_New(pyWaitObject, &pyWaitType);
    o->obj = [obj retain];
    return (PyObject *)o;
}


@end
