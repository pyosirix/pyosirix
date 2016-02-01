//
//  pyViewerController.m
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

#import "pyViewerController.h"
#import <OsiriXAPI/Wait.h>
#import <OsiriXAPI/DCMView.h>
#import <OsiriXAPI/AppController.h>
#import "pyDCMPix.h"
#import "pyWait.h"
#import "pyROI.h"
#import "pyVRController.h"

# pragma mark -
# pragma mark pyViewerControllerObject initialization/deallocation

static void pyViewerController_dealloc(pyViewerControllerObject *self)
{
    [self->obj release];
    self->ob_type->tp_free(self);
}

# pragma mark -
# pragma mark pyViewerControllerObject str/repr

static PyObject *pyViewerController_str(pyViewerControllerObject *self)
{
	NSString *str = [NSString stringWithFormat:@"ViewerController object\nTitle: %@\nNumber frames: %d\nCurrent movie index: %d\nNumber images: %d\nCurrent frame:%d\nModality: %@\n", [[self->obj window] title], [self->obj maxMovieIndex], [self->obj curMovieIndex], (int)[[self->obj pixList:0] count], [(DCMView *)[self->obj imageView] curImage], [self->obj modality]];
	PyObject *ostr = PyString_FromString([str UTF8String]);
	if (ostr == NULL) {
		Py_INCREF(Py_None);
		return Py_None;
	}
	return ostr;
}

# pragma mark -
# pragma mark pyViewerControllerObject getters/setters

PyDoc_STRVAR(viewerControllerTitleAttr_doc,
			 "The string title of the ViewerController window."
			 );

static PyObject *pyViewerController_getTitle(pyViewerControllerObject *self, void *closure)
{
    NSString *name = [[self->obj window] title];
    PyObject *pyName = PyString_FromString([name UTF8String]);
    return pyName;
}

static int pyViewerController_setTitle(pyViewerControllerObject *self, PyObject *value, void *closure)
{
    if (!PyString_Check(value)) {
        PyErr_SetString(PyExc_TypeError,
                        "The title attribute value must be a string");
        return -1;
    }
    char * name = PyString_AsString(value);
    [[self->obj window] setTitle:[NSString stringWithUTF8String:name]];
    [self->obj needsDisplayUpdate];
    return 0;
}

PyDoc_STRVAR(viewerControllerMovieIdxAttr_doc,
			 "The current 4D index of the ViewerController as an integer."
			 );

static PyObject *pyViewerController_getMovieIdx(pyViewerControllerObject *self, void *closure)
{
    short idx = [self->obj curMovieIndex];
    PyObject *pyIdx = PyInt_FromLong((long)idx);
    return pyIdx;
}

static int pyViewerController_setMovieIdx(pyViewerControllerObject *self, PyObject *value, void *closure)
{
    unsigned short idx;
    if (!PyArg_Parse(value, "H", &idx)) {
        return -1;
    }
    [self->obj setMovieIndex:idx];
    [self->obj needsDisplayUpdate];
    return 0;
}

PyDoc_STRVAR(viewerControllerIdxAttr_doc,
			 "The current image index of the ViewerController as an integer."
			 );

static PyObject *pyViewerController_getIdx(pyViewerControllerObject *self, void *closure)
{
    short idx = [(DCMView *)[self->obj imageView] curImage] ;
    PyObject *pyIdx = PyInt_FromLong((long)idx);
    return pyIdx;
}

static int pyViewerController_setIdx(pyViewerControllerObject *self, PyObject *value, void *closure)
{
    unsigned short idx;
    if (!PyArg_Parse(value, "H", &idx)) {
        return -1;
    }
    [[self->obj imageView] setIndex:idx];
    [self->obj needsDisplayUpdate];
    return 0;
}

PyDoc_STRVAR(viewerControllerWLWWAttr_doc,
			 "The current WLWW settings of the ViewerController as an tuple of floats (WL, WW)."
			 );

static PyObject *pyViewerController_getWLWW(pyVRControllerObject *self, void *closure)
{
    float wl, ww;
    [[(ViewerController *)self->obj imageView]  getWLWW:&wl :&ww];
    PyObject *owl = PyFloat_FromDouble((double)wl);
    PyObject *oww = PyFloat_FromDouble((double)ww);
    PyObject *owlww = PyTuple_New(2);
    PyTuple_SetItem(owlww, 0, owl); //Reference stolen
    PyTuple_SetItem(owlww, 1, oww); //Reference stolen
    return owlww;
}

static int pyViewerController_setWLWW(pyVRControllerObject *self, PyObject *value, void *closure)
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
    [[(ViewerController *)self->obj imageView] setWLWW:wl :ww];
    return 0;
}

PyDoc_STRVAR(viewerControllerModalityAttr_doc,
			 "A string representation of the viewed image modality.  This property cannot be set."
			 );

static PyObject *pyViewerController_getModality(pyViewerControllerObject *self, void *closure)
{
    return PyString_FromString([[self->obj modality] UTF8String]);
}

static PyGetSetDef pyViewerController_getsetters[] =
{
    {"title", (getter)pyViewerController_getTitle, (setter)pyViewerController_setTitle, viewerControllerTitleAttr_doc, NULL},
    {"movieIdx", (getter)pyViewerController_getMovieIdx, (setter)pyViewerController_setMovieIdx, viewerControllerMovieIdxAttr_doc, NULL},
    {"idx", (getter)pyViewerController_getIdx, (setter)pyViewerController_setIdx, viewerControllerIdxAttr_doc, NULL},
    {"WLWW", (getter)pyViewerController_getWLWW, (setter)pyViewerController_setWLWW, viewerControllerWLWWAttr_doc, NULL},
    {"modality", (getter)pyViewerController_getModality, NULL, viewerControllerModalityAttr_doc, NULL},
    {NULL}
};

# pragma mark -
# pragma mark pyViewerControllerObject methods

PyDoc_STRVAR(viewerControllerMaxMovieIdx_doc,
			 "\n"
			 "Return the number of 4D viewer frames contained within the ViewerController .\n"
			 "\n"
			 "Args:\n"
			 "    None\n"
			 "\n"
			 "Returns:\n"
			 "    int: The number of 4D movie frames.\n"
			 );

static PyObject *pyViewerController_maxMovieIdx(pyViewerControllerObject *self)
{
    short max = [self->obj maxMovieIndex];
    PyObject *o = PyInt_FromLong((long)max);
    return o;
}

PyDoc_STRVAR(viewerControllerCloseViewer_doc,
			 "\n"
			 "Close the ViewerController instance.\n"
			 "Note: To truly destroy the ViewerController, it should also be deletd via del().\n"
			 "\n"
			 "Args:\n"
			 "   None\n"
			 "\n"
			 "Returns:\n"
			 "    None.\n"
			 );

static PyObject *pyViewerController_closeViewer(pyViewerControllerObject *self, PyObject *args)
{
    //Not really sure we need this but just for demo
    [self->obj CloseViewerNotification:[NSNotification notificationWithName:@"Python Close" object:nil]];
    Py_INCREF(Py_None);
    return Py_None;
}

PyDoc_STRVAR(viewerControllerPixList_doc,
			 "\n"
			 "Provides a tuple containing the DCMPix objects represented in the ViewerController.\n"
			 "\n"
			 "Args:\n"
			 "   movieIdx (Optional[int]): The 4D index (starts at 0) from which to obtain the tuple of DCMPix instances.\n"
			 "                             Defaults to the currently displayed frame.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: A tuple with each element containing a DCMPix instance.\n"
			 "\n"
			 "Example:\n"
			 "    >>> #Obtain the DCMPix tuple for the first frame of the frontmost ViewerController\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> pix = vc.pixList(movieIdx = 0)\n"
			 );

static PyObject *pyViewerConroller_pixList(pyViewerControllerObject *self, PyObject *args, PyObject *kwds)
{
    int movieIdx = [self->obj curMovieIndex];
	static char *kwlist[] = {"movieIdx", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, kwds, "|i", kwlist, &movieIdx))
		return NULL;
    
    NSMutableArray *pix = [self->obj pixList:movieIdx];
    PyObject *pixTuple = PyTuple_New([pix count]);
    for (int i = 0; i < [pix count]; i++) {
        PyTuple_SetItem(pixTuple, i, [pyDCMPix pythonObjectWithInstance:[pix objectAtIndex:i]]);
    }
    return pixTuple;
}

PyDoc_STRVAR(viewerControllerStartWaitProgressWindow_doc,
			 "\n"
			 "Starts a progress bar window with a given message and maximum number of steps.\n"
			 "\n"
			 "Args:\n"
			 "    message (str): The message to display in the progress window\n"
			 "    max (int): The maximum number of incremental steps to use until the bar is full.\n"
			 "\n"
			 "Returns:\n"
			 "    Wait: An insatce of the Wait class that can be used fro progress management.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> w = vc.startWaitProgressWindow(\"Counting 1, 2, ..., 100\", 100)\n"
			 "    >>> for i in range(100):\n"
			 "    >>>     doSomething(...)\n"
			 "    >>>     w.incrementBy(1.0)\n"
			 "    >>> vc.endWaitWindow(w)\n"
			 );

static PyObject *pyViewerController_startWaitProgressWindow(pyViewerControllerObject *self, PyObject *args)
{
    char *str;
    int max;
    if (!PyArg_ParseTuple(args, "si", &str, &max)) {
        return NULL;
    }
    
    Wait *w = [self->obj startWaitProgressWindow:[NSString stringWithUTF8String:str] :(long)max];
    PyObject *ow = [pyWait pythonObjectWithInstance:w];
    return ow;
}

//static PyObject *pyViewerController_startWaitWindow(pyViewerControllerObject *self, PyObject *args)
//{
//    char *str;
//    if (!PyArg_ParseTuple(args, "s", &str)) {
//        return NULL;
//    }
//    
//    Wait *w = [self->obj startWaitWindow:[NSString stringWithUTF8String:str]];
//    PyObject *ow = [pyWait pythonObjectWithInstance:w];
//    return ow;
//}

PyDoc_STRVAR(viewerControllerEndWaitWindow_doc,
			 "\n"
			 "Ends a progress window and closes it.\n"
			 "\n"
			 "Args:\n"
			 "    w (Wait): The instance of a Wait class that is to closed\n"
			 "\n"
			 "Returns:\n"
			 "    None.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> w = vc.startWaitProgressWindow(\"Counting 1, 2, ..., 100\", 100)\n"
			 "    >>> for i in range(100):\n"
			 "    >>>     doSomething(...)\n"
			 "    >>>     w.incrementBy(1.0)\n"
			 "    >>> vc.endWaitWindow(w)\n"
			 );


static PyObject *pyViewerController_endWaitWindow(pyViewerControllerObject *self, PyObject *args)
{
    if (PyTuple_Size(args) != 1) {
        PyErr_SetString(PyExc_ValueError, "Incorrect number of arguments given");
        return NULL;
    }
    
    PyObject *input = PyTuple_GetItem(args, 0);
    if (!pyWait_CheckExact(input))
    {
        PyErr_SetString(PyExc_ValueError, "Input must be a Wait type");
        return NULL;
    }
    [self->obj endWaitWindow:(((pyWaitObject *)input)->obj)];
    Py_INCREF(Py_None);
    return Py_None;
}

PyDoc_STRVAR(viewerControllerNeedsDisplayUpdate_doc,
			 "\n"
			 "Tells a ViewerController that it should be updated.\n"
			 "This method should be called after every change to the viewer's content.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    None.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> vc.needsDisplayUpdate()\n"
			 );


static PyObject *pyViewerController_needsDisplayUpdate(pyViewerControllerObject *self)
{
    [self->obj needsDisplayUpdate];
    Py_INCREF(Py_None);
    return Py_None;
}

PyDoc_STRVAR(viewerControllerSetROI_doc,
			 "\n"
			 "Adds a ROI instance to the viewer at a specified 4D frame and image number.\n"
			 "Note: The needsDisplayUpdate() method should be called afterwards.\n"
			 "\n"
			 "Args:\n"
			 "    roi (ROI): The ROI to add to the viewer\n"
			 "    position (Optional[int]): The image position of the ROI.\n"
			 "                              Defaults to the currently displayed position.\n"
			 "    movieIdx (Optional[int]): The 4D frame of the ROI.\n"
			 "                              Defaults to the currently displayed frame.\n"
			 "\n"
			 "Returns:\n"
			 "    None.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> pix = vc.curDCM()\n"
			 "    >>> roi = osirix.ROI(itype = \"tPencil\", DCMPix = pix)\n"
			 "    >>> roi.points = np.array([[0., 0.], [0., 100.], [100., 100.], [100., 0.]])\n"
			 "    >>> vc.setROI(roi)\n"
			 "    >>> del(roi)\n"
			 );

static PyObject *pyViewerController_setROI(pyViewerControllerObject *self, PyObject *args, PyObject *kwds)
{
    int movieIdx = [self->obj curMovieIndex];
    int imIdx = [[self->obj imageView] curImage];
    PyObject *pyROI;
    static char *kwlist[] = {"roi", "position", "movieIdx", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, kwds, "O!|ii", kwlist, &pyROIType, &pyROI, &imIdx, &movieIdx))
    {
        return NULL;
    }
    
    if (movieIdx >= [self->obj maxMovieIndex]) {
        NSString *str = [NSString stringWithFormat:@"'movieIdx' cannot be greater than current max (%d)", [self->obj maxMovieIndex]-1];
        PyErr_SetString(PyExc_ValueError, [str UTF8String]);
        return NULL;
    }
    
    int maxIdx = [[self->obj pixList:movieIdx] count];
    if (imIdx >= maxIdx) {
        NSString *str = [NSString stringWithFormat:@"'position' cannot be greater than current max (%d)", maxIdx-1];
        PyErr_SetString(PyExc_ValueError, [str UTF8String]);
        return NULL;
    }
    
    //Set the associated DCMPix as the dcm at that index
    DCMPix *pix = [[self->obj pixList:movieIdx] objectAtIndex:imIdx];
    [((pyROIObject*)pyROI)->obj setPix:pix];
    
    //Set the ROI
    NSMutableArray *rois = [self->obj roiList:movieIdx];
    [[rois objectAtIndex:imIdx] addObject:((pyROIObject*)pyROI)->obj];
    
    Py_INCREF(Py_None);
    return Py_None;
}

PyDoc_STRVAR(viewerControllerRoiList_doc,
			 "\n"
			 "Provides a tuple of tuples, each containing the ROIs within each slice of the ViewerController.\n"
			 "\n"
			 "Args:\n"
			 "    movieIdx (Optional[int]): The 4D index (starts at 0) from which to obtain the tuple of ROI instances.\n"
			 "                              Defaults to the currently displayed frame.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: A tuple with each element containing a tuple of ROI instance.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> rois = vc.roiList(movieIdx = 0)\n"
			 );

static PyObject *pyViewerController_roiList(pyViewerControllerObject *self, PyObject *args, PyObject *kwds)
{
	int movieIdx = [self->obj curMovieIndex];
	static char *keys[] = {"movieIdx", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, kwds, "|i", keys, &movieIdx))
		return NULL;
    
    NSMutableArray *rois = [self->obj roiList:movieIdx];
    PyObject *pyROIs = PyTuple_New([rois count]);
    for (int i = 0; i < [rois count]; i++) {
        NSMutableArray *rois_i = [rois objectAtIndex:i];
        PyObject *pyROIs_i = PyTuple_New([rois_i count]);
        for (int j = 0; j < [rois_i count]; j++) {
            PyObject *pyROI_j = [pyROI pythonObjectWithInstance:[rois_i objectAtIndex:j]];
            PyTuple_SetItem(pyROIs_i, j, pyROI_j);
        }
        PyTuple_SetItem(pyROIs, i, pyROIs_i);
    }
    return pyROIs;
}

PyDoc_STRVAR(viewerControllerCurDCM_doc,
			 "\n"
			 "Provide a reference to the currently displayed DCMPix.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    DCMPix: The currently displayed DCMPix of the ViewerController.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> pix = curDCM()\n"
			 );

static PyObject *pyViewerController_curDCM(pyViewerControllerObject *self)
{
    short movieIdx = [self->obj curMovieIndex];
    short idx = [(DCMView *)[self->obj imageView] curImage];
    NSMutableArray *pixList = [self->obj pixList:movieIdx];
    DCMPix *pix = [pixList objectAtIndex:idx];
    return [pyDCMPix pythonObjectWithInstance:pix];
}

PyDoc_STRVAR(viewerControllerRoisWithName_doc,
			 "\n"
			 "Returns a tuple of ROIs within the ViewerController with a given name.\n"
			 "\n"
			 "Args:\n"
			 "    name (str): The name of the ROIs to look for.\n"
			 "    movieIdx (Optional[int]): The 4D index (starts at 0) in which to search.\n"
			 "                             Defaults to the currently displayed frame.\n"
			 "    in4D (Optional[bool]): Defines whether to search over all 4D frames.\n"
			 "                           Defaults to False.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: A tuple with each element containing a ROI instance.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> rois = vc.roisWithName(\"MyROI\", in4D = True)\n"
			 );

static PyObject *pyViewerController_roisWithName(pyViewerControllerObject *self, PyObject *args, PyObject *kwds)
{
    short movieIdx = [self->obj curMovieIndex];
    short in4D = 0;
    char *name;
    static char *keys[] = {"movieIdx", "in4D", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, kwds, "s|Hi", keys, &name, &movieIdx, &in4D)) {
        return NULL;
    }
    
    NSArray *rois;
    if (in4D == 0)
        rois = [self->obj roisWithName:[NSString stringWithUTF8String:name] forMovieIndex:movieIdx];
    else
        rois = [self->obj roisWithName:[NSString stringWithUTF8String:name] in4D:YES];
    
    PyObject *pyROIs = PyTuple_New([rois count]);
    for (int i = 0; i < [rois count]; i++)
        PyTuple_SetItem(pyROIs, i, [pyROI pythonObjectWithInstance:[rois objectAtIndex:i]]);
    
    return pyROIs;
}

PyDoc_STRVAR(viewerControllerSelectedRois_doc,
			 "\n"
			 "Returns a tuple of the currently selected ROIs.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: A tuple with each element containing a ROI instance.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> rois = vc.selectedROIs()\n"
			 );

static PyObject *pyViewerController_selectedROIs(pyViewerControllerObject *self)
{
    NSMutableArray *rois = [self->obj selectedROIs];
    PyObject *pyROIs = PyTuple_New([rois count]);
    for (int i = 0; i < [rois count]; i++)
        PyTuple_SetItem(pyROIs, i, [pyROI pythonObjectWithInstance:[rois objectAtIndex:i]]);
    
    return pyROIs;
}


/*****************************************************************************************************
 * I have copied from the implementation of ViewerController.  There is a mismatch in the header file
 * of ViewerController provided from plugins and the source for OsiriX complete.  The latter provides
 * this functionality in-built.
 ****************************************************************************************************/

void copyVolumeDataForViewerController(ViewerController *vC, NSData** vD, NSMutableArray ** newPixList, int v)
{
    *vD = nil;
    *newPixList = nil;
    
    // First calculate the amount of memory needed for the new serie
    NSArray		*pL = [vC pixList: v];
    DCMPix		*curPix;
    long		mem = 0;
    
    for( int i = 0; i < [pL count]; i++)
    {
        curPix = [pL objectAtIndex: i];
        mem += [curPix pheight] * [curPix pwidth] * 4;		// each pixel contains either a 32-bit float or a 32-bit ARGB value
    }
    
    unsigned char *fVolumePtr = malloc( mem);	// ALWAYS use malloc for allocating memory !
    if( fVolumePtr)
    {
        // Copy the source series in the new one !
        memcpy( fVolumePtr, [vC volumePtr: v], mem);
        
        // Create a NSData object to control the new pointer
        *vD = [[[NSData alloc] initWithBytesNoCopy:fVolumePtr length:mem freeWhenDone:YES] autorelease];
        
        // Now copy the DCMPix with the new fVolumePtr
        *newPixList = [NSMutableArray array];
        for( int i = 0; i < [pL count]; i++)
        {
            curPix = [[[pL objectAtIndex: i] copy] autorelease];
            [curPix setfImage: (float*) (fVolumePtr + [curPix pheight] * [curPix pwidth] * 4 * i)];
            [*newPixList addObject: curPix];
        }
    }
}

PyDoc_STRVAR(viewerControllerCopyViewerWindow_doc,
			 "\n"
			 "Duplicates the current viewer window and displays it.\n"
			 "\n"
			 "Args:\n"
			 "    in4D (Optional[bool]): Defines whether to copy all 4D frames.\n"
			 "                           Defaults to False.\n"
			 "\n"
			 "Returns:\n"
			 "    ViewerController: A reference to the newly created viewer.\n"
			 "\n"
			 "Example:\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> vcNew = vc.copyViewerWindow(in4D = True)\n"
			 );

static PyObject *pyViewerController_copyViewerWindow(pyViewerControllerObject *self, PyObject *args, PyObject *kwds)
{
    int in4D = 0;
    static char *keys[] = {"in4D", NULL};
    
    if (!PyArg_ParseTupleAndKeywords(args, kwds, "|i", keys, &in4D)) {
        return NULL;
    }
    
    ViewerController *new2DViewer = nil;
    
    NSData *vD = nil;
    NSMutableArray *newPixList = nil;
    copyVolumeDataForViewerController(self->obj, &vD, &newPixList, 0);
    if (!vD) {
        PyErr_SetString(PyExc_RuntimeError, "Could not duplicate Viewer Controller!");
        return NULL;
    }
    
    // CAUTION: The DicomFile array is identical!
    new2DViewer = [self->obj newWindow:newPixList :[self->obj fileList: 0] :vD];
    [new2DViewer roiDeleteAll: self->obj];
    
    if (in4D != 0 && [self->obj maxMovieIndex] > 1) {
        for( int v = 1; v < [self->obj maxMovieIndex]; v++)
        {
            vD = nil;
            newPixList = nil;
            copyVolumeDataForViewerController(self->obj, &vD, &newPixList, v);
            if( vD)
                [new2DViewer addMovieSerie:newPixList :[self->obj fileList: v] :vD];
        }
    }
    
    return [pyViewerController pythonObjectWithInstance:new2DViewer];
}

PyDoc_STRVAR(viewerControllerIsDataVolumic_doc,
			 "\n"
			 "Identifies whether the data within the viewer window is volumic (i.e. can be displayed in 3D view).\n"
			 "\n"
			 "Args:\n"
			 "    in4D (Optional[bool]): Defines whether to check over all 4D frames.\n"
			 "                           Defaults to False.\n"
			 "\n"
			 "Returns:\n"
			 "    bool: A boolean value determining whether the data is volumic.\n"
			 );

static PyObject *pyViewerController_isDataVolumic(pyViewerControllerObject *self, PyObject *args, PyObject *kwds)
{
    int in4D = 0;
    static char *keys[] = {"in4D", NULL};
    
    if (!PyArg_ParseTupleAndKeywords(args, kwds, "|i", keys, &in4D))
        return NULL;
    
    BOOL isVol;
    if (in4D == 0)
        isVol = [self->obj isDataVolumicIn4D:NO];
    else
        isVol = [self->obj isDataVolumicIn4D:YES];
    
    return PyBool_FromLong((long)isVol);
}

PyDoc_STRVAR(viewerControllerResampleViewerController_doc,
			 "\n"
			 "Create a copy of the the ViewerController instance with images resampled\n"
			 "to the same resolution as a another viewer.\n"
			 "\n"
			 "Args:\n"
			 "    vc (ViewerController): The viewer to which the current resolution should be matched.\n"
			 "\n"
			 "Returns:\n"
			 "    ViewerController: The reference to the new viewer in which the data is resampled.\n"
			 "\n"
			 "Example:\n"
			 "    vcs = osirix.getDisplayed2DViewers()\n"
			 "    vc0 = vcs[0]\n"
			 "    vc1 = vcs[1]\n"
			 "    vcNew = vc0.resampleViewerController(vc1)\n"
			 );

static PyObject *pyViewerController_resampleViewerController(pyViewerControllerObject *self, PyObject *args)
{
    pyViewerControllerObject *movingVC;
    if (!PyArg_ParseTuple(args, "O!", &pyViewerControllerType, &movingVC))
        return NULL;
    
    ViewerController *newVC = [self->obj resampleSeries:movingVC->obj];
    if (!newVC) {
        PyErr_SetString(PyExc_Warning, "Resampling failed");
        return NULL;
    }
    
    NSString *oldTitle = [[newVC window] title];
    NSString *newTitle = [NSString stringWithFormat:@"Resample: %@", oldTitle];
    [[newVC window] setTitle:newTitle];
    
    return [pyViewerController pythonObjectWithInstance:newVC];
}

PyDoc_STRVAR(viewerControllerBlendingController_doc,
			 "\n"
			 "Returns a reference to the ViewerController currently fused with this one.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    ViewerController: The fused viewer window.\n"
			 );

static PyObject *pyViewerController_blendingController(pyViewerControllerObject *self)
{
    
    ViewerController *bVC = [self->obj blendingController];
    if (bVC == nil) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    
    return [pyViewerController pythonObjectWithInstance:bVC];
}

PyDoc_STRVAR(viewerControllerVRControllers_doc,
			 "\n"
			 "Returns all volume render controllers associated with this viewer.\n"
			 "\n"
			 "Args:\n"
			 "    None.\n"
			 "\n"
			 "Returns:\n"
			 "    tuple: A tuple of all associated VRControllers.\n"
			 "\n"
			 "Example:\n"
			 "    vc = osirix.getFrontmostViewer()\n"
			 "    VRs = vc.VRControllers()\n"
			 );

static PyObject *pyViewerController_VRControllers(pyViewerControllerObject *self)
{
    NSArray *viewers = [[AppController sharedAppController] FindRelatedViewers:[self->obj pixList:0]];
    
    NSMutableArray *viewerArr = [NSMutableArray array];
    
    for( NSWindowController *v in viewers)
    {
        if( [v.windowNibName isEqualToString: @"VR"])
            [viewerArr addObject:v];
    }
    
    if ([viewerArr count] == 0) {
        Py_INCREF(Py_None);
        return Py_None;
    }
    
    PyObject *tuple = PyTuple_New([viewerArr count]);
    for (int i = 0; i < [viewerArr count]; i++) {
        PyTuple_SetItem(tuple, i, [pyVRController pythonObjectWithInstance:[viewerArr objectAtIndex:i]]);
    }
    return tuple;
}

static PyMethodDef pyViewerControllerMethods[] =
{
    {"maxMovieIndex", (PyCFunction)pyViewerController_maxMovieIdx, METH_NOARGS, viewerControllerMaxMovieIdx_doc},
    {"closeViewer", (PyCFunction)pyViewerController_closeViewer, METH_NOARGS, viewerControllerCloseViewer_doc},
    {"pixList", (PyCFunction)pyViewerConroller_pixList, METH_VARARGS|METH_KEYWORDS, viewerControllerPixList_doc},
   // {"startWaitWindow", (PyCFunction)pyViewerController_startWaitWindow, METH_VARARGS, "Start a wait window.\nUsage: Wait = startWaitWindow(str)\n  str: A string to display on the window."},
    {"startWaitProgressWindow", (PyCFunction)pyViewerController_startWaitProgressWindow, METH_VARARGS, viewerControllerStartWaitProgressWindow_doc},
    {"endWaitWindow", (PyCFunction)pyViewerController_endWaitWindow, METH_VARARGS, viewerControllerEndWaitWindow_doc},
    {"needsDisplayUpdate", (PyCFunction)pyViewerController_needsDisplayUpdate, METH_NOARGS, viewerControllerNeedsDisplayUpdate_doc},
    {"roiList", (PyCFunction)pyViewerController_roiList, METH_VARARGS|METH_KEYWORDS, viewerControllerRoiList_doc},
    {"setROI", (PyCFunction)pyViewerController_setROI, METH_VARARGS|METH_KEYWORDS, viewerControllerSetROI_doc},
    {"curDCM", (PyCFunction)pyViewerController_curDCM, METH_NOARGS, viewerControllerCurDCM_doc},
    {"roisWithName", (PyCFunction)pyViewerController_roisWithName, METH_VARARGS|METH_KEYWORDS, viewerControllerRoisWithName_doc},
    {"selectedROIs", (PyCFunction)pyViewerController_selectedROIs, METH_NOARGS, viewerControllerSelectedRois_doc},
    {"isDataVolumic", (PyCFunction)pyViewerController_isDataVolumic, METH_VARARGS|METH_KEYWORDS, viewerControllerIsDataVolumic_doc},
    {"copyViewerWindow", (PyCFunction)pyViewerController_copyViewerWindow, METH_VARARGS|METH_KEYWORDS, viewerControllerCopyViewerWindow_doc},
    {"resampleViewerController", (PyCFunction)pyViewerController_resampleViewerController, METH_VARARGS, viewerControllerResampleViewerController_doc},
    {"blendingController", (PyCFunction)pyViewerController_blendingController, METH_NOARGS, viewerControllerBlendingController_doc},
    {"VRControllers", (PyCFunction)pyViewerController_VRControllers, METH_NOARGS, viewerControllerVRControllers_doc},
    {NULL}
};

# pragma mark -
# pragma mark pyViewerControllerType definition

PyDoc_STRVAR(viewerController_doc,
			 "A python implementation of the OsiriX 'ViewerController' class.\n"
			 "This class is used to obtain access to many of the viewer properties and its contained data.\n"
			 "Instances of this class may not be created.  Instead instances are accessed\n"
			 "via functions defined in the osirix module\n"
			 "\n"
			 "Example Usage:\n"
			 "    >>> import osirix\n"
			 "    >>> vc = osirix.frontmostViewer()\n"
			 "    >>> print vc.title\n"
			 );

PyTypeObject pyViewerControllerType =
{
    PyObject_HEAD_INIT(NULL)
    0,
    "osirix.ViewerController",
    sizeof(pyViewerControllerObject),
    0,
    (destructor)pyViewerController_dealloc,
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
    (reprfunc)pyViewerController_str,
    0,
    0,
    0,
    Py_TPFLAGS_DEFAULT,
    viewerController_doc,
    0,
    0,
    0,
    0,
    0,
    0,
    pyViewerControllerMethods,
    0,
    pyViewerController_getsetters,
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
# pragma mark pyViewerController implementation

@implementation pyViewerController

+ (void)initTypeInModule:(PyObject *)module
{
    if (PyType_Ready(&pyViewerControllerType) < 0) {
        return;
    }
    Py_INCREF(&pyViewerControllerType);
    PyModule_AddObject(module, "ViewerController", (PyObject*)&pyViewerControllerType);
}

+ (PyObject *)pythonObjectWithInstance:(id)obj
{
    if ([obj class] != [ViewerController class]) {
        return NULL;
    }
    
    pyViewerControllerObject *o = PyObject_New(pyViewerControllerObject, &pyViewerControllerType);
    o->obj = [obj retain];
    return (PyObject *)o;
}

@end
