//
//  pyROI.m
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

#import "pyROI.h"
#include <arrayobject.h>
#import <OsiriXAPI/DCMView.h>
#import <OsiriXAPI/DCMPix.h>
#import <OsiriXAPI/MyPoint.h>
#import "pyDCMPix.h"
#import "pyOsiriX.h"

static void pyROI_dealloc(pyROIObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

static PyObject *pyROI_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    //Al this does is allocate the instance memory -> try to keep in line eith obj-C syntax style: [[ROI alloc] initWith:...]
    pyROIObject *self = (pyROIObject *)type->tp_alloc(type, 0);
    if(self)
        self->obj = [ROI alloc];
    return (PyObject *)self;
}

void init_numpy_ROI()
{
    import_array(); //TODO! - This is the only way I can get this to work!!
}

static int pyROI_init(pyROIObject *self, PyObject *args, PyObject *kwds)
{
    //Make sure user has supplied a type, then we can decide what to do with it!
    static char *kwlist[] = {"itype", "buffer", "position", "DCMPix", "name", "ipixelSpacing", "iimageorigin", "addToDCMPix", NULL};
    
    char * roiType = "tCPolygon";
    float iSpx = 1.0;
    float iSpy = 1.0;
    float iOrx = 0.0;
    float iOry = 0.0;
    PyObject *dcmRef = NULL;
    int addToDCM = 0;
    char *name = "Un-named ROI";
    PyObject *buffer = NULL;
    int posX = 0;
    int posY = 0;
    
    init_numpy_ROI();
    if (!PyArg_ParseTupleAndKeywords(args, kwds, "|sO!(ii)O!s(ff)(ff)d", kwlist, &roiType, &PyArray_Type, &buffer, &posX, &posY, &pyDCMPixType, &dcmRef, &name, &iSpx, &iSpy, &iOrx, &iOry, &addToDCM))
    {
        pyOsiriXLog("Could not instantiate the ROI instance");
        return -1;
    }
    
    NSDictionary *roiTypesDictionary = [pyROI toolsDictionary];
    int toolType = [[roiTypesDictionary objectForKey:[NSString stringWithUTF8String:roiType]] integerValue];
    
    if (toolType != tPlain && toolType != tOPolygon && toolType != tCPolygon && toolType != tPencil) {
        NSArray *allowedTools = [NSArray arrayWithObjects:@"tPlain", @"tOPolygon", @"tCPolygon", @"tPencil", nil];
        NSString *str = [NSString stringWithFormat:@"Only the following ROI types can be created: %@", allowedTools];
        PyErr_SetString(PyExc_ValueError, [str UTF8String]);
        return -1;
    }
    
    if (toolType == tPlain) {
        if (!buffer) {
            PyErr_SetString(PyExc_ValueError, "For ROI type: tPlain, the keyword 'buffer' must be set");
            return -1;
        }
        
        //Easier to work directly with array objects
        PyArrayObject *bufferArray = (PyArrayObject *)buffer;
        
        //Check that a valid buffer mask has been provided
        int nd = PyArray_NDIM(bufferArray);
        npy_intp *dims = PyArray_DIMS(bufferArray);
        int type = (int)PyArray_TYPE(bufferArray);
        if (nd != 2) {
            PyErr_SetString(PyExc_ValueError, "Input buffer array must be a two-dimensional array");
            return -1;
        }
        if (type != NPY_BOOL) {
            PyErr_SetString(PyExc_ValueError, "Input buffer must be type BOOL");
            return -1;
        }
        int dimsX = dims[0];
        int dimsY = dims[1];
        unsigned char *roi_buffer = malloc(dimsX * dimsY * sizeof(unsigned char));
        unsigned char *npy_buffer;
        for (int i = 0; i < dimsX; i++) {
            for (int j = 0; j < dimsY; j++) {
                npy_buffer = (unsigned char *)PyArray_GETPTR2(bufferArray, i, j);
                if (*npy_buffer == NPY_FALSE)
                    roi_buffer[i + j*dimsX] = 0x00;
                else
                    roi_buffer[i + j*dimsX] = 0xff;
            }
        }
        
        if (dcmRef) {
            DCMPix *pix = ((pyDCMPixObject *)dcmRef)->obj;
            iOrx = [pix originX];
            iOry = [pix originY];
            iSpx = (float)[pix pixelSpacingX];
            iSpy = (float)[pix pixelSpacingY];
        }
        NSPoint iOr;
        iOr.x = iOrx;
        iOr.y = iOry;
        [self->obj initWithTexture:roi_buffer textWidth:dimsX textHeight:dimsY textName:[NSString stringWithUTF8String:name] positionX:posX positionY:posY spacingX:iSpx spacingY:iSpy imageOrigin:iOr];
    }
    else {
        if (dcmRef) {
            //If a DCM reference is passed fill in with its values.
            DCMPix *pix = ((pyDCMPixObject *)dcmRef)->obj;
            iOrx = [pix originX];
            iOry = [pix originY];
            iSpx = (float)[pix pixelSpacingX];
            iSpy = (float)[pix pixelSpacingY];
        }
        NSPoint iOr;
        iOr.x = iOrx;
        iOr.y = iOry;
        [self->obj initWithType:toolType :iSpx :iSpy :iOr];
        [self->obj setName:[NSString stringWithUTF8String:name]];
    }
    
    if (dcmRef && addToDCM != 0) {
        DCMPix *pix = ((pyDCMPixObject *)dcmRef)->obj;
        [self->obj setPix:pix];
    }
    return 0;
}

static PyObject *pyROI_getType(pyROIObject *self, void *closure)
{
    ROI *roi = self->obj;
    long t = [roi type];
    NSDictionary *roiTypesDictionary = [pyROI toolsDictionary];
    NSArray *typeKeys = [roiTypesDictionary allKeys];
    NSString *key = [typeKeys objectAtIndex:t];
    PyObject *pyStr = PyString_FromString([key UTF8String]);
    return pyStr;
}

static PyObject *pyROI_getThickness(pyROIObject *self, void *closure)
{
    float thick = [self->obj thickness];
    return PyFloat_FromDouble((double) thick);
}

static int pyROI_setThickness(pyROIObject *self, PyObject *value, void *closure)
{
    if (!PyFloat_CheckExact(value)) {
        PyErr_SetString(PyExc_TypeError, "Type not a float");
        return -1;
    }
    [self->obj setThickness:(float)PyFloat_AsDouble(value)];
    return 0;
}

static PyObject *pyROI_getOpacity(pyROIObject *self, void *closure)
{
    float op = [self->obj opacity];
    return PyFloat_FromDouble((double) op);
}

static int pyROI_setOpacity(pyROIObject *self, PyObject *value, void *closure)
{
    if (!PyFloat_CheckExact(value)) {
        PyErr_SetString(PyExc_TypeError, "Type not a float");
        return -1;
    }
    float op  = (float)PyFloat_AsDouble(value);
    op = op > 1.0 ? 1.0 : op;
    op = op < 0.0 ? 0.0 : op;
    [self->obj setOpacity:op];
    return 0;
}

static PyObject *pyROI_getColor(pyROIObject *self, void *closure)
{
    RGBColor col = [self->obj rgbcolor];
    short r = col.red / 256;
    short g = col.green / 256;
    short b = col.blue / 256;
    PyObject *rgb = PyTuple_New(3);
    PyTuple_SetItem(rgb, 0, PyInt_FromLong((long)r));
    PyTuple_SetItem(rgb, 1, PyInt_FromLong((long)g));
    PyTuple_SetItem(rgb, 2, PyInt_FromLong((long)b));
    return rgb;
}

static int pyROI_setColor(pyROIObject *self, PyObject *value, void *closure)
{
    if (!PyTuple_CheckExact(value))
    {
        PyErr_SetString(PyExc_TypeError, "Color must be a 3-tuple of type (R,G,B) with 0 <= RGB <= 255");
        return -1;
    }
    if (PyTuple_Size(value) != 3)
    {
        PyErr_SetString(PyExc_TypeError, "Color must be a 3-tuple of type (R,G,B) with 0 <= RGB <= 255");
        return -1;
    }
    for (int i = 0; i < 3; i++) {
        if (!PyInt_CheckExact(PyTuple_GetItem(value, i)))
        {
            PyErr_SetString(PyExc_TypeError, "Color must be a 3-tuple of type (R,G,B) with 0 <= RGB <= 255");
            return -1;
        }
    }
    
    long r = PyInt_AsLong(PyTuple_GetItem(value, 0));
    long g = PyInt_AsLong(PyTuple_GetItem(value, 1));
    long b = PyInt_AsLong(PyTuple_GetItem(value, 2));
    
    r = r > 255 ? 255 : r;
    r = r < 0 ? 0 : r;
    g = g > 255 ? 255 : g;
    g = g < 0 ? 0 : g;
    b = b > 255 ? 255 : b;
    b = b < 0 ? 0 : b;
    
    RGBColor rgb;
    rgb.red = (short)(r*256);
    rgb.green = (short)(g*256);
    rgb.blue = (short)(b*256);
    
    [self->obj setColor:rgb];
    return 0;
}

static PyObject *pyROI_getName(pyROIObject *self, void *closure)
{
    NSString *name = [self->obj name];
    PyObject *pyName = PyString_FromString([name UTF8String]);
    return pyName;
}

static int pyROI_setName(pyROIObject *self, PyObject *value, void *closure)
{
    if (!PyString_Check(value)) {
        PyErr_SetString(PyExc_TypeError,
                        "Name must be a string");
        return -1;
    }
    char * name = PyString_AsString(value);
    [self->obj setName:[NSString stringWithUTF8String:name]];
    return 0;
}

static PyObject *pyROI_getPix(pyROIObject *self, void *closure)
{
    DCMPix *pix = [self->obj pix];
    PyObject *pyPix = [pyDCMPix pythonObjectWithInstance:pix];
    return pyPix;
}

static int pyROI_setPoints(pyROIObject *self, PyObject *value, void *closure)
{
    init_numpy_ROI();
    if (!PyArray_Check(value)) {
        PyErr_SetString(PyExc_TypeError, "Input must be a Numpy float array with shape [N, 2]");
        return -1;
    }
    
    PyArrayObject *pts = (PyArrayObject *)value;
    
    int nd = PyArray_NDIM(pts);
    npy_intp *dims = PyArray_DIMS(pts);
    int type = (int)PyArray_TYPE(pts);
    
    if (nd != 2) {
        PyErr_SetString(PyExc_TypeError, "Input must be a Numpy float array with shape [N, 2]");
        return -1;
    }
    
    if (!(type != NPY_FLOAT || type != NPY_DOUBLE || type != NPY_LONGDOUBLE)) {
        PyErr_SetString(PyExc_TypeError, "Input must be a Numpy float array with shape [N, 2]");
        return -1;
    }
    
    if (dims[1] != 2) {
        PyErr_SetString(PyExc_TypeError, "Input must be a Numpy float array with shape [N, 2]");
        return -1;
    }
    
    int cnt = dims[0];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:cnt];
    for (int i = 0; i < cnt; i++) {
        CGFloat pntX = (CGFloat)(*((double *)(PyArray_GETPTR2(pts, i, 0))));
        CGFloat pntY = (CGFloat)(*((double *)(PyArray_GETPTR2(pts, i, 1))));
        NSPoint pt;
        pt.x = pntX;
        pt.y = pntY;
        MyPoint *point = [MyPoint point:pt];
        [array addObject:point];
    }
    [self->obj setPoints:array];
    return 0;
}

static PyObject *pyROI_getPoints(pyROIObject *self, void *closure)
{
    init_numpy_ROI();
    NSMutableArray *pts = [self->obj points];
    npy_intp dims[2] = {[pts count], 2};
    PyObject *pts_npy = PyArray_SimpleNew(2, dims, NPY_DOUBLE);
    for (int i = 0; i < [pts count]; i++) {
        MyPoint *point = [pts objectAtIndex:i];
        double ptX = (double)[point x];
        double ptY = (double)[point y];
        *((double *)(PyArray_GETPTR2((PyArrayObject *)pts_npy, i, 0))) = ptX;
        *((double *)(PyArray_GETPTR2((PyArrayObject *)pts_npy, i, 1))) = ptY;
    }
    return pts_npy;
}

static PyGetSetDef pyROI_getsetters[] =
{
    {"type", (getter)pyROI_getType, NULL, "The type of ROI", NULL},
    {"thickness", (getter)pyROI_getThickness, (setter)pyROI_setThickness, "The thickness of the ROI", NULL},
    {"opacity", (getter)pyROI_getOpacity, (setter)pyROI_setOpacity, "The opacity of the ROI", NULL},
    {"color", (getter)pyROI_getColor, (setter)pyROI_setColor, "The color of the ROI", NULL},
    {"name", (getter)pyROI_getName, (setter)pyROI_setName, "The name of the ROI", NULL},
    {"pix", (getter)pyROI_getPix, NULL, "The pix object in which the ROI is contained", NULL},
    {"points", (getter)pyROI_getPoints, (setter)pyROI_setPoints, "A list of Nx2 points describing the ROI", NULL},
    {NULL}
};

static PyObject *pyROI_centroid(pyROIObject *self)
{
    NSPoint pt = [self->obj centroid];
    PyObject *pyPt = PyTuple_New(2);
    PyTuple_SetItem(pyPt, 0, PyFloat_FromDouble((double)pt.x));
    PyTuple_SetItem(pyPt, 1, PyFloat_FromDouble((double)pt.y));
    return pyPt;
}

static PyObject *pyROI_roiMove(pyROIObject *self, PyObject *args)
{
    NSPoint pt;
    float x, y;
    if (!PyArg_ParseTuple(args, "ff", &x, &y)) {
        return NULL;
    }
    pt.x = x;
    pt.y = y;
    [self->obj roiMove:pt];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject *pyROI_rotate(pyROIObject *self, PyObject *args)
{
    NSPoint pt;
    float theta, x, y;
    if (!PyArg_ParseTuple(args, "f(ff)", &theta, &x, &y)) {
        return NULL;
    }
    pt.x = x;
    pt.y = y;
    [self->obj rotate:theta :pt];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject *pyROI_flipVertically(pyROIObject *self)
{
    [self->obj flipVertically:YES];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject *pyROI_flipHorizontally(pyROIObject *self)
{
    [self->obj flipVertically:NO];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject *pyROI_roiArea(pyROIObject *self)
{
    float area = [self->obj roiArea];
    PyObject *pyArea = PyFloat_FromDouble((double)area);
    return pyArea;
}

static PyMethodDef pyROIMethods[] =
{
    {"centroid", (PyCFunction)pyROI_centroid, METH_NOARGS, "Return the centroid of an ROI as a tuple in the format (x, y)"},
    {"roiMove", (PyCFunction)pyROI_roiMove, METH_VARARGS, "Move the ROI by distance x to the right and y upwards.  Usage: roi.roiMove(x, y)"},
    {"rotate", (PyCFunction)pyROI_rotate, METH_VARARGS, "Retate an ROI by specified amount t about point tuple (x,y).  Usage: roi.rotate(t, (x,y))"},
    {"flipVertically", (PyCFunction)pyROI_flipVertically, METH_NOARGS, "Flip the ROI vertically"},
    {"flipHorizontally", (PyCFunction)pyROI_flipHorizontally, METH_NOARGS, "Flip the ROI horizontally"},
    {"roiArea", (PyCFunction)pyROI_roiArea, METH_NOARGS, "Get the area of the ROI in unit of cm^2"},
    {NULL}
};

PyTypeObject pyROIType =
{
    PyObject_HEAD_INIT(NULL)
    0,
    "osirix.ROI",
    sizeof(pyROIObject),
    0,
    (destructor)pyROI_dealloc,
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
    "ROI objects",
    0,
    0,
    0,
    0,
    0,
    0,
    pyROIMethods,
    0,
    pyROI_getsetters,
    0,
    0,
    0,
    0,
    0,
    (initproc)pyROI_init,
    0,
    pyROI_new,
};

@implementation pyROI

+ (void)initTypeInModule:(PyObject *)module
{
    if (PyType_Ready(&pyROIType) < 0) {
        return;
    }
    Py_INCREF(&pyROIType);
    PyModule_AddObject(module, "ROI", (PyObject*)&pyROIType);
}

+ (NSDictionary *)toolsDictionary
{
    //Most of these aren't needed in this context but just in case...
    return [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithInt:tWL], @"tWL",
                          [NSNumber numberWithInt:tTranslate], @"tTranslate",
                          [NSNumber numberWithInt:tZoom], @"tZoom",
                          [NSNumber numberWithInt:tRotate], @"tRotate",
                          [NSNumber numberWithInt:tNext], @"tNext",
                          [NSNumber numberWithInt:tMesure], @"tMesure",
                          [NSNumber numberWithInt:tROI], @"tROI",
                          [NSNumber numberWithInt:t3DRotate], @"t3DRotate",
                          [NSNumber numberWithInt:tCross],@"tCross",
                          [NSNumber numberWithInt:tOval],@"tOval",
                          [NSNumber numberWithInt:tOPolygon],@"tOPolygon",
                          [NSNumber numberWithInt:tCPolygon],@"tCPolygon",
                          [NSNumber numberWithInt:tAngle],@"tAngle",
                          [NSNumber numberWithInt:tText],@"tText",
                          [NSNumber numberWithInt:tArrow],@"tArrow",
                          [NSNumber numberWithInt:tPencil],@"tPencil",
                          [NSNumber numberWithInt:t3Dpoint],@"t3Dpoint",
                          [NSNumber numberWithInt:t3DCut],@"t3DCut",
                          [NSNumber numberWithInt:tCamera3D],@"tCamera3D",
                          [NSNumber numberWithInt:t2DPoint],@"t2DPoint",
                          [NSNumber numberWithInt:tPlain],@"tPlain",
                          [NSNumber numberWithInt:tBonesRemoval],@"tBonesRemoval",
                          [NSNumber numberWithInt:tWLBlended],@"tWLBlended",
                          [NSNumber numberWithInt:tRepulsor],@"tRepulsor",
                          [NSNumber numberWithInt:tLayerROI],@"tLayerROI",
                          [NSNumber numberWithInt:tROISelector],@"tROISelector",
                          [NSNumber numberWithInt:tAxis],@"tAxis",
                          [NSNumber numberWithInt:tDynAngle],@"tDynAngle",
                          [NSNumber numberWithInt:tCurvedROI],@"tCurvedROI",
                          nil];
}

+ (PyObject *)pythonObjectWithInstance:(id)obj
{
    if ([obj class] != [ROI class]) {
        return NULL;
    }
    
    pyROIObject *o = PyObject_New(pyROIObject, &pyROIType);
    o->obj = [obj retain];
    return (PyObject *)o;
}

@end
