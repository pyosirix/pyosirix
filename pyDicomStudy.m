//
//  pyDicomStudy.m
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

#import "pyDicomStudy.h"
#import "pyDicomImage.h"
#import "pyDicomSeries.h"
#import <OsiriXAPI/DicomImage.h>
#import <OsiriXAPI/Dicomseries.h>
#import <OsiriXAPI/DicomStudy.h>
#include <Python/datetime.h>

# pragma mark -
# pragma mark pyDicomStudy initialization/deallocation

static void pyDicomStudy_dealloc(pyDicomStudyObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

# pragma mark -
# pragma mark pyDicomStudyObject str/repr

static PyObject *DicomStudy_str(pyDicomStudyObject *self)
{
	NSString *str = [NSString stringWithFormat:@"DicomStudy object\nName: %@\nDate: %@\nModality:%@\nNumber of images:%@\n", [self->obj name], [self->obj date], [self->obj modality], [self->obj numberOfImages]];
	PyObject *ostr = PyString_FromString([str UTF8String]);
	if (ostr == NULL) {
		Py_INCREF(Py_None);
		return Py_None;
	}
	return ostr;
}

# pragma mark -
# pragma mark pyDicomStudyObject getters/setters

PyDoc_STRVAR(DicomStudyNumberOfImagesAttr_doc,
			 "The integer number of images contained by the DicomStudy. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getNumberOfImages(pyDicomStudyObject *self, void *closure)
{
    NSNumber *num = [self->obj numberOfImages];
    return PyInt_FromLong([num longValue]);
}

PyDoc_STRVAR(DicomStudySeriesAttr_doc,
			 "A tuple containing all DicomSeries within the DicomStudy. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getSeries(pyDicomStudyObject *self, void *closure)
{
    NSSet *series = [self->obj series];
    if ([series count] == 0) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    
    PyObject *oArr = PyTuple_New([series count]);
    int idx = 0;
    for (DicomSeries *serie in series) {
        PyTuple_SetItem(oArr, idx, [pyDicomSeries pythonObjectWithInstance:serie]);
        idx++;
    }
    
    return oArr;
}

PyDoc_STRVAR(DicomStudyNameAttr_doc,
			 "The patient name for DicomStudy as a string. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getName(pyDicomStudyObject *self, void *closure)
{
    NSString *name = [self->obj name];
    if (name == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyString_FromString([name UTF8String]);
}

PyDoc_STRVAR(DicomStudyDateAttr_doc,
			 "The date of the DicomStudy as a datetime object. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getDate(pyDicomStudyObject *self, void *closure)
{
    NSDate *date = [self->obj date];
    if (date == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSCalendarUnitNanosecond | NSCalendarUnitSecond | NSCalendarUnitMinute | NSCalendarUnitHour | NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:date];
    PyObject * oDate = PyDateTime_FromDateAndTime((int)[comps year], (int)[comps month], (int)[comps day], (int)[comps hour], (int)[comps minute], (int)[comps second], (int)([comps nanosecond]*1000));
    return oDate;
}

PyDoc_STRVAR(DicomStudyDateAddedAttr_doc,
			 "The date the DicomStudy was added to OsiriX as a datetime object. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getDateAdded(pyDicomStudyObject *self, void *closure)
{
    NSDate *date = [self->obj dateAdded];
    if (date == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSCalendarUnitNanosecond | NSCalendarUnitSecond | NSCalendarUnitMinute | NSCalendarUnitHour | NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:date];
    PyObject * oDate = PyDateTime_FromDateAndTime((int)[comps year], (int)[comps month], (int)[comps day], (int)[comps hour], (int)[comps minute], (int)[comps second], (int)([comps nanosecond]*1000));
    return oDate;
}

PyDoc_STRVAR(DicomStudyDateOfBirthAttr_doc,
			 "The patient DOB for the DicomStudy as a datetime object. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getDateOfBirth(pyDicomStudyObject *self, void *closure)
{
    NSDate *date = [self->obj dateOfBirth];
    if (date == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSCalendarUnitNanosecond | NSCalendarUnitSecond | NSCalendarUnitMinute | NSCalendarUnitHour | NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:date];
    PyObject * oDate = PyDateTime_FromDateAndTime((int)[comps year], (int)[comps month], (int)[comps day], (int)[comps hour], (int)[comps minute], (int)[comps second], (int)([comps nanosecond]*1000));
    return oDate;
}

PyDoc_STRVAR(DicomStudyInstitutionNameAttr_doc,
			 "The institution name of the DicomStudy as a string. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getInstitutionName(pyDicomStudyObject *self, void *closure)
{
    NSString *inst = [self->obj institutionName];
    if (inst == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyString_FromString([inst UTF8String]);
}

PyDoc_STRVAR(DicomStudyModalityAttr_doc,
			 "The modality of the DicomStudy as a string. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getModality(pyDicomStudyObject *self, void *closure)
{
    NSString *mod = [self->obj modality];
    if (mod == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyString_FromString([mod UTF8String]);
}

PyDoc_STRVAR(DicomStudyPatientIDAttr_doc,
			 "The patient ID of the DicomStudy as a string. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getPatientID(pyDicomStudyObject *self, void *closure)
{
    NSString *ID = [self->obj patientID];
    if (ID == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyString_FromString([ID UTF8String]);
}

PyDoc_STRVAR(DicomStudyPatientUIDAttr_doc,
			 "The patient UID of the DicomStudy as a string. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getPatientUID(pyDicomStudyObject *self, void *closure)
{
    NSString *UID = [self->obj patientUID];
    if (UID == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyString_FromString([UID UTF8String]);
}

PyDoc_STRVAR(DicomStudyPatientSexAttr_doc,
			 "The patient sex of the DicomStudy as a string. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getPatientSex(pyDicomStudyObject *self, void *closure)
{
    NSString *sex = [self->obj patientSex];
    if (sex == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyString_FromString([sex UTF8String]);
}

PyDoc_STRVAR(DicomStudyPerformingPhysicianAttr_doc,
			 "The name of the performing physician for the DicomStudy as a string. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getPerformingPhysician(pyDicomStudyObject *self, void *closure)
{
    NSString *pp = [self->obj performingPhysician];
    if (pp == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyString_FromString([pp UTF8String]);
}

PyDoc_STRVAR(DicomStudyReferringPhysicianAttr_doc,
			 "The name of the referring physician for the DicomStudy as a string. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getReferringPhysician(pyDicomStudyObject *self, void *closure)
{
    NSString *rp = [self->obj referringPhysician];
    if (rp == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyString_FromString([rp UTF8String]);
}

PyDoc_STRVAR(DicomStudyUIDAttr_doc,
			 "The DicomStudy UID as a string. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getStudyInstanceUID(pyDicomStudyObject *self, void *closure)
{
    NSString *UID = [self->obj studyInstanceUID];
    if (UID == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyString_FromString([UID UTF8String]);
}

PyDoc_STRVAR(DicomStudyStudyNameAttr_doc,
			 "The DicomStudy name as a string. This property cannot be set.\n"
			 );

static PyObject *pyDicomStudy_getStudyName(pyDicomStudyObject *self, void *closure)
{
    NSString *name = [self->obj studyName];
    if (name == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyString_FromString([name UTF8String]);
}

static PyGetSetDef pyDicomStudy_getsetters[] =
{
    {"numberOfImages", (getter)pyDicomStudy_getNumberOfImages, NULL, DicomStudyNumberOfImagesAttr_doc, NULL},
    {"series", (getter)pyDicomStudy_getSeries, NULL, DicomStudySeriesAttr_doc, NULL},
    {"name", (getter)pyDicomStudy_getName, NULL, DicomStudyNameAttr_doc, NULL},
    {"date", (getter)pyDicomStudy_getDate, NULL, DicomStudyDateAttr_doc, NULL},
    {"dateAdded", (getter)pyDicomStudy_getDateAdded, NULL, DicomStudyDateAddedAttr_doc, NULL},
    {"dateOfBirth", (getter)pyDicomStudy_getDateOfBirth, NULL, DicomStudyDateOfBirthAttr_doc, NULL},
    {"institutionName", (getter)pyDicomStudy_getInstitutionName, NULL, DicomStudyInstitutionNameAttr_doc, NULL},
    {"modality", (getter)pyDicomStudy_getModality, NULL, DicomStudyModalityAttr_doc, NULL},
    {"patientID", (getter)pyDicomStudy_getPatientID, NULL, DicomStudyPatientIDAttr_doc, NULL},
    {"patientUID", (getter)pyDicomStudy_getPatientUID, NULL, DicomStudyPatientUIDAttr_doc, NULL},
    {"patientSex", (getter)pyDicomStudy_getPatientSex, NULL, DicomStudyPatientSexAttr_doc, NULL},
    {"performingPhysician", (getter)pyDicomStudy_getPerformingPhysician, NULL, DicomStudyPerformingPhysicianAttr_doc, NULL},
    {"referringPhysician", (getter)pyDicomStudy_getReferringPhysician, NULL, DicomStudyReferringPhysicianAttr_doc, NULL},
    {"studyInstanceUID", (getter)pyDicomStudy_getStudyInstanceUID, NULL, DicomStudyUIDAttr_doc, NULL},
    {"studyName", (getter)pyDicomStudy_getStudyName, NULL, DicomStudyStudyNameAttr_doc, NULL},
    {NULL}
};

# pragma mark -
# pragma mark pyDicomStudyObject methods

PyDoc_STRVAR(DicomStudyPaths_doc,
			 "\n"
			 "Returns a tuple containing the paths of all associated dicom files for the study.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: The filepaths to all associated dicom SOP instances.\n"
			 "\n"
			 );

static PyObject *pyDicomStudy_paths(pyDicomStudyObject *self)
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

PyDoc_STRVAR(DicomStudyImages_doc,
			 "\n"
			 "Returns a tuple containing the DicomImages contained within the study.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: The DicomImage instances contained within the study.\n"
			 "\n"
			 );

static PyObject *pyDicomStudy_images(pyDicomStudyObject *self)
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

PyDoc_STRVAR(DicomStudyModalities_doc,
			 "\n"
			 "Returns a string with all modelities in the study.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    str: See above.\n"
			 "\n"
			 );

static PyObject *pyDicomStudy_modalities(pyDicomStudyObject *self)
{
    NSString *str = [self->obj modalities];
    if (str == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return PyString_FromString([str UTF8String]);
}

PyDoc_STRVAR(DicomStudyImageSeries_doc,
			 "\n"
			 "Returns a tuple containing the DicomSeries contained within the study.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: The DicomSeries instances contained within the study.\n"
			 "\n"
			 );

static PyObject *pyDicomStudy_imageSeries(pyDicomStudyObject *self)
{
    NSArray *series = [self->obj imageSeries];
    if ([series count] == 0) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    
    PyObject *oArr = PyTuple_New([series count]);
    int idx = 0;
    for (DicomSeries *serie in series) {
        PyTuple_SetItem(oArr, idx, [pyDicomSeries pythonObjectWithInstance:serie]);
        idx++;
    }
    
    return oArr;
}

PyDoc_STRVAR(DicomStudyNoFiles_doc,
			 "\n"
			 "Returns the number of dicom files associated with the study.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    int: See above.\n"
			 "\n"
			 );

static PyObject *pyDicomStudy_noFiles(pyDicomStudyObject *self)
{
    NSNumber *no = [self->obj noFiles];
    if (no == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    
    return PyInt_FromLong([no longValue]);
}

PyDoc_STRVAR(DicomStudyRawNoFiles_doc,
			 "\n"
			 "Returns the raw number of dicom files associated with the study.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    int: See above.\n"
			 "\n"
			 );

static PyObject *pyDicomStudy_rawNoFiles(pyDicomStudyObject *self)
{
    NSNumber *no = [self->obj rawNoFiles];
    if (no == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    
    return PyInt_FromLong([no longValue]);
}

PyDoc_STRVAR(DicomStudyNoFilesExcludingMultiframe_doc,
			 "\n"
			 "Returns the number of dicom files associated with the study, excluding any multiframe instances.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    int: See above.\n"
			 "\n"
			 );

static PyObject *pyDicomStudy_noFilesExcludingMultiFrames(pyDicomStudyObject *self)
{
    NSNumber *no = [self->obj noFilesExcludingMultiFrames];
    if (no == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    
    return PyInt_FromLong([no longValue]);
}

static PyMethodDef pyDicomStudyMethods[] =
{
    {"paths", (PyCFunction)pyDicomStudy_paths, METH_NOARGS, DicomStudyPaths_doc},
    {"images", (PyCFunction)pyDicomStudy_images, METH_NOARGS, DicomStudyImages_doc},
    {"modalities", (PyCFunction)pyDicomStudy_modalities, METH_NOARGS, DicomStudyModalities_doc},
    {"imageSeries", (PyCFunction)pyDicomStudy_imageSeries, METH_NOARGS, DicomStudyImageSeries_doc},
    {"noFiles", (PyCFunction)pyDicomStudy_noFiles, METH_NOARGS, DicomStudyNoFiles_doc},
    {"rawNoFiles", (PyCFunction)pyDicomStudy_rawNoFiles, METH_NOARGS, DicomStudyRawNoFiles_doc},
    {"noFilesExcludingMultiFrames", (PyCFunction)pyDicomStudy_noFilesExcludingMultiFrames, METH_NOARGS, DicomStudyNoFilesExcludingMultiframe_doc},
    {NULL}
};

# pragma mark -
# pragma mark pyDicomStudyType definition

PyDoc_STRVAR(DicomStudy_doc,
			 "A python implementation of the OsiriX 'DicomStudy' class.\n"
			 "DicomStudy is a convienience class used by the main browser within OsiriX to organise and group dicom instances within the same study.\n"
			 "Instances of this class may not be created.  Instead instances are accessed\n"
			 "via functions defined in the BrowserController class\n"
			 );

PyTypeObject pyDicomStudyType =
{
    PyObject_HEAD_INIT(NULL)
    0,
    "osirix.DicomStudy",
    sizeof(pyDicomStudyObject),
    0,
    (destructor)pyDicomStudy_dealloc,
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
    (reprfunc)DicomStudy_str,
    0,
    0,
    0,
    Py_TPFLAGS_DEFAULT,
    DicomStudy_doc,
    0,
    0,
    0,
    0,
    0,
    0,
    pyDicomStudyMethods,
    0,
    pyDicomStudy_getsetters,
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
# pragma mark pyDicomStudy implementation

@implementation pyDicomStudy

+ (void)initTypeInModule:(PyObject *)module
{
    if (PyType_Ready(&pyDicomStudyType) < 0) {
        return;
    }
    PyDateTime_IMPORT;
    Py_INCREF(&pyDicomStudyType);
    PyModule_AddObject(module, "DicomStudy", (PyObject*)&pyDicomStudyType);
}

+ (PyObject *)pythonObjectWithInstance:(id)obj
{
    if ([obj class] != [DicomStudy class]) {
        return NULL;
    }
    
    pyDicomStudyObject *o = PyObject_New(pyDicomStudyObject, &pyDicomStudyType);
    o->obj = [obj retain];
    return (PyObject *)o;
}

@end
