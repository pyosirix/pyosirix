//
//  pyLog.m
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

#import "pyLog.h"

static void pyLog_dealloc(pyLogObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

static PyObject *pyLog_write(pyLogObject *self, PyObject *args)
{
    char* LogStr = NULL;
    if (!PyArg_ParseTuple(args, "s", &LogStr)) return NULL;
    [self->obj logAppendString:[NSString stringWithUTF8String:LogStr]];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef pyLogMethods[] =
{
    {"write", (PyCFunction)pyLog_write, METH_VARARGS, "Print the input string to the log window"},
    {NULL}
};

PyTypeObject pyLogType =
{
    PyObject_HEAD_INIT(NULL)
    0,
    "log",
    sizeof(pyLogObject),
    0,
    (destructor)pyLog_dealloc,
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
    0,
    0,
    0,
    0,
    Py_TPFLAGS_DEFAULT,
    "Output log to scripting window",
    0,
    0,
    0,
    0,
    0,
    0,
    pyLogMethods,
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

@implementation pyLog

+ (void)initTypeInModule:(PyObject *)module
{
    if (PyType_Ready(&pyLogType) < 0) {
        return;
    }
    Py_INCREF(&pyLogType);
    PyModule_AddObject(module, "log", (PyObject*)&pyLogType);
}

+ (PyObject *)pythonObjectWithInstance:(id)obj
{
    pyLogObject *o = PyObject_New(pyLogObject, &pyLogType);
    o->obj = [obj retain];
    return (PyObject *)o;
}

@end
