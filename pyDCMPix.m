//
//  pyDCMPix.m
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

#import "pyDCMPix.h"
#include <arrayobject.h>
#import "pyROI.h"
#import "pyDicomImage.h"
#import "pyDicomSeries.h"
#import "pyDicomStudy.h"
#import <OsiriXAPI/DCMView.h>
#import <OsiriXAPI/DicomImage.h>
#import <OsiriXAPI/DicomSeries.h>
#import <OsiriXAPI/DicomStudy.h>

# pragma mark -
# pragma mark pyViewerControllerObject initialization/deallocation

static void pyDCMPix_dealloc(pyDCMPixObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

static PyObject *pyDCMPix_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    pyDCMPixObject *self = (pyDCMPixObject *)type->tp_alloc(type, 0);
    if (self != NULL) {
        char * fileStr;
        int bOK = PyArg_ParseTuple(args, "s", &fileStr);
        if (!bOK) {
            return NULL;
        }
        self->obj = [[DCMPix alloc] initWithContentsOfFile:[NSString stringWithUTF8String:fileStr]];
    }
    return (PyObject *)self;
}

void init_numpy_DCMPix()
{
    import_array();
}

# pragma mark -
# pragma mark pyDCMPixObject str/repr

static PyObject *pyDCMPix_str(pyDCMPixObject *self)
{
	NSString *str = [NSString stringWithFormat:@"DCMPix object\nShape: (%ld, %ld)\n%@ image type (%@)\nLocation: %f\nSource file: %@\n", [self->obj pwidth], [self->obj pheight], ([self->obj isRGB]?@"RGBA":@"Grayscale"), ([self->obj isRGB]?@"byte":@"int32"), [self->obj sliceLocation], [self->obj sourceFile]];
	PyObject *ostr = PyString_FromString([str UTF8String]);
	if (ostr == NULL) {
		Py_INCREF(Py_None);
		return Py_None;
	}
	return ostr;
}

# pragma mark -
# pragma mark pyViewerControllerObject getters/setters

PyDoc_STRVAR(DCMPixImageAttr_doc,
			 "A numpy array represeting the pixel data stored by the DCMPix instance.\n"
			 "For BW DCMPix instances, the array has shape [columns, rows] and is 32-bit floating point ('int32').\n"
			 "For RGB DCMPix insatnces, the resulting array has shape [4, columns, rows] with the first dimension\n"
			 "providing the RGBA values as an 8-bit unsigned byte array at each pixel location ('byte').\n"
			 "When setting the image array, the array dimensions must not change.\n"
			 "Conversion should be achieved via explicit numpy conversion ('int32' for BW and 'byte' for RGBA).\n"
			 "\n"
			 "Example:\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> pix = vc.curDCM()\n"
			 "    >>> im = pix.image\n"
			 "    >>> pix.image = (2.0*im).astype('int32') #Multiply image by 2!\n"
			 );

static PyArrayObject *pyDCMPix_getImage(pyDCMPixObject *self, void *closure)
{
    DCMPix *pix = self->obj;
    long w = [pix pwidth];
    long h = [pix pheight];
    
    init_numpy_DCMPix();
    PyArrayObject *image = NULL;
    if (![pix isRGB]) {
        npy_intp dims[2] = {w,h};
        npy_intp strides[2] = {sizeof(float), w*sizeof(float)};
        image = (PyArrayObject *)PyArray_New(&PyArray_Type, 2, dims, NPY_FLOAT, strides, NULL, sizeof(float), NPY_ARRAY_CARRAY, NULL);
        float * data = (float *)PyArray_DATA(image);
        float *osirixData = [pix fImage];
        memcpy(data, osirixData, w*h*sizeof(float));
    }
    else
    {
        npy_intp dims[3] = {4,w,h};
        npy_intp strides[3] = {sizeof(unsigned char), 4*sizeof(unsigned char), 4*w*sizeof(unsigned char)};
        image = (PyArrayObject *)PyArray_New(&PyArray_Type, 3, dims, NPY_UBYTE, strides, NULL, sizeof(unsigned char), NPY_ARRAY_CARRAY, NULL);
        float *data = (float *)PyArray_DATA(image);
        unsigned char *osirixData = (unsigned char *)[pix fImage];
        memcpy(data, osirixData, 4*w*h*sizeof(char));
    }
    return image;
}

static int pyDCMPix_setImage(pyDCMPixObject *self, PyObject *input, void *closure)
{
    DCMPix *pix = self->obj;
    int h = [pix pheight];
    int w = [pix pwidth];
    
    init_numpy_DCMPix();
    if (!PyArray_EnsureArray(input))
    {
        PyErr_SetString(PyExc_ValueError, "Input is not a numpy array!");
        return -1;
    }
    
    PyArrayObject *image = (PyArrayObject *)input;
    int nd = PyArray_NDIM(image);
    npy_intp *dims = PyArray_DIMS(image);
    int type = (int)PyArray_TYPE(image);
    if (![pix isRGB]) {
        if (nd != 2)
        {
            NSString *err = [NSString stringWithFormat:@"Grayscale DCMPix image must have shape [%d, %d]", w, h];
            PyErr_SetString(PyExc_ValueError, [err UTF8String]);
            return -1;
        }
        if (dims[0] != w || dims[1] != h)
        {
            NSString *err = [NSString stringWithFormat:@"Grayscale DCMPix image must have shape [%d, %d]", w, h];
            PyErr_SetString(PyExc_ValueError, [err UTF8String]);
            return -1;
        }
        if (type == NPY_FLOAT)
        {
            float *data = [pix fImage];
            for (int i = 0; i < w; i++) {
                for (int j = 0; j < h; j++) {
                    float *valPtr = (float *)PyArray_GETPTR2(image, i, j);
                    data[i + w*j] = *valPtr;
                }
            }
        }
        else
        {
            NSString *err = [NSString stringWithFormat:@"Grayscale DCMPix image must be 32-bit float type. Please convert the array using arr.astype('float32')."];
            PyErr_SetString(PyExc_ValueError, [err UTF8String]);
            return -1;
        }
        
    }
    else {
        if (nd != 3)
        {
            NSString *err = [NSString stringWithFormat:@"RGB DCMPix image must have shape [4, %d, %d]", w, h];
            PyErr_SetString(PyExc_ValueError, [err UTF8String]);
            return -1;
        }
        if (dims[0] != 4 || dims[1] != w || dims[2] != h)
        {
            NSString *err = [NSString stringWithFormat:@"RGB DCMPix image must have shape [4, %d, %d]", w, h];
            PyErr_SetString(PyExc_ValueError, [err UTF8String]);
            return -1;
        }
        if (type == NPY_UBYTE)
        {
            unsigned char *data = (unsigned char *)[pix fImage];
            for (int i = 0; i < 4; i++) {
                for (int j = 0; j < w; j++) {
                    for (int k = 0; k < h; k++) {
                        unsigned char *valPtr = (unsigned char *)PyArray_GETPTR3(image, i, j, k);
                        data[i + 4*j + 4*w*k] = *valPtr;
                    }
                }
            }
        }
        else
        {
            NSString *err = [NSString stringWithFormat:@"RGB DCMPix image must be 8-bit unsigned byte type. Please convert the array using arr.astype('ubyte')."];
            PyErr_SetString(PyExc_ValueError, [err UTF8String]);
            return -1;
        }
    }

    return 0;
}

PyDoc_STRVAR(DCMPixShapeAttr_doc,
			 "A tuple representing the shape of the contained image data in the form:\n"
			 "    (width, height).\n"
			 "This property cannot be set.\n"
			 );

static PyObject *pyDCMPix_getShape(pyDCMPixObject *self, void *closure)
{
    long w = [self->obj pwidth];
    long h = [self->obj pheight];
    PyObject *ret = PyTuple_New(2);
    PyTuple_SetItem(ret, 0, PyInt_FromLong(w));
    PyTuple_SetItem(ret, 1, PyInt_FromLong(h));
    return ret;
}

PyDoc_STRVAR(DCMPixPixelSpacingAttr_doc,
			 "A tuple representing the pixelSpacing of the contained image data in the form:\n"
			 "    (col. spacing, row spacing)\n"
			 "This property cannot be set.\n"
			 );

static PyObject *pyDCMPix_getPixelSpacing(pyDCMPixObject *self, void *closure)
{
    double spX = [self->obj pixelSpacingX];
    double spY = [self->obj pixelSpacingY];
    PyObject *ret = PyTuple_New(2);
    PyTuple_SetItem(ret, 0, PyFloat_FromDouble(spX));
    PyTuple_SetItem(ret, 1, PyFloat_FromDouble(spY));
    return ret;
}

PyDoc_STRVAR(DCMPixOriginAttr_doc,
			 "A tuple representing the origin of the top-left pixel of the image in patient coordinates.\n"
			 "Returned in the form:\n"
			 "    (x, y, z)\n"
			 "This property cannot be set.\n"
			 );

static PyObject *pyDCMPix_getOrigin(pyDCMPixObject *self, void *closure)
{
    double orX = [self->obj originX];
    double orY = [self->obj originY];
    double orZ = [self->obj originZ];
    PyObject *ret = PyTuple_New(3);
    PyTuple_SetItem(ret, 0, PyFloat_FromDouble(orX));
    PyTuple_SetItem(ret, 1, PyFloat_FromDouble(orY));
    PyTuple_SetItem(ret, 2, PyFloat_FromDouble(orZ));
    return ret;
}

PyDoc_STRVAR(DCMPixSliceLocationAttr_doc,
			 "A float representing the slice-location of the image in patient coordinates.\n"
			 "This property cannot be set.\n"
			 );

static PyObject *pyDCMPix_getSliceLocation(pyDCMPixObject *self, void *closure)
{
    double sL = [self->obj sliceLocation];
    return PyFloat_FromDouble(sL);
}

PyDoc_STRVAR(DCMPixSourceFileAttr_doc,
			 "A string providing the location of the source dicom file.\n"
			 "This property cannot be set.\n"
			 );

static PyObject *pyDCMPix_getSourceFile(pyDCMPixObject *self, void *closure)
{
    NSString *fl = [self->obj sourceFile];
    return PyString_FromString([fl UTF8String]);
}

PyDoc_STRVAR(DCMPixOrientationAttr_doc,
			 "A 9-element tuple providing the orientation of the image as defined by the dicom standard.\n"
			 "See dicom element (0020, 0037) and descriptions provided by the standard: http://dicom.nema.org\n"
			 "This property cannot be set.\n"
			 );

static PyObject *pyDCMPix_getOrientation(pyDCMPixObject *self, void *closure)
{
    double or[9];
    [self->obj orientationDouble:or];
    PyObject *orObj = PyTuple_New(9);
    for (int i = 0; i < 9; i++)
        PyTuple_SetItem(orObj, i, PyFloat_FromDouble(or[i]));
    return orObj;
}

PyDoc_STRVAR(DCMPixIsRGBAttr_doc,
			 "A bool determining whether the DCMPix instance represents a grayscale image or RGBA.\n"
			 "This property cannot be set.\n"
			 );

static PyObject *pyDCMPix_getIsRGB(pyDCMPixObject *self, void *closure)
{
    long y = [self->obj isRGB] ? 1 : 0;
    PyObject *ret = PyBool_FromLong(y);
    return ret;
}

static PyGetSetDef pyDCMPix_getsetters[] =
{
    {"image", (getter)pyDCMPix_getImage, (setter)pyDCMPix_setImage, DCMPixImageAttr_doc, NULL},
    {"shape", (getter)pyDCMPix_getShape, NULL, DCMPixShapeAttr_doc, NULL},
    {"pixelSpacing", (getter)pyDCMPix_getPixelSpacing, NULL, DCMPixPixelSpacingAttr_doc, NULL},
    {"origin", (getter)pyDCMPix_getOrigin, NULL, DCMPixOriginAttr_doc, NULL},
    {"location", (getter)pyDCMPix_getSliceLocation, NULL, DCMPixSliceLocationAttr_doc, NULL},
    {"sourceFile", (getter)pyDCMPix_getSourceFile, NULL, DCMPixSourceFileAttr_doc, NULL},
    {"orientation", (getter)pyDCMPix_getOrientation, NULL, DCMPixOrientationAttr_doc, NULL},
    {"isRGB", (getter)pyDCMPix_getIsRGB, NULL, DCMPixIsRGBAttr_doc, NULL},
    {NULL}
};

# pragma mark -
# pragma mark pyDCMPixObject methods

PyDoc_STRVAR(DCMPixComputeROI_doc,
			 "\n"
			 "Returns a tuple of statistics for the pixel values within a given ROI.\n"
			 "\n"
			 "Args:\n"
			 "    ROI: The ROI from within which to compute the image statistics.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: The ROI statitics provided in the format\n"
			 "           (mean, total, st. dev., min., max., skewness, kurtosis)\n"
			 );

static PyObject *pyDCMPix_computeROI(pyDCMPixObject *self, PyObject *args)
{
    short bOK = 1;
    if (!(PyTuple_Size(args) == 1))
        bOK = 0;
    if (!pyROI_CheckExact(PyTuple_GetItem(args, 0)))
        bOK = 0;
    if (!bOK)
    {
        PyErr_SetString(PyExc_TypeError, "Input must be an ROI type");
        return NULL;
    }
    
    ROI *roi = ((pyROIObject*)PyTuple_GetItem(args, 0))->obj;
    DCMPix *pix = self->obj;
    float mean, total, dev, max, min, kurtosis, skewness;
    [pix computeROI:roi :&mean :&total :&dev :&min :&max :&skewness :&kurtosis];
    PyObject *ret = PyTuple_New(7);
    PyTuple_SetItem(ret, 0, PyFloat_FromDouble((double)mean));
    PyTuple_SetItem(ret, 1, PyFloat_FromDouble((double)total));
    PyTuple_SetItem(ret, 2, PyFloat_FromDouble((double)dev));
    PyTuple_SetItem(ret, 3, PyFloat_FromDouble((double)min));
    PyTuple_SetItem(ret, 4, PyFloat_FromDouble((double)max));
    PyTuple_SetItem(ret, 5, PyFloat_FromDouble((double)skewness));
    PyTuple_SetItem(ret, 6, PyFloat_FromDouble((double)kurtosis));
    return ret;
}

PyDoc_STRVAR(DCMPixGetROIValues_doc,
			 "\n"
			 "Provides the pixel values within a given ROI\n"
			 "\n"
			 "Args:\n"
			 "    ROI: The ROI from within which to provide the image values.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: A two-element tuple containing numpy arrays of the pixel values and their locations in the form (row, col) \n"
			 "\n"
			 "Example:\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> pix = vc.curDCM()\n"
			 "    >>> roi = pix.selectedROIs()[0]\n"
			 "    >>> vals, locs = pix.getROIValues(roi)\n"
			 "    >>> print \"ROI mean = \", np.mean(vals)\n"
			 );

static PyObject *pyDCMPix_getROIValues(pyDCMPixObject *self, PyObject *args)
{
    PyObject *pyRoi;
    
    if (!PyArg_ParseTuple(args, "O!", &pyROIType, &pyRoi)) {
        return NULL;
    }
	
	if ([self->obj isRGB]) {
		PyErr_SetString(PyExc_TypeError, "Cannot currently provide pixel values for RGBA images!");
		return NULL;
	}
    
    ROI *roi = ((pyROIObject *)pyRoi)->obj;
    DCMPix *pix = self->obj;
    
    float *locs;
    long no;
    float *vals = [pix getROIValue:&no :roi :&locs];
    
    init_numpy_DCMPix();
    
    PyArrayObject *valsArr = NULL;
    npy_intp valsDims[1] = {no};
    npy_intp valsStrides[1] = {sizeof(float)};
    valsArr = (PyArrayObject *)PyArray_New(&PyArray_Type, 1, valsDims, NPY_FLOAT, valsStrides, NULL, sizeof(float), NPY_ARRAY_CARRAY, NULL);
    float *valsData = (float *)PyArray_DATA(valsArr);
    memcpy(valsData, vals, no*sizeof(float));
    free(vals);
    
    PyArrayObject *locsArr = NULL;
    npy_intp locsDims[2] = {no, 2};
    npy_intp locsStrides[2] = {2*sizeof(float), sizeof(float)};
    locsArr = (PyArrayObject *)PyArray_New(&PyArray_Type, 2, locsDims, NPY_FLOAT, locsStrides, NULL, sizeof(float), NPY_ARRAY_CARRAY, NULL);
    float *locsData = (float *)PyArray_DATA(locsArr);
    memcpy(locsData, locs, no*2*sizeof(float));
    free(locs);
    
    
    PyObject *ret = PyTuple_New(2);
    PyTuple_SetItem(ret, 0, (PyObject *)valsArr);
    PyTuple_SetItem(ret, 1, (PyObject *)locsArr);
    
    return ret;
}

PyDoc_STRVAR(DCMPixGetMapFromROI_doc,
			 "\n"
			 "Provides a mask for the image representing regions within a given ROI.\n"
			 "\n"
			 "Args:\n"
			 "    ROI: The ROI from which to compute the mask.\n"
			 "\n"
			 "Returns:\n"
			 "    Numpy array (bool): A numpy array with the same dimensions as the contained image. \n"
			 "    Elements with value 'True' represnet regions within the ROI.\n"
			 );

static PyObject *pyDCMPix_getMapFromROI(pyDCMPixObject *self, PyObject *args)
{
    PyObject *pyRoi;
    if (!PyArg_ParseTuple(args, "O!", &pyROIType, &pyRoi)) {
        return NULL;
    }
    
    ROI *roi = ((pyROIObject *)pyRoi)->obj;
    DCMPix *pix = self->obj;
    
    NSSize s;
    NSPoint o;
    unsigned char* texture;
    
    BOOL freeTexture = NO;
    if ([roi type] == tPlain) {
        texture = [roi textureBuffer];
        s.width = [roi textureWidth];
        s.height = [roi textureHeight];
        o.x = [roi textureUpLeftCornerX];
        o.y = [roi textureUpLeftCornerY];
    }
    else
    {
        texture = [DCMPix getMapFromPolygonROI: roi size: &s origin: &o];
        freeTexture = YES;
    }
    
    int w = [pix pwidth];
    int h = [pix pheight];
    
    long ucharsz = sizeof(unsigned char);
    unsigned char *tempMask = calloc(w*h, ucharsz);
    for (int i = 0; i < h; i++) {
        for (int j = 0; j < w; j++) {
            if((i-o.y)>=0 && (j-o.x)>=0 && i<(o.y+s.height) && j<(o.x+s.width))
            {
                int idx = (i-o.y)*s.width + (j-o.x);
                tempMask[j + i*w] = texture[idx] == 0xff ? (unsigned char)1 : (unsigned char)0;
            }
        }
    }
    
    init_numpy_DCMPix();
    PyArrayObject *mask = NULL;
    npy_intp dims[2] = {w, h};
    npy_intp strides[2] = {ucharsz, w*ucharsz};
    
    mask = (PyArrayObject *)PyArray_New(&PyArray_Type, 2, dims, NPY_BOOL, strides, NULL, ucharsz, NPY_ARRAY_CARRAY, NULL);
    float *maskData = (float *)PyArray_DATA(mask);
    memcpy(maskData, tempMask, w*h*ucharsz);
    free(tempMask);
    
    if (freeTexture)
        free(texture);
    
    return (PyObject *)mask;
}

PyDoc_STRVAR(DCMPixConvertToRGB_doc,
			 "\n"
			 "Convert the contained pixel data from a grayscale (int32) array to RGBA (byte)\n"
			 "\n"
			 "Args:\n"
			 "    type (Optional[int]): Convert greyscale values to:\n"
			 "                          0: Red\n"
			 "                          1: Green\n"
			 "                          2: Blue\n"
			 "                          0: BW\n"
			 "\n"
			 "Returns:\n"
			 "    None. \n"
			 "\n"
			 );

static PyObject *pyDCMPix_convertToRGB(pyDCMPixObject *self, PyObject *args)
{
    int type = 3;
    if (!PyArg_ParseTuple(args, "|i", &type)) {
        return NULL;
    }
    
    if (type < 0 || type > 3) {
        PyErr_SetString(PyExc_ValueError, "RGB type can be one of: 0-red, 1-green, 2-blue, 3-BW");
        return NULL;
    }
	
	if ([self->obj isRGB]) {
		PyErr_SetString(PyExc_Warning, "DCMPix is already in RGBA format!");
        return NULL;
	}
    
    float cwl, cww;
    float min = FLT_MAX, max = FLT_MIN;
    float *im = [self->obj fImage];
    for (int i = 0; i < [self->obj pwidth]*[self->obj pheight]; i++) {
        min = im[i] < min ? im[i] : min;
        max = im[i] > max ? im[i] : max;
    }
    cwl = (min + max)/2;
    cww = max - min;
    
    [self->obj ConvertToRGB:type : (long)cwl: (long)cww];
    
    Py_INCREF(Py_None);
    return Py_None;
}

PyDoc_STRVAR(DCMPixConvertToBW_doc,
			 "\n"
			 "Convert the contained pixel data from an RGBA (byte) array to grayscale (byte).\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    None. \n"
			 "\n"
			 );

static PyObject *pyDCMPix_convertToBW(pyDCMPixObject *self, PyObject *args)
{
    int type = 3;
    if (!PyArg_ParseTuple(args, "|i", &type)) {
        return NULL;
    }
    
    if (type < 0 || type > 3) {
        PyErr_SetString(PyExc_ValueError, "BW type can be one of: 0-red, 1-green, 2-blue, 3-BW");
        return NULL;
    }
    
    [self->obj ConvertToBW:type];
    
    Py_INCREF(Py_None);
    return Py_None;
}

PyDoc_STRVAR(DCMPixImageObj_doc,
			 "\n"
			 "Provides the instance of the associated DicomImage stored by the OsiriX browser.\n"
			 "\n"
			 "Args:\n"
			 "    None. \n"
			 "\n"
			 "Returns:\n"
			 "    DicomImage\n"
			 "\n"
			 );

static PyObject *pyDCMPix_imageObj(pyDCMPixObject *self)
{
    DicomImage *im = [self->obj imageObj];
    return [pyDicomImage pythonObjectWithInstance:im];
}

PyDoc_STRVAR(DCMPixSeriesObj_doc,
			 "\n"
			 "Provides the instance of the associated DicomSeries stored by the OsiriX browser.\n"
			 "\n"
			 "Args:\n"
			 "    None. \n"
			 "\n"
			 "Returns:\n"
			 "    DicomSeries\n"
			 "\n"
			 );

static PyObject *pyDCMPix_seriresObj(pyDCMPixObject *self)
{
    DicomSeries *se = [self->obj seriesObj];
    return [pyDicomSeries pythonObjectWithInstance:se];
}

PyDoc_STRVAR(DCMPixStudyObj_doc,
			 "\n"
			 "Provides the instance of the associated DicomStudy stored by the OsiriX browser.\n"
			 "\n"
			 "Args:\n"
			 "    None. \n"
			 "\n"
			 "Returns:\n"
			 "    DicomStudy\n"
			 "\n"
			 );

static PyObject *pyDCMPix_studyObj(pyDCMPixObject *self)
{
    DicomStudy *st = [self->obj studyObj];
    return [pyDicomStudy pythonObjectWithInstance:st];
}

static PyMethodDef pyDCMPixMethods[] =
{
    {"computeROI", (PyCFunction)pyDCMPix_computeROI, METH_VARARGS, DCMPixComputeROI_doc},
    {"getROIValues", (PyCFunction)pyDCMPix_getROIValues, METH_VARARGS, DCMPixGetROIValues_doc},
    {"getMapFromROI", (PyCFunction)pyDCMPix_getMapFromROI, METH_VARARGS, DCMPixGetMapFromROI_doc},
    {"convertToRGB", (PyCFunction)pyDCMPix_convertToRGB, METH_VARARGS, DCMPixConvertToRGB_doc},
    {"convertToBW", (PyCFunction)pyDCMPix_convertToBW, METH_VARARGS, DCMPixConvertToBW_doc},
    {"imageObj", (PyCFunction)pyDCMPix_imageObj, METH_NOARGS, DCMPixImageObj_doc},
    {"seriesObj", (PyCFunction)pyDCMPix_seriresObj, METH_NOARGS, DCMPixSeriesObj_doc},
    {"studyObj", (PyCFunction)pyDCMPix_studyObj, METH_NOARGS, DCMPixStudyObj_doc},
    {NULL}
};

# pragma mark -
# pragma mark pyDCMPixType definition

PyDoc_STRVAR(DCMPix_doc,
			 "A python implementation of the OsiriX 'DCMPix' class.\n"
			 "A seperate DCMPix instance is stored for each image displayed by the OsiriX 2D viewer.\n"
			 "Instances of this class should not be created.  Instead instances are accessed\n"
			 "via functions defined in the ViewerContoller class\n"
			 "\n"
			 "Example Usage:\n"
			 "    >>> import osirix"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> dcmPixList = vc.pixList(0)\n"
			 "    >>> dcmPix = dcmPixLIst[0]\n"
			 "    >>> print dcmPix.shape\n"
			 );

PyTypeObject pyDCMPixType =
{
    PyObject_HEAD_INIT(NULL)
    0,
    "osirix.DCMPix",
    sizeof(pyDCMPixObject),
    0,
    (destructor)pyDCMPix_dealloc,
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
    (reprfunc)pyDCMPix_str,
    0,
    0,
    0,
    Py_TPFLAGS_DEFAULT,
    DCMPix_doc,
    0,
    0,
    0,
    0,
    0,
    0,
    pyDCMPixMethods,
    0,
    pyDCMPix_getsetters,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    pyDCMPix_new,
};

# pragma mark -
# pragma mark pyDCMPix implementation

@implementation pyDCMPix

+ (void)initTypeInModule:(PyObject *)module
{
    if (PyType_Ready(&pyDCMPixType) < 0) {
        return;
    }
    Py_INCREF(&pyDCMPixType);
    PyModule_AddObject(module, "DCMPix", (PyObject*)&pyDCMPixType);
}

+ (PyObject *)pythonObjectWithInstance:(id)obj
{
    if ([obj class] != [DCMPix class]) {
        return NULL;
    }
    
    pyDCMPixObject *o = PyObject_New(pyDCMPixObject, &pyDCMPixType);
    o->obj = [obj retain];
    return (PyObject *)o;
}

@end
