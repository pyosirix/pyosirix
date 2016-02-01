//
//  pyROIVolume.m
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

#import <OsiriXAPI/ROIVolume.h>
#import "pyROIVolume.h"

# pragma mark -
# pragma mark pyROIVolumeObject initialization/deallocation

static void pyROIVolume_dealloc(pyROIVolumeObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

# pragma mark -
# pragma mark pyROIObject str/repr

static PyObject *pyROIVolume_str(pyROIVolumeObject *self)
{
	NSString *str = [NSString stringWithFormat:@"ROIVolume object\nName: %@\nVolume: %f\n", [self->obj name], [self->obj volume]];
	PyObject *ostr = PyString_FromString([str UTF8String]);
	if (ostr == NULL) {
		Py_INCREF(Py_None);
		return Py_None;
	}
	return ostr;
}

# pragma mark -
# pragma mark pyROIVolumeObject getters/setters

PyDoc_STRVAR(ROIVolumeNameAttr_doc,
			 "A string representing the name of the ROIVolume.  This will match those of the contructing ROIs.\n"
			 "This property cannot be set.\n"
			 );

static PyObject *pyROIVolume_getName(pyROIVolumeObject *self, void *closure)
{
    PyObject *pyStr = PyString_FromString([[self->obj name] UTF8String]);
    return pyStr;
}

PyDoc_STRVAR(ROIVolumeVisibleAttr_doc,
			 "A bool determining whether the ROIVolume is visible within the VRController.\n"
			 );

static PyObject *pyROIVolume_getVisible(pyROIVolumeObject *self, void *closure)
{
    BOOL visible = [self->obj visible];
    return PyBool_FromLong(visible?(long)1:(long)0);
}

static int pyROIVolume_setVisible(pyROIVolumeObject *self, PyObject *value, void *closure)
{
	if (!PyInt_CheckExact(value)) {
        PyErr_SetString(PyExc_TypeError, "Type not a bool/integer");
        return -1;
    }
    BOOL visible = PyInt_AsLong(value)>0?YES:NO;
    [self->obj setVisible:visible];
	return 0;
}

PyDoc_STRVAR(ROIVolumeTextureAttr_doc,
			 "A bool determining whether the ROIVolume is textured.\n"
			 );

static PyObject *pyROIVolume_getTexture(pyROIVolumeObject *self, void *closure)
{
    BOOL text = [self->obj texture];
    return PyBool_FromLong(text?(long)1:(long)0);
}

static int pyROIVolume_setTexture(pyROIVolumeObject *self, PyObject *value, void *closure)
{
	if (!PyInt_CheckExact(value)) {
        PyErr_SetString(PyExc_TypeError, "Type not a bool/integer");
        return -1;
    }
    BOOL text = PyInt_AsLong(value)>0?YES:NO;
    [self->obj setTexture:text];
	return 0;
}

PyDoc_STRVAR(ROIVolumeColorAttr_doc,
			 "A 4-element (R,G,B,A) tuple representing the ROIVolume color.\n"
			 "Each element must be in the range 0 -> 1.\n"
			 );

static PyObject *pyROIVolume_getColor(pyROIVolumeObject *self, void *closure)
{
    NSColor *col = [self->obj color];
	PyObject *tup = PyTuple_New(4);
	PyTuple_SetItem(tup, 0, PyFloat_FromDouble((double)[col redComponent]));
	PyTuple_SetItem(tup, 1, PyFloat_FromDouble((double)[col greenComponent]));
	PyTuple_SetItem(tup, 2, PyFloat_FromDouble((double)[col blueComponent]));
	PyTuple_SetItem(tup, 3, PyFloat_FromDouble((double)[col alphaComponent]));
    return tup;
}

static int pyROIVolume_setColor(pyROIVolumeObject *self, PyObject *value, void *closure)
{
	if (!PyTuple_CheckExact(value))
    {
        PyErr_SetString(PyExc_TypeError, "Color must be a 4-tuple of type (R,G,B,A) with 0 <= RGBA <= 1");
        return -1;
    }
    if (PyTuple_Size(value) != 4)
    {
        PyErr_SetString(PyExc_TypeError, "Color must be a 4-tuple of type (R,G,B,A) with 0 <= RGBA <= 1");
        return -1;
    }
    for (int i = 0; i < 4; i++) {
        if (!PyFloat_CheckExact(PyTuple_GetItem(value, i)))
        {
            PyErr_SetString(PyExc_TypeError, "Color must be a 4-tuple of type (R,G,B,A) with 0 <= RGBA <= 1");
			return -1;
        }
    }
    
    double r = PyFloat_AsDouble(PyTuple_GetItem(value, 0));
    double g = PyFloat_AsDouble(PyTuple_GetItem(value, 1));
    double b = PyFloat_AsDouble(PyTuple_GetItem(value, 2));
	double a = PyFloat_AsDouble(PyTuple_GetItem(value, 3));
    
    r = r > 1.0 ? 1.0 : r;
    r = r < 0.0 ? 0.0 : r;
    g = g > 1.0 ? 1.0 : g;
    g = g < 0.0 ? 0.0 : g;
    b = b > 1.0 ? 1.0 : b;
    b = b < 0.0 ? 0.0 : b;
	a = a > 1.0 ? 1.0 : a;
    a = a < 0.0 ? 0.0 : a;
    
    NSColor *col = [NSColor colorWithRed:r green:g blue:b alpha:a];
    [self->obj setColor:col];
    return 0;
}

static PyGetSetDef pyROIVolume_getsetters[] =
{
    {"name", (getter)pyROIVolume_getName, NULL, ROIVolumeNameAttr_doc, NULL},
    {"visible", (getter)pyROIVolume_getVisible, (setter)pyROIVolume_setVisible, ROIVolumeVisibleAttr_doc, NULL},
	{"texture", (getter)pyROIVolume_getTexture, (setter)pyROIVolume_setTexture, ROIVolumeTextureAttr_doc, NULL},
    {"color", (getter)pyROIVolume_getColor, (setter)pyROIVolume_setColor, ROIVolumeColorAttr_doc, NULL},
    {NULL}
};

# pragma mark -
# pragma mark pyROIVolumeObject methods

PyDoc_STRVAR(ROIVolumeVolume_doc,
			 "\n"
			 "Returns float representing the volume of the 3D ROI.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    float: The volume in cm^3.\n"
			 );

static PyObject *pyROIVolume_volume(pyROIVolumeObject *self)
{
    float vol = [self->obj volume];
    PyObject *pyVol = PyFloat_FromDouble((double)vol);
    return pyVol;
}

static PyMethodDef pyROIVolumeMethods[] =
{
    {"volume", (PyCFunction)pyROIVolume_volume, METH_NOARGS, ROIVolumeVolume_doc},
    {NULL}
};

# pragma mark -
# pragma mark pyROIVolumeType definition

PyDoc_STRVAR(ROIVolume_doc,
			 "A python implementation of the OsiriX 'ROIVolume' class.\n"
			 "Instances of this class may not be created.  Rather they are accessed through the methods defined in VRController.\n"
			 "\n"
			 );

PyTypeObject pyROIVolumeType =
{
    PyObject_HEAD_INIT(NULL)
    0,
    "osirix.ROIVolume",
    sizeof(pyROIVolumeObject),
    0,
    (destructor)pyROIVolume_dealloc,
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
    (reprfunc)pyROIVolume_str,
    0,
    0,
    0,
    Py_TPFLAGS_DEFAULT,
    ROIVolume_doc,
    0,
    0,
    0,
    0,
    0,
    0,
    pyROIVolumeMethods,
    0,
    pyROIVolume_getsetters,
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
# pragma mark pyROIVolume implementation

@implementation pyROIVolume

+ (void)initTypeInModule:(PyObject *)module
{
    if (PyType_Ready(&pyROIVolumeType) < 0) {
        return;
    }
    Py_INCREF(&pyROIVolumeType);
    PyModule_AddObject(module, "ROIVolume", (PyObject*)&pyROIVolumeType);
}

+ (PyObject *)pythonObjectWithInstance:(id)obj
{
    if ([obj class] != [ROIVolume class]) {
        return NULL;
    }
    
    pyROIVolumeObject *o = PyObject_New(pyROIVolumeObject, &pyROIVolumeType);
    o->obj = [obj retain];
    return (PyObject *)o;
}

@end
