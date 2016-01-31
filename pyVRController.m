//
//  pyVRController.m
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

#import "pyVRController.h"
#import <OsiriXAPI/ViewerController.h>
#import "pyViewerController.h"

static void pyVRController_dealloc(pyVRControllerObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

static PyObject *pyVRController_renderingMode(pyVRControllerObject *self, void *closure)
{
    NSString *rm = [self->obj renderingMode];
    return PyString_FromString([rm UTF8String]);
}

static int pyVRController_setRenderingMode(pyVRControllerObject *self, PyObject *value, void *closure)
{
    if (!PyString_CheckExact(value)) {
        PyErr_SetString(PyExc_ValueError, "Rendering mode must be a string. Eithre 'VR' or 'MIP'");
        return -1;
    }
    
    NSString *omode = [NSString stringWithUTF8String:PyString_AsString(value)];
    if ([omode isEqualToString:[self->obj renderingMode]])
        return 0; //Already set - no need to do anything
    
    if (![omode isEqualToString:@"VR"] && ![omode isEqualToString:@"MIP"]) {
        PyErr_SetString(PyExc_ValueError, "Rendering mode must be a string. Eithre 'VR' or 'MIP'");
        return -1;
    }
    
    [self->obj setRenderingMode:omode];
    
    return 0;
}

static PyObject *pyVRController_getWLWW(pyVRControllerObject *self, void *closure)
{
    float wl, ww;
    [self->obj getWLWW:&wl :&ww];
    PyObject *owl = PyFloat_FromDouble((double)wl);
    PyObject *oww = PyFloat_FromDouble((double)ww);
    PyObject *owlww = PyTuple_New(2);
    PyTuple_SetItem(owlww, 0, owl); //Reference stolen
    PyTuple_SetItem(owlww, 1, oww); //Reference stolen
    return owlww;
}

static int pyVRController_setWLWW(pyVRControllerObject *self, PyObject *value, void *closure)
{
    float wl, ww;
    if (!PyTuple_CheckExact(value)) {
        PyErr_SetString(PyExc_ValueError, "Value must be a two-element tuple of floats of the form (wl, ww)");
        return -1;
    }
    if (PyTuple_Size(value) != 2) {
        PyErr_SetString(PyExc_ValueError, "Value must be a two-element tuple of floats of the form (wl, ww)");
        return -1;
    }
    PyObject *owl = PyTuple_GetItem(value, 0);
    if (!PyFloat_CheckExact(owl)) {
        PyErr_SetString(PyExc_ValueError, "Value must be a two-element tuple of floats of the form (wl, ww)");
        return -1;
    }
    PyObject *oww = PyTuple_GetItem(value, 1);
    if (!PyFloat_CheckExact(oww)) {
        PyErr_SetString(PyExc_ValueError, "Value must be a two-element tuple of floats of the form (wl, ww)");
        return -1;
    }
    wl = (float)PyFloat_AsDouble(owl);
    ww = (float)PyFloat_AsDouble(oww);
    [self->obj setWLWW:wl :ww];
    return 0;
}

static PyObject *pyVRController_style(pyVRControllerObject *self, void *closure)
{
    NSString *st = [self->obj style];
    return PyString_FromString([st UTF8String]);
}

static PyObject *pyVRController_title(pyVRControllerObject *self, void *closure)
{
    NSString *title = [[self->obj window] title];
    return PyString_FromString([title UTF8String]);
}

static PyGetSetDef pyVRController_getsetters[] =
{
    {"renderingMode", (getter)pyVRController_renderingMode, (setter) pyVRController_setRenderingMode, "A string representing the rendering mode of the VRController. Valid values are 'VR' and 'MIP'", NULL},
    {"WLWW", (getter)pyVRController_getWLWW, (setter)pyVRController_setWLWW, "A float tuple (wl, ww) representing the current window level and window width of the VRController.", NULL},
    {"style", (getter)pyVRController_style, NULL, "The style of the VRController.  Either 'panel' or 'standard'", NULL},
    {"title", (getter)pyVRController_title, NULL, "The title of the VRController window.", NULL},
    {NULL}
};

static PyObject *pyVRController_viewer2D(pyVRControllerObject *self)
{
    ViewerController *vc = [self->obj viewer2D];
    return [pyViewerController pythonObjectWithInstance:vc];
}

static PyObject *pyVRController_blendingController(pyVRControllerObject *self)
{
    ViewerController *bvc = [self->obj blendingController];
    if (bvc == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return [pyViewerController pythonObjectWithInstance:bvc];
}

static PyMethodDef pyVRControllerMethods[] =
{
    {"viewer2D", (PyCFunction)pyVRController_viewer2D, METH_NOARGS, "Get the 2D ViewerController instance associated with this Volume Renderer"},
    {"blendingController", (PyCFunction)pyVRController_blendingController, METH_NOARGS, "Get the blended 2D ViewerController instance associated with this Volume Renderer if one is present"},
    {NULL}
};

PyTypeObject pyVRControllerType =
{
    PyObject_HEAD_INIT(NULL)
    0,
    "osirix.VRController",
    sizeof(pyVRControllerObject),
    0,
    (destructor)pyVRController_dealloc,
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
    "Volume Render Controller",
    0,
    0,
    0,
    0,
    0,
    0,
    pyVRControllerMethods,
    0,
    pyVRController_getsetters,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
};

@implementation pyVRController

+ (void)initTypeInModule:(PyObject *)module
{
    if (PyType_Ready(&pyVRControllerType) < 0) {
        return;
    }
    Py_INCREF(&pyVRControllerType);
    PyModule_AddObject(module, "VRController", (PyObject*)&pyVRControllerType);
}

+ (PyObject *)pythonObjectWithInstance:(id)obj
{
    if ([obj class] != [VRController class]) {
        return NULL;
    }
    
    pyVRControllerObject *o = PyObject_New(pyVRControllerObject, &pyVRControllerType);
    o->obj = [obj retain];
    return (PyObject *)o;
}
@end
