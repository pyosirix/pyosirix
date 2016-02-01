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
#import "pyROIVolume.h"

# pragma mark -
# pragma mark pyVRControllerObject initialization/deallocation

static void pyVRController_dealloc(pyVRControllerObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

# pragma mark -
# pragma mark pyVRControllerObject str/repr

static PyObject *pyVRController_str(pyVRControllerObject *self)
{
	NSString *str = [NSString stringWithFormat:@"VRController object\nTitle: %@\nRendering mode: %@\n", [[self->obj window] title], [self->obj renderingMode]];
	PyObject *ostr = PyString_FromString([str UTF8String]);
	if (ostr == NULL) {
		Py_INCREF(Py_None);
		return Py_None;
	}
	return ostr;
}

# pragma mark -
# pragma mark pyViewerControllerObject getters/setters

PyDoc_STRVAR(VRControllerRenderingModeAttr_doc,
			 "The rendering mode the ViewerController window as a string.\n"
			 "Must be one of two possible values: \"VR\" (volume rendering) or \"MIP\"."
			 );

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

PyDoc_STRVAR(VRControllerWLWWAttr_doc,
			 "The windowing level and windowing width of the VRController as a float tuple in the format (wl, ww)."
			 );

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

PyDoc_STRVAR(VRControllerStyleAttr_doc,
			 "The style of the VRController window (either \"panel\" or \"standard\"). This property cannot be set."
			 );

static PyObject *pyVRController_getStyle(pyVRControllerObject *self, void *closure)
{
    NSString *st = [self->obj style];
    return PyString_FromString([st UTF8String]);
}

PyDoc_STRVAR(VRControllerTitleAttr_doc,
			 "The string title of the VRController window. This property cannot be set."
			 );

static PyObject *pyVRController_getTitle(pyVRControllerObject *self, void *closure)
{
    NSString *title = [[self->obj window] title];
    return PyString_FromString([title UTF8String]);
}

static PyGetSetDef pyVRController_getsetters[] =
{
    {"renderingMode", (getter)pyVRController_renderingMode, (setter) pyVRController_setRenderingMode, VRControllerRenderingModeAttr_doc, NULL},
    {"WLWW", (getter)pyVRController_getWLWW, (setter)pyVRController_setWLWW, VRControllerWLWWAttr_doc, NULL},
    {"style", (getter)pyVRController_getStyle, NULL, VRControllerStyleAttr_doc, NULL},
    {"title", (getter)pyVRController_getTitle, NULL, VRControllerTitleAttr_doc, NULL},
    {NULL}
};

PyDoc_STRVAR(VRControllerViewer2D_doc,
			 "\n"
			 "Return the ViewerController instance containing the original data currently displayed.\n"
			 "\n"
			 "Args:\n"
			 "    None\n"
			 "\n"
			 "Returns:\n"
			 "    ViewerController: The associated OsiriX 2D viewer window.\n"
			 );

static PyObject *pyVRController_viewer2D(pyVRControllerObject *self)
{
    ViewerController *vc = [self->obj viewer2D];
    return [pyViewerController pythonObjectWithInstance:vc];
}

PyDoc_STRVAR(VRControllerBlendingController_doc,
			 "\n"
			 "If the data is fused, return the ViewerController instance containing the fused image data.\n"
			 "\n"
			 "Args:\n"
			 "    None\n"
			 "\n"
			 "Returns:\n"
			 "    ViewerController: The fused OsiriX 2D viewer window if available.  Set to 'None' if no fusion active.\n"
			 );

static PyObject *pyVRController_blendingController(pyVRControllerObject *self)
{
    ViewerController *bvc = [self->obj blendingController];
    if (bvc == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    return [pyViewerController pythonObjectWithInstance:bvc];
}

//PyDoc_STRVAR(VRControllerROIVolumes_doc,
//			 "\n"
//			 "Returns a tuple of the ROIVolumes in the current movie index of the VRController.\n"
//			 "Note: The name of a ROIVolumes matches the ROIs that created it.\n"
//			 "These can be accessed via the ViewerController instance.\n"
//			 "\n"
//			 "Args:\n"
//			 "    None.\n"
//			 "\n"
//			 "Returns:\n"
//			 "    tuple: A tuple with each element containing a ROIVolume instance.\n"
//			 "\n"
//			 "Example:\n"
//			 "    >>> import osirix\n"
//			 "    >>> vrc = osirix.frontmostVRController()\n"
//			 "    >>> roiVols = vrc.roiVolumes()\n"
//			 "    >>> firstVol = roiVols[0]\n"
//			 "    >>> name = firstVol.name\n"
//			 "    >>> vc = vrc.viewer2D()\n"
//			 "    >>> correspondingROIs = vc.roisWithName(name)\n"
//			 );
//
//static PyObject *pyVRController_roiVolumes(pyVRControllerObject *self)
//{
//    NSMutableArray *vols = [self->obj roiVolumes];
//	if ([vols count] == 0) {
//		Py_INCREF(Py_None);
//        return Py_None;
//	}
//    
//	PyObject *pyVols = PyTuple_New([vols count]);
//    for (int i = 0; i < [vols count]; i++)
//        PyTuple_SetItem(pyVols, i, [pyROIVolume pythonObjectWithInstance:[vols objectAtIndex:i]]);
//	
//    return pyVols;
//}
//
//PyDoc_STRVAR(VRControllerComputeROIVolumes_doc,
//			 "\n"
//			 "Refresh the list of ROI volumes contained within the VRContoller.\n"
//			 "\n"
//			 "Args:\n"
//			 "    None.\n"
//			 "\n"
//			 "Returns:\n"
//			 "    None.\n"
//			 );
//
//static PyObject *pyVRController_computeROIVolumes(pyVRControllerObject *self)
//{
//    [self->obj computeROIVolumes];
//	Py_INCREF(Py_None);
//	return Py_None;
//}
//
//PyDoc_STRVAR(VRControllerDisplayROIVolumes_doc,
//			 "\n"
//			 "Display the ROI volumes contained within the VRContoller.\n"
//			 "\n"
//			 "Args:\n"
//			 "    None.\n"
//			 "\n"
//			 "Returns:\n"
//			 "    None.\n"
//			 );
//
//static PyObject *pyVRController_displayROIVolumes(pyVRControllerObject *self)
//{
//    [self->obj displayROIVolumes];
//	Py_INCREF(Py_None);
//	return Py_None;
//}

static PyMethodDef pyVRControllerMethods[] =
{
    {"viewer2D", (PyCFunction)pyVRController_viewer2D, METH_NOARGS, VRControllerViewer2D_doc},
    {"blendingController", (PyCFunction)pyVRController_blendingController, METH_NOARGS, VRControllerBlendingController_doc},
//	{"roiVolumes", (PyCFunction)pyVRController_roiVolumes, METH_NOARGS, VRControllerROIVolumes_doc},
//	{"computeROIVolumes", (PyCFunction)pyVRController_computeROIVolumes, METH_NOARGS, VRControllerComputeROIVolumes_doc},
//	{"displayROIVolumes", (PyCFunction)pyVRController_displayROIVolumes, METH_NOARGS, VRControllerDisplayROIVolumes_doc},
    {NULL}
};

# pragma mark -
# pragma mark pyVRControllerType definition

PyDoc_STRVAR(VRController_doc,
			 "A python implementation of the OsiriX 'VRController' class.\n"
			 "This class is used to obtain limited access to some of the volume rendering window properties.\n"
			 "Instances of this class may not be created.  Instead instances are accessed\n"
			 "via functions defined in the osirix module\n"
			 "\n"
			 "Example Usage:\n"
			 "    >>> import osirix\n"
			 "    >>> vrc = osirix.frontmostVRController()\n"
			 "    >>> print vrc.title\n"
			 );

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
    (reprfunc)pyVRController_str,
    0,
    0,
    0,
    Py_TPFLAGS_DEFAULT,
    VRController_doc,
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

# pragma mark -
# pragma mark pyVRController implementation

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
