//
//  pyDicomImage.m
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

#import "pyDicomImage.h"
#import "pyDicomSeries.h"
#import <OsiriXAPI/DicomSeries.h>
#include <Python/datetime.h>

# pragma mark -
# pragma mark pyDicomImageObject initialization/deallocation

static void pyDicomImage_dealloc(pyDicomImageObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

# pragma mark -
# pragma mark pyDicomImageObject str/repr

static PyObject *pyDicomImage_str(pyDicomImageObject *self)
{
	NSString *str = [NSString stringWithFormat:@"DicomImage object\nDate: %@\nModality:%@\nInstance Number:%@\nNumber of frames:%@\nShape: (%@, %@)\n", [self->obj date], [self->obj modality], [self->obj instanceNumber], [self->obj numberOfFrames], [self->obj width], [self->obj height]];
	PyObject *ostr = PyString_FromString([str UTF8String]);
	if (ostr == NULL) {
		Py_INCREF(Py_None);
		return Py_None;
	}
	return ostr;
}

# pragma mark -
# pragma mark pyDicomImageObject getters/setters

PyDoc_STRVAR(DicomImageDateAttr_doc,
			 "The date of image acquisition. This property cannot be set.\n"
			 );

static PyObject *pyDicomImage_getDate(pyDicomImageObject *self, void *closure)
{
    NSDate *date = [self->obj date];
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSCalendarUnitNanosecond | NSCalendarUnitSecond | NSCalendarUnitMinute | NSCalendarUnitHour | NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:date];
   PyObject * oDate = PyDateTime_FromDateAndTime((int)[comps year], (int)[comps month], (int)[comps day], (int)[comps hour], (int)[comps minute], (int)[comps second], (int)([comps nanosecond]*1000));
    return oDate;
}

PyDoc_STRVAR(DicomImageNumberOfFramesAttr_doc,
			 "The integer number of frames contained within the associated dicom SOP instance. This property cannot be set.\n"
			 );

static PyObject *pyDicomImage_getNumberOfFrames(pyDicomImageObject *self, void *closure)
{
    NSNumber *frames = [self->obj numberOfFrames];
    return PyInt_FromLong([frames longValue]);
}

PyDoc_STRVAR(DicomImageModalityAttr_doc,
			 "The modality of the image in string representation. This property cannot be set.\n"
			 );

static PyObject *pyDicomImage_getModality(pyDicomImageObject *self, void *closure)
{
    NSString *modality = [self->obj modality];
    return PyString_FromString([modality UTF8String]);
}

PyDoc_STRVAR(DicomImageSeriesAttr_doc,
			 "Returns the DicomSeries associated with the DicomImage. This property cannot be set.\n"
			 );

static PyObject *pyDicomImage_getSeries(pyDicomImageObject *self, void *closure)
{
    DicomSeries *series = [self->obj series];
    return [pyDicomSeries pythonObjectWithInstance:series];
}

PyDoc_STRVAR(DicomImageSliceLocationAttr_doc,
			 "The floating-point slice location in patient coordinates. This property cannot be set.\n"
			 );

static PyObject *pyDicomImage_getSliceLocation(pyDicomImageObject *self, void *closure)
{
    NSNumber *loc = [self->obj sliceLocation];
    return PyFloat_FromDouble([loc doubleValue]);
}

PyDoc_STRVAR(DicomImageInstanceNumberAttr_doc,
			 "The integer instance number. This property cannot be set.\n"
			 );

static PyObject *pyDicomImage_getInstanceNumber(pyDicomImageObject *self, void *closure)
{
    NSNumber *num = [self->obj instanceNumber];
    return PyInt_FromLong([num longValue]);
}

static PyGetSetDef pyDicomImage_getsetters[] =
{
    {"date", (getter)pyDicomImage_getDate, NULL, DicomImageDateAttr_doc, NULL},
    {"numberOfFrames", (getter)pyDicomImage_getNumberOfFrames, NULL, DicomImageNumberOfFramesAttr_doc, NULL},
    {"modality", (getter)pyDicomImage_getModality, NULL, DicomImageModalityAttr_doc, NULL},
    {"series", (getter)pyDicomImage_getSeries, NULL, DicomImageSeriesAttr_doc, NULL},
    {"sliceLocation", (getter)pyDicomImage_getSliceLocation, NULL, DicomImageSliceLocationAttr_doc, NULL},
    {"instanceNumber", (getter)pyDicomImage_getInstanceNumber, NULL, DicomImageInstanceNumberAttr_doc, NULL},
    {NULL}
};

# pragma mark -
# pragma mark pyDicomImageObject methods

PyDoc_STRVAR(DicomImageWidth_doc,
			 "\n"
			 "The number of columns within the contained image.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    int: The number of columns.\n"
			 "\n"
			 );

static PyObject *pyDicomImage_width(pyDicomImageObject *self)
{
    NSNumber *width = [self->obj width];
    PyObject *w = NULL;
    if (width != nil) {
        w = PyInt_FromLong([width longValue]);
    }
    return w;
}

PyDoc_STRVAR(DicomImageHeight_doc,
			 "\n"
			 "The number of rows within the contained image.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    int: The number of rows.\n"
			 "\n"
			 );

static PyObject *pyDicomImage_height(pyDicomImageObject *self)
{
    NSNumber *height = [self->obj height];
    PyObject *h = NULL;
    if (height != nil) {
        h = PyInt_FromLong([height longValue]);
    }
    return h;
}

PyDoc_STRVAR(DicomImageSOPInstanceUID_doc,
			 "\n"
			 "The SOPInstance unique identifier of the image object represented as a string.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    str: The UID value represented by dicom tag (0008, 0018) .\n"
			 "\n"
			 );

static PyObject *pyDicomImage_sopInstanceUID(pyDicomImageObject *self)
{
    NSString *sop = [self->obj sopInstanceUID];
    PyObject *sop_str = NULL;
    if (sop != nil) {
        sop_str = PyString_FromString([sop UTF8String]);
    }
    return sop_str;
}

PyDoc_STRVAR(DicomImageCompletePath_doc,
			 "\n"
			 "The path of the associated dicom file.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    str: The path of dicom file conforming to RFC 1808.\n"
			 "\n"
			 );

static PyObject *pyDicomImage_completePath(pyDicomImageObject *self)
{
    NSString *cPath = [self->obj completePath];
    PyObject *cPath_str = NULL;
    if (cPath != nil) {
        cPath_str = PyString_FromString([cPath UTF8String]);
    }
    return cPath_str;
}

static PyMethodDef pyDicomImageMethods[] =
{
    {"width", (PyCFunction)pyDicomImage_width, METH_NOARGS, DicomImageWidth_doc},
    {"height", (PyCFunction)pyDicomImage_height, METH_NOARGS, DicomImageHeight_doc},
    {"sopInstanceUID", (PyCFunction)pyDicomImage_sopInstanceUID, METH_NOARGS, DicomImageSOPInstanceUID_doc},
    {"completePath", (PyCFunction)pyDicomImage_completePath, METH_NOARGS, DicomImageCompletePath_doc},
    {NULL}
};
# pragma mark -
# pragma mark pyDicomImageType definition

PyDoc_STRVAR(DicomImage_doc,
			 "A python implementation of the OsiriX 'DicomImage' class.\n"
			 "DicomImage is a convienience class used by the main browser within OsiriX to organise dicom instances.\n"
			 "Instances of this class should not be created.  Instead instances are accessed\n"
			 "via functions defined in the BrowserController class\n"
			 "\n"
			 "Example Usage:\n"
			 "    >>> import osirix"
			 "    >>> bc = osirix.currentBrowser()\n"
			 "    >>> seriesOrStudies = bc.databaseSelection()\n"
			 "    >>> images = seriesOrStudies.images\n"
			 "    >>> print images[0].completePath\n"
			 );

PyTypeObject pyDicomImageType =
{
    PyObject_HEAD_INIT(NULL)
    0,
    "osirix.DicomImage",
    sizeof(pyDicomImageObject),
    0,
    (destructor)pyDicomImage_dealloc,
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
    (reprfunc)pyDicomImage_str,
    0,
    0,
    0,
    Py_TPFLAGS_DEFAULT,
    DicomImage_doc,
    0,
    0,
    0,
    0,
    0,
    0,
    pyDicomImageMethods,
    0,
    pyDicomImage_getsetters,
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
# pragma mark pyDicomImage implementation

@implementation pyDicomImage

+ (void)initTypeInModule:(PyObject *)module
{
    if (PyType_Ready(&pyDicomImageType) < 0) {
        return;
    }
    Py_INCREF(&pyDicomImageType);
    PyDateTime_IMPORT;
    PyModule_AddObject(module, "DicomImage", (PyObject*)&pyDicomImageType);
}

+ (PyObject *)pythonObjectWithInstance:(id)obj
{
    if ([obj class] != [DicomImage class]) {
        return NULL;
    }
    
    pyDicomImageObject *o = PyObject_New(pyDicomImageObject, &pyDicomImageType);
    o->obj = [obj retain];
    return (PyObject *)o;
}

@end
