//
//  pythonPackageWindowController.m
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

#import "POPackageWindowController.h"
#import "POPackageManager.h"
#import "PORuntime.h"

@implementation POPackageWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)addPath
{
    NSOpenPanel *oP = [[NSOpenPanel alloc] init];
    [oP setCanChooseDirectories:YES];
    [oP setCanChooseFiles:NO];
    [oP setTitle:@"Please choose a python package path"];
    [oP setCanHide:NO];
    
    NSUInteger ans = [oP runModal];
    if (ans != NSFileHandlingPanelOKButton) {
        return;
    }
	NSURL *url = [oP URL];
	if (!url) {
		url = [oP directoryURL];
	}
	if (!url) {
		return;
	}
    NSString *dir = [url path];
	[oP close];
	[oP release];
    POPackageManager *ppm = [POPackageManager packageManager];
    for (NSString *package in [ppm getUserPackages]) {
        if ([package isEqualToString:dir]) {
            return; //Path already there
        }
    }
    NSMutableArray *currPackages = [[ppm getUserPackages] mutableCopy];
    [currPackages addObject:dir];
    [ppm setUserPackages:[NSArray arrayWithArray:currPackages]];
    [pyRuntime updateSysPath];
    [table reloadData];
}

- (void)removePath
{
    NSIndexSet *idxSet = [table selectedRowIndexes];
    POPackageManager *ppm = [POPackageManager packageManager];
    NSMutableArray *currPackages = [[ppm getUserPackages] mutableCopy];
    for (int i  = 0; i < [currPackages count]; i++) {
        if ([idxSet containsIndex:i]) {
            [currPackages removeObjectAtIndex:i];
        }
    }
    [ppm setUserPackages:[NSArray arrayWithArray:currPackages]];
    [pyRuntime updateSysPath];
    [table reloadData];
}

- (IBAction)addRemovePath:(id)sender
{
    NSSegmentedCell *cell = (NSSegmentedCell *)sender;
    switch ([cell selectedSegment]) {
        case 0:
            [self addPath];
            break;
        case 1:
            [self removePath];
            break;
        default:
            break;
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    NSArray *userPackages = [[POPackageManager packageManager] getUserPackages];
    return [userPackages count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSArray *userPackages = [[POPackageManager packageManager] getUserPackages];
    return [userPackages objectAtIndex:row];
}

@end
