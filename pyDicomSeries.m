//
//  pyDicomSeries.m
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

#import "pyDicomSeries.h"
#import "pyDicomStudy.h"
#import "pyDicomImage.h"
#import <OsiriXAPI/DicomImage.h>
#import <OsiriXAPI/DicomStudy.h>
#include <Python/datetime.h>

# pragma mark -
# pragma mark pyDicomSeries initialization/deallocation

static void pyDicomSeries_dealloc(pyDicomSeriesObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

# pragma mark -
# pragma mark pyDicomSeriesObject str/repr

static PyObject *DicomSeries_str(pyDicomSeriesObject *self)
{
	NSString *str = [NSString stringWithFormat:@"DicomSeries object\nName: %@\nDate: %@\nModality:%@\nNumber of images:%@\n", [self->obj name], [self->obj date], [self->obj modality], [self->obj numberOfImages]];
	PyObject *ostr = PyString_FromString([str UTF8String]);
	if (ostr == NULL) {
		Py_INCREF(Py_None);
		return Py_None;
	}
	return ostr;
}

# pragma mark -
# pragma mark pyDicomSeries getters/setters

PyDoc_STRVAR(DicomSeriesStudyAttr_doc,
			 "The DicomStudy associated with the DicomSeries. This property cannot be set.\n"
			 );

static PyObject *pyDicomSeries_getStudy(pyDicomSeriesObject *self, void *closure)
{
    DicomStudy *study = [self->obj study];
    return [pyDicomStudy pythonObjectWithInstance:study];
}

PyDoc_STRVAR(DicomSeriesImagesAttr_doc,
			 "A tuple of DicomImages associated with the DicomSeries. This property cannot be set.\n"
			 );

static PyObject *pyDicomSeries_getImages(pyDicomSeriesObject *self, void *closure)
{
    NSSet *images = [self->obj images];
    if ([images count] == 0) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    PyObject *tup = PyTuple_New([images count]);
    int idx = 0;
    for (id im in images) {
        if ([im isKindOfClass:[DicomImage class]]) {
            PyObject *o = [pyDicomImage pythonObjectWithInstance:(DicomImage *)im];
            PyTuple_SetItem(tup, idx, o);
        }
        else
        {
            NSString *str = [NSString stringWithFormat:@"Invalid selection %@ encountered", [im className]];
            PyErr_SetString(PyExc_TypeError, [str UTF8String]);
            Py_DECREF(tup);
            return NULL;
        }
        idx++;
    }
    return tup;
}

PyDoc_STRVAR(DicomSeriesNumberOfImages_doc,
			 "The integer number of images in the DicomSeries. This property cannot be set.\n"
			 );

static PyObject *pyDicomSeries_getNumberOfImages(pyDicomSeriesObject *self, void *closure)
{
    NSNumber *num = [self->obj numberOfImages];
    return PyInt_FromLong([num longValue]);
}

PyDoc_STRVAR(DicomSeriesInstanceUIDAttr_doc,
			 "A string of the series UID for the DicomSeries. This property cannot be set.\n"
			 );

static PyObject *pyDicomSeries_getSeriesInstanceUID(pyDicomSeriesObject *self, void *closure)
{
    NSString *uid = [self->obj seriesInstanceUID];
    return PyString_FromString([uid UTF8String]);
}

PyDoc_STRVAR(DicomSeriesSOPClassUIDAttr_doc,
			 "A string of the series SOP class UID for the DicomSeries. This property cannot be set.\n"
			 );

static PyObject *pyDicomSeries_getSeriesSOPClassUID(pyDicomSeriesObject *self, void *closure)
{
    NSString *uid = [self->obj seriesSOPClassUID];
    return PyString_FromString([uid UTF8String]);
}

PyDoc_STRVAR(DicomSeriesDescriptionAttr_doc,
			 "A string of the series UID for the DicomSeries. This property cannot be set.\n"
			 );

static PyObject *pyDicomSeries_getSeriesDescription(pyDicomSeriesObject *self, void *closure)
{
    NSString *desc = [self->obj seriesDescription];
    return PyString_FromString([desc UTF8String]);
}

PyDoc_STRVAR(DicomSeriesModalityAttr_doc,
			 "A string of the DicomSeries modality. This property cannot be set.\n"
			 );

static PyObject *pyDicomSeries_getModality(pyDicomSeriesObject *self, void *closure)
{
    NSString *mod = [self->obj modality];
    return PyString_FromString([mod UTF8String]);
}

PyDoc_STRVAR(DicomSeriesNameAttr_doc,
			 "A string of the DicomSeries name. This property cannot be set.\n"
			 );

static PyObject *pyDicomSeries_getName(pyDicomSeriesObject *self, void *closure)
{
    NSString *name = [self->obj name];
    return PyString_FromString([name UTF8String]);
}

PyDoc_STRVAR(DicomSeriesDateAttr_doc,
			 "A date object for the DicomSeries. This property cannot be set.\n"
			 );

static PyObject *pyDicomSeries_getDate(pyDicomSeriesObject *self, void *closure)
{
    NSDate *date = [self->obj date];
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSCalendarUnitNanosecond | NSCalendarUnitSecond | NSCalendarUnitMinute | NSCalendarUnitHour | NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:date];
    PyObject * oDate = PyDateTime_FromDateAndTime((int)[comps year], (int)[comps month], (int)[comps day], (int)[comps hour], (int)[comps minute], (int)[comps second], (int)([comps nanosecond]*1000));
    return oDate;
}

static PyGetSetDef pyDicomSeries_getsetters[] =
{
    {"study", (getter)pyDicomSeries_getStudy, NULL, DicomSeriesStudyAttr_doc, NULL},
    {"images", (getter)pyDicomSeries_getImages, NULL, DicomSeriesImagesAttr_doc, NULL},
    {"numberOfImages", (getter)pyDicomSeries_getNumberOfImages, NULL, DicomSeriesNumberOfImages_doc, NULL},
    {"seriesInstanceUID", (getter)pyDicomSeries_getSeriesInstanceUID, NULL, DicomSeriesInstanceUIDAttr_doc, NULL},
    {"seriesSOPClassUID", (getter)pyDicomSeries_getSeriesSOPClassUID, NULL, DicomSeriesSOPClassUIDAttr_doc, NULL},
    {"seriesDescription", (getter)pyDicomSeries_getSeriesDescription, NULL, DicomSeriesDescriptionAttr_doc, NULL},
    {"modality", (getter)pyDicomSeries_getModality, NULL, DicomSeriesModalityAttr_doc, NULL},
    {"name", (getter)pyDicomSeries_getName, NULL, DicomSeriesNameAttr_doc, NULL},
    {"date", (getter)pyDicomSeries_getDate, NULL, DicomSeriesDateAttr_doc, NULL},
    {NULL}
};

# pragma mark -
# pragma mark pyDicomSeriesObject methods

PyDoc_STRVAR(DicomSeriesPaths_doc,
			 "\n"
			 "Returns a tuple containing the paths of all associated dicom files for the series.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: The filepaths to all associated dicom SOP instances.\n"
			 "\n"
			 );

static PyObject *pyDicomSeries_paths(pyDicomSeriesObject *self)
{
    NSSet *paths = [self->obj paths];
    if ([paths count] == 0) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    PyObject *tup = PyTuple_New([paths count]);
    int idx = 0;
    for (NSString *path in paths) {
        PyObject *oPath = PyString_FromString([path UTF8String]);
        PyTuple_SetItem(tup, idx, oPath);
        idx++;
    }
    return tup;
}

PyDoc_STRVAR(DicomSeriesPreviousSeries_doc,
			 "\n"
			 "Returns a reference to the previous series in the OsiriX browser.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    DicomSeries: See above.\n"
			 "\n"
			 );

static PyObject *pyDicomSeries_previousSeries(pyDicomSeriesObject *self)
{
    DicomSeries *series = [self->obj previousSeries];
    return [pyDicomSeries pythonObjectWithInstance:series];
}

PyDoc_STRVAR(DicomSeriesNextSeries_doc,
			 "\n"
			 "Returns a reference to the next series in the OsiriX browser.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    DicomSeries: See above.\n"
			 "\n"
			 );

static PyObject *pyDicomSeries_nextSeries(pyDicomSeriesObject *self)
{
    DicomSeries *series = [self->obj nextSeries];
    return [pyDicomSeries pythonObjectWithInstance:series];
}

// TODO - What does this do?
//static PyObject *pyDicomSeries_uniqueFilename(pyDicomSeriesObject *self)
//{
//    NSString *uniq = [self->obj uniqueFilename];
//    return PyString_FromString([uniq UTF8String]);
//}

PyDoc_STRVAR(DicomSeriesSortedImages_doc,
			 "\n"
			 "Returns a tuple of DicomImage instances sorted accorrding to the cirteria \n"
			 "currently set by the OsiriX browser.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: A tuple of DicomImage instances.\n"
			 "\n"
			 );

static PyObject *pyDicomSeries_sortedImages(pyDicomSeriesObject *self)
{
    NSArray *ims = [self->obj sortedImages];
    if ([ims count] == 0) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    PyObject *tup = PyTuple_New([ims count]);
    int idx = 0;
    for (DicomImage *im in ims) {
        PyObject *oIm = [pyDicomImage pythonObjectWithInstance:im];
        PyTuple_SetItem(tup, idx, oIm);
        idx++;
    }
    return tup;
}

static PyMethodDef pyDicomSeriesMethods[] =
{
    {"paths", (PyCFunction)pyDicomSeries_paths, METH_NOARGS, DicomSeriesPaths_doc},
    {"previousSeries", (PyCFunction)pyDicomSeries_previousSeries, METH_NOARGS, DicomSeriesPreviousSeries_doc},
    {"nextSeries", (PyCFunction)pyDicomSeries_nextSeries, METH_NOARGS, DicomSeriesNextSeries_doc},
    //{"uniqueFilename", (PyCFunction)pyDicomSeries_uniqueFilename, METH_NOARGS, "Get a string representing a unique filename for the series"},
    {"sortedImages", (PyCFunction)pyDicomSeries_sortedImages, METH_NOARGS, DicomSeriesSortedImages_doc},
    {NULL}
};

# pragma mark -
# pragma mark pyDicomSeriesType definition

PyDoc_STRVAR(DicomSeries_doc,
			 "A python implementation of the OsiriX 'DicomSeries' class.\n"
			 "DicomSeries is a convienience class used by the main browser within OsiriX to organise and group dicom instances within the same series.\n"
			 "Instances of this class may not be created.  Instead instances are accessed\n"
			 "via functions defined in the BrowserController class\n"
			 );

PyTypeObject pyDicomSeriesType =
{
    PyObject_HEAD_INIT(NULL)
    0,
    "osirix.DicomSeries",
    sizeof(pyDicomSeriesObject),
    0,
    (destructor)pyDicomSeries_dealloc,
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
    (reprfunc)DicomSeries_str,
    0,
    0,
    0,
    Py_TPFLAGS_DEFAULT,
    DicomSeries_doc,
    0,
    0,
    0,
    0,
    0,
    0,
    pyDicomSeriesMethods,
    0,
    pyDicomSeries_getsetters,
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
# pragma mark pyDicomSeries implementation

@implementation pyDicomSeries

+ (void)initTypeInModule:(PyObject *)module
{
    if (PyType_Ready(&pyDicomSeriesType) < 0) {
        return;
    }
    PyDateTime_IMPORT;
    Py_INCREF(&pyDicomSeriesType);
    PyModule_AddObject(module, "DicomSeries", (PyObject*)&pyDicomSeriesType);
}

+ (PyObject *)pythonObjectWithInstance:(id)obj
{
    if ([obj class] != [DicomSeries class]) {
        return NULL;
    }
    
    pyDicomSeriesObject *o = PyObject_New(pyDicomSeriesObject, &pyDicomSeriesType);
    o->obj = [obj retain];
    return (PyObject *)o;
}

@end
