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

static void pyDicomSeries_dealloc(pyDicomSeriesObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

static PyObject *pyDicomSeries_getStudy(pyDicomSeriesObject *self, void *closure)
{
    DicomStudy *study = [self->obj study];
    return [pyDicomStudy pythonObjectWithInstance:study];
}

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

static PyObject *pyDicomSeries_getNumberOfImages(pyDicomSeriesObject *self, void *closure)
{
    NSNumber *num = [self->obj numberOfImages];
    return PyInt_FromLong([num longValue]);
}

static PyObject *pyDicomSeries_getSeriesInstanceUID(pyDicomSeriesObject *self, void *closure)
{
    NSString *uid = [self->obj seriesInstanceUID];
    return PyString_FromString([uid UTF8String]);
}

static PyObject *pyDicomSeries_getSeriesSOPClassUID(pyDicomSeriesObject *self, void *closure)
{
    NSString *uid = [self->obj seriesSOPClassUID];
    return PyString_FromString([uid UTF8String]);
}

static PyObject *pyDicomSeries_getSeriesDescription(pyDicomSeriesObject *self, void *closure)
{
    NSString *desc = [self->obj seriesDescription];
    return PyString_FromString([desc UTF8String]);
}

static PyObject *pyDicomSeries_getModality(pyDicomSeriesObject *self, void *closure)
{
    NSString *mod = [self->obj modality];
    return PyString_FromString([mod UTF8String]);
}

static PyObject *pyDicomSeries_getName(pyDicomSeriesObject *self, void *closure)
{
    NSString *name = [self->obj name];
    return PyString_FromString([name UTF8String]);
}

static PyObject *pyDicomSeries_getDate(pyDicomSeriesObject *self, void *closure)
{
    NSDate *date = [self->obj date];
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSCalendarUnitNanosecond | NSCalendarUnitSecond | NSCalendarUnitMinute | NSCalendarUnitHour | NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:date];
    PyObject * oDate = PyDateTime_FromDateAndTime((int)[comps year], (int)[comps month], (int)[comps day], (int)[comps hour], (int)[comps minute], (int)[comps second], (int)([comps nanosecond]*1000));
    return oDate;
}

static PyGetSetDef pyDicomSeries_getsetters[] =
{
    {"study", (getter)pyDicomSeries_getStudy, NULL, "The DicomStudy to which the series belongs", NULL},
    {"images", (getter)pyDicomSeries_getImages, NULL, "The DicomImages that are contained by the series", NULL},
    {"numberOfImages", (getter)pyDicomSeries_getNumberOfImages, NULL, "The number of DicomImages that are contained by the series", NULL},
    {"seriesInstanceUID", (getter)pyDicomSeries_getSeriesInstanceUID, NULL, "The series instance UID as a string value", NULL},
    {"seriesSOPClassUID", (getter)pyDicomSeries_getSeriesSOPClassUID, NULL, "The series SOP class UID as a string value", NULL},
    {"seriesDescription", (getter)pyDicomSeries_getSeriesDescription, NULL, "The series description", NULL},
    {"modality", (getter)pyDicomSeries_getModality, NULL, "The series modality", NULL},
    {"name", (getter)pyDicomSeries_getName, NULL, "The series name", NULL},
    {"date", (getter)pyDicomSeries_getDate, NULL, "A datetime.datetime object referenceing the date and time of the DicomSeries", NULL},
    {NULL}
};

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

static PyObject *pyDicomSeries_previousSeries(pyDicomSeriesObject *self)
{
    DicomSeries *series = [self->obj previousSeries];
    return [pyDicomSeries pythonObjectWithInstance:series];
}

static PyObject *pyDicomSeries_nextSeries(pyDicomSeriesObject *self)
{
    DicomSeries *series = [self->obj nextSeries];
    return [pyDicomSeries pythonObjectWithInstance:series];
}

static PyObject *pyDicomSeries_uniqueFilename(pyDicomSeriesObject *self)
{
    NSString *uniq = [self->obj uniqueFilename];
    return PyString_FromString([uniq UTF8String]);
}

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
    {"paths", (PyCFunction)pyDicomSeries_paths, METH_NOARGS, "Get a tuple of complete paths for the  contained DicomImages"},
    {"previousSeries", (PyCFunction)pyDicomSeries_previousSeries, METH_NOARGS, "Get the previous DicomSeries instance in the browser"},
    {"nextSeries", (PyCFunction)pyDicomSeries_nextSeries, METH_NOARGS, "Get the next DicomSeries instance in the browser"},
    {"uniqueFilename", (PyCFunction)pyDicomSeries_uniqueFilename, METH_NOARGS, "Get a string representing a unique filename for the series"},
    {"sortedImages", (PyCFunction)pyDicomSeries_sortedImages, METH_NOARGS, "Return a tuple of DicomImages sorted by slice location"},
    {NULL}
};

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
    0,
    0,
    0,
    0,
    Py_TPFLAGS_DEFAULT,
    "DicomSeries objects",
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
