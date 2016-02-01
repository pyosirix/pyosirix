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

# pragma mark -
# pragma mark pyROIObject initialization/deallocation

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
    static char *kwlist[] = {"itype", "buffer", "position", "DCMPix", "name", "ipixelSpacing", "iimageOrigin", NULL};
    
    char * roiType = "tCPolygon";
    float iSpx = 1.0;
    float iSpy = 1.0;
    float iOrx = 0.0;
    float iOry = 0.0;
    PyObject *dcmRef = NULL;
    char *name = "Un-named ROI";
    PyObject *buffer = NULL;
    int posX = 0;
    int posY = 0;
    
    init_numpy_ROI();
    if (!PyArg_ParseTupleAndKeywords(args, kwds, "|sO!(ii)O!s(ff)(ff)", kwlist, &roiType, &PyArray_Type, &buffer, &posX, &posY, &pyDCMPixType, &dcmRef, &name, &iSpx, &iSpy, &iOrx, &iOry))
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
    
    return 0;
}

# pragma mark -
# pragma mark pyROIObject str/repr

static PyObject *pyROI_str(pyROIObject *self)
{
	NSString *str = [NSString stringWithFormat:@"ROI object (Name: %@)\n", [self->obj name]];
	PyObject *ostr = PyString_FromString([str UTF8String]);
	if (ostr == NULL) {
		Py_INCREF(Py_None);
		return Py_None;
	}
	return ostr;
}

# pragma mark -
# pragma mark pyROIObject getters/setters

PyDoc_STRVAR(ROITypeAttr_doc,
			 "A string representing the ROI type.\n"
			 "This property cannot be set.\n"
			 );

static PyObject *pyROI_getType(pyROIObject *self, void *closure)
{
    ROI *roi = self->obj;
    long t = [roi type];
    NSString *type = [pyROI toolTypeDescriptionForNumber:[NSNumber numberWithLong:t]];
	PyObject *pyStr;
	if (type != nil)
		pyStr = PyString_FromString([type UTF8String]);
	else {
		Py_INCREF(Py_None);
		pyStr = Py_None;
	}
    return pyStr;
}

PyDoc_STRVAR(ROIThicknessAttr_doc,
			 "A float value for the thickness of the ROI.\n"
			 );

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

PyDoc_STRVAR(ROIOpacityAttr_doc,
			 "A float value for the opacity of the ROI.\n"
			 "Must be within the range 0.0 -> 1.0.\n"
			 );

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

PyDoc_STRVAR(ROIColorAttr_doc,
			 "A three element (R, G, B) tuple representing the ROI color.\n"
			 "Each element must be an integer in the range 0 -> 255.\n"
			 );

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

PyDoc_STRVAR(ROINameAttr_doc,
			 "A string representing the name of the ROI.\n"
			 );

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

PyDoc_STRVAR(ROIPixAttr_doc,
			 "The DCMPix instance associated with the ROI.\n"
			 "This property cannot be set.\n"
			 );

static PyObject *pyROI_getPix(pyROIObject *self, void *closure)
{
    DCMPix *pix = [self->obj pix];
    PyObject *pyPix = [pyDCMPix pythonObjectWithInstance:pix];
    return pyPix;
}

PyDoc_STRVAR(ROIPointsAttr_doc,
			 "A numpy float array with shape [N, 2] for N points in the ROI.\n"
			 "Setting this property fro some ROI types result in a no-op.\n"
			 );

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
    {"type", (getter)pyROI_getType, NULL, ROITypeAttr_doc, NULL},
    {"thickness", (getter)pyROI_getThickness, (setter)pyROI_setThickness, ROIThicknessAttr_doc, NULL},
    {"opacity", (getter)pyROI_getOpacity, (setter)pyROI_setOpacity, ROIOpacityAttr_doc, NULL},
    {"color", (getter)pyROI_getColor, (setter)pyROI_setColor, ROIColorAttr_doc, NULL},
    {"name", (getter)pyROI_getName, (setter)pyROI_setName, ROINameAttr_doc, NULL},
    {"pix", (getter)pyROI_getPix, NULL, ROIPixAttr_doc, NULL},
    {"points", (getter)pyROI_getPoints, (setter)pyROI_setPoints, ROIPointsAttr_doc, NULL},
    {NULL}
};

# pragma mark -
# pragma mark pyROIObject methods

PyDoc_STRVAR(ROICentroid_doc,
			 "\n"
			 "Returns a two-element tuple representing the centroid of the ROI.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: A 2-element tuple representing the ROI centroid in the form: \n"
			 "           (rows, columns)\n"
			 );

static PyObject *pyROI_centroid(pyROIObject *self)
{
    NSPoint pt = [self->obj centroid];
    PyObject *pyPt = PyTuple_New(2);
    PyTuple_SetItem(pyPt, 0, PyFloat_FromDouble((double)pt.x));
    PyTuple_SetItem(pyPt, 1, PyFloat_FromDouble((double)pt.y));
    return pyPt;
}

PyDoc_STRVAR(ROIMove_doc,
			 "\n"
			 "Move the ROI by a specified number of pixels in the image plane.\n"
			 "\n"
			 "Args:\n"
			 "    c (float): The number of columns to move the ROI.  Positive values move left -> right.\n"
			 "    r (float): The number of rows to move the ROI.  Positive values move up -> down.\n"
			 "\n"
			 "Returns:\n"
			 "    None.\n"
			 "\n"
			 "Example:\n"
			 "    >>> import osirix\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> selectedROI = vc.selectedROIs()[0]\n"
			 "    >>> selectedROI.moveROI(1.0, 1.0)\n"
			 "    >>> vc.needsDisplayUpdate()\n"
			 );

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

PyDoc_STRVAR(ROIRotate_doc,
			 "\n"
			 "Rotate the ROI by a specified angle about a point (x, y) in the image plane.\n"
			 "Note: This method is a no-op for brush ROIs.\n"
			 "\n"
			 "Args:\n"
			 "    theta (float): The angle (in degrees) by which to rotate the ROI.\n"
			 "    pt (tuple): A 2-element tuple of float values representing the point about which to rotate the ROI.\n"
			 "                The order of the tuple should be (columns, rows).\n"
			 "\n"
			 "Returns:\n"
			 "    None.\n"
			 "\n"
			 "Example:\n"
			 "    >>> import osirix\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> selectedROI = vc.selectedROIs()[0]\n"
			 "    >>> c = selectedROI.centroid()\n"
			 "    >>> selectedROI.rotate(90.0, c) #Rotate an ROI 90 degrees about its center of mass\n"
			 "    >>> vc.needsDisplayUpdate()\n"
			 );

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

PyDoc_STRVAR(ROIFlipVertically_doc,
			 "\n"
			 "Flip the ROI vertically.\n"
			 "Note: This method is a no-op for brush ROIs.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    None.\n"
			 );

static PyObject *pyROI_flipVertically(pyROIObject *self)
{
    [self->obj flipVertically:YES];
    Py_INCREF(Py_None);
    return Py_None;
}

PyDoc_STRVAR(ROIFlipHorizontally_doc,
			 "\n"
			 "Flip the ROI horizontally.\n"
			 "Note: This method is a no-op for brush ROIs.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    None.\n"
			 );

static PyObject *pyROI_flipHorizontally(pyROIObject *self)
{
    [self->obj flipVertically:NO];
    Py_INCREF(Py_None);
    return Py_None;
}

PyDoc_STRVAR(ROIArea_doc,
			 "\n"
			 "Return the area with the ROI.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    float: The area within the ROI in units of cm^2.\n"
			 );

static PyObject *pyROI_roiArea(pyROIObject *self)
{
    float area = [self->obj roiArea];
    PyObject *pyArea = PyFloat_FromDouble((double)area);
    return pyArea;
}

static PyMethodDef pyROIMethods[] =
{
    {"centroid", (PyCFunction)pyROI_centroid, METH_NOARGS, ROICentroid_doc},
    {"roiMove", (PyCFunction)pyROI_roiMove, METH_VARARGS, ROIMove_doc},
    {"rotate", (PyCFunction)pyROI_rotate, METH_VARARGS, ROIRotate_doc},
    {"flipVertically", (PyCFunction)pyROI_flipVertically, METH_NOARGS, ROIFlipVertically_doc},
    {"flipHorizontally", (PyCFunction)pyROI_flipHorizontally, METH_NOARGS, ROIFlipHorizontally_doc},
    {"roiArea", (PyCFunction)pyROI_roiArea, METH_NOARGS, ROIArea_doc},
    {NULL}
};

# pragma mark -
# pragma mark pyROIType definition

PyDoc_STRVAR(ROI_doc,
			 "A python implementation of the OsiriX 'ROI' class.\n"
			 "Instances of this class can be created with the following signature:\n"
			 "    osirix.ROI(*args)\n"
			 "\n"
			 "Args:\n"
			 "    itype (Optional[str]): The type of ROI to create.  Currently can only be none of\n"
			 "           tPlain, tCPolygon (default), tOPolygon, tPencil.\n"
			 "    buffer (npy_array): A 2D numpy boolean array representing pixels contained with the ROI.\n"
			 "            This keyword is required if ROI type is tPlain and must not be specified otherwise.\n"
			 "    origin (Optional[tuple]): The position of the top-left most pixel of the ROI buffer.\n"
			 "    DCMPix (Optional[DCMPix]): A DCMPix instance from which to extract tha arguments ipixelSpacing \n"
			 "                               and iimageOrigin.\n"
			 "    name (Optional[str]): The name of the ROI (defaults to \"Un-named ROI\").\n"
			 "    ipixelSpacing (Optional[tuple]): A 2-element tuple, (x, y), with the pixel spacing of the image \n"
			 "                                     to which the ROI will be associated. Ignored if DCMPix is set.\n"
			 "    iimageOrigin (Optional[tuple]): A 2-element tuple, (x, y), with the position of the top-left image pixel\n"
			 "                                     to which the ROI will be associated. Ignored if DCMPix is set.\n"
			 "\n"
			 "Example Usage:\n"
			 "    >>> import osirix\n"
			 "    >>> import numpy as np\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> pix = vc.curDCM()\n"
			 "    >>> newROI = osirix.ROI(itype = \"tPencil\", name = \"square-ish ROI\")\n"
			 "    >>> newROI.points = np.array([[10.0, 10.0], [20.0, 10.0], [20.0, 20.0], [10.0, 20.0]])\n"
			 "    >>> newROI.thickness = 4.0\n"
			 "    >>> newROI.color = (255, 0, 255)\n"
			 "    >>> newROI.opacity = 0.7\n"
			 "    >>> vc.setROI(newROI)\n"
			 "    >>> vc.needsDisplayUpdate()\n"
			 );

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
    (reprfunc)pyROI_str,
    0,
    0,
    0,
    Py_TPFLAGS_DEFAULT,
    ROI_doc,
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

# pragma mark -
# pragma mark pyROI implementation

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

+ (NSString *)toolTypeDescriptionForNumber:(NSNumber *)num
{
	NSDictionary *roiTypes = [pyROI toolsDictionary];
	NSArray *keys = [roiTypes allKeys];
	for (NSString *key in keys) {
		if ([[roiTypes valueForKey:key] isEqualToNumber:num]) {
			return key;
		}
	}
	return nil;
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
