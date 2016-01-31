//
//  POPackageManager.m
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

#import "POPackageManager.h"

NSString * const pythonUserPackagesDefaultKey = @"com.InstituteOfCancerResearch.pyOsiriX.userPackagesKey";

@implementation POPackageManager

+ (POPackageManager *)packageManager
{
    return [[[POPackageManager alloc] init] autorelease];
}

- (NSArray *) requiredPackages
{
    NSString *frameworks = [[NSBundle bundleForClass:[self class]] privateFrameworksPath];
    NSString *homeStr = [frameworks stringByAppendingString:@"/Python.framework/Versions/2.7/"];
    
    //There are all the packages required to run
    NSArray *arr = [NSArray arrayWithObjects:
            frameworks,
            [NSString stringWithFormat:@"%@%@", homeStr, @"lib/python2.7"],
            [NSString stringWithFormat:@"%@%@", homeStr, @"lib/python2.7/plat-darwin"],
            [NSString stringWithFormat:@"%@%@", homeStr, @"lib/python2.7/plat-mac"],
            [NSString stringWithFormat:@"%@%@", homeStr, @"lib/python2.7/plat-mac/lib-scriptpackages"],
            //[NSString stringWithFormat:@"%@%@", homeStr, @"/lib/python2.7/lib-tk"], //Currently not working/needed so don't provide.
            [NSString stringWithFormat:@"%@%@", homeStr, @"lib/python2.7/lib-old"],
            [NSString stringWithFormat:@"%@%@", homeStr, @"lib/python2.7/lib-dynload"],
            [NSString stringWithFormat:@"%@%@", homeStr, @"lib/python2.7/site-packages"],
            [NSString stringWithFormat:@"%@%@", homeStr, @"lib/python2.7/site-packages/matplotlib-1.4.3-py2.7-macosx-10.5-intel.egg"],
            [NSString stringWithFormat:@"%@%@", homeStr, @"lib/python2.7/site-packages/PIL"],
                    nil];
    
    return arr;
}

- (NSArray *) getUserPackages
{
    NSArray *packages = [[NSUserDefaults standardUserDefaults] arrayForKey:pythonUserPackagesDefaultKey];
    return packages;
}

- (NSArray *) extractPythonEggsFromPath:(NSString *)path
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *subdirs = [fm contentsOfDirectoryAtPath:path error:nil];
    if (!subdirs) {
        return nil;
    }
    NSMutableArray *arr = [NSMutableArray array];
    for(NSString *subdir in subdirs)
    {
        NSString *ext = [subdir pathExtension];
        if ([ext isEqualToString:@"egg"]) {
            [arr addObject:[NSString stringWithFormat:@"%@/%@", path, subdir]];
        }
    }
    return arr;
}

- (NSArray *) appendPythonEggstoPaths:(NSArray *)paths
{
    NSMutableArray *arr = [NSMutableArray array];
    for (NSString *path in paths) {
        [arr addObject:path];
        NSArray *eggs = [self extractPythonEggsFromPath:path];
        if (eggs) {
            [arr addObjectsFromArray:eggs];
        }
    }
    return [NSArray arrayWithArray:arr];
}

- (BOOL) addUserPackage:(NSString *)path
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:path isDirectory:&isDir] || ! isDir) {
        NSLog(@"%s - Path %@, does not exist or is not a directory", __func__, path);
        return NO;
    }
    NSArray *packages = [[NSUserDefaults standardUserDefaults] arrayForKey:pythonUserPackagesDefaultKey];
    NSArray *newPackages = [packages arrayByAddingObject:path]; //TODO - work with URLs?
    [[NSUserDefaults standardUserDefaults] setObject:newPackages forKey:pythonUserPackagesDefaultKey];
    return YES;
}

- (void) removeUserPackage:(NSString *)path
{
    NSMutableArray *packages = [[self getUserPackages] mutableCopy];
    for (NSString *pack in packages) {
        if ([pack isEqualToString:path]) {
            [packages removeObject:pack];
        }
    }
    [self setUserPackages:packages];
}

- (BOOL) setUserPackages:(NSArray *)packages
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    for (NSString *path in packages) {
        if (![fm fileExistsAtPath:path isDirectory:&isDir] || ! isDir) {
            NSLog(@"%s - Path %@, does not exist or is not a directory", __func__, path);
            return NO;
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:packages forKey:pythonUserPackagesDefaultKey];
    return YES;
}



@end
