//
//  POScriptWindowController.m
//  pyOsiriX
//
//  Created by Matthew Blackledge on 01/02/2016.
//
//

#import "POScriptWindowController.h"
#import "POScriptManager.h"
#import "pyOsiriXFilter.h"

@implementation POScriptWindowController

+ (NSInteger)alertWithMessageText:(NSString *)message :(NSString *)firstButton :(NSString *)secondButton :(NSString *)thirdButton :(NSString *)informativeTextWithFormat, ...
{
	NSAlert *alert = [[NSAlert alloc] init];
	if (message)
		[alert setMessageText:message];
	if (firstButton)
		[alert addButtonWithTitle:firstButton];
	if (secondButton)
		[alert addButtonWithTitle:secondButton];
	if (thirdButton)
		[alert addButtonWithTitle:thirdButton];
	if (informativeTextWithFormat)
	{
		va_list args;
		va_start(args, informativeTextWithFormat);
		NSString *infText = [[NSString alloc] initWithFormat:informativeTextWithFormat arguments:args];
		[alert setInformativeText:infText];
		[infText release];
		va_end(args);
	}
	[alert setAlertStyle:NSWarningAlertStyle];
	
	NSInteger response = (NSInteger)[alert runModal];
	[alert release];
	return response;
}

- (void)installScript
{
    NSOpenPanel *oP = [[NSOpenPanel alloc] init];
    [oP setCanChooseDirectories:NO];
    [oP setCanChooseFiles:YES];
	[oP setAllowedFileTypes:[NSArray arrayWithObject:@"py"]];
    [oP setTitle:@"Please choose a python script to install"];
    [oP setCanHide:NO];
    
    NSUInteger ans = [oP runModal];
    if (ans != NSFileHandlingPanelOKButton) {
		[oP close];
		[oP release];
        return;
    }
	
	NSURL *scriptURL = [oP URL];
	if (!scriptURL) {
		return;
	}
	[oP close];
	[oP release];
	NSError *err;
    if (![scriptManager installScriptFromURL:scriptURL withError:&err]) {
		[POScriptWindowController alertWithMessageText:pluginName :@"OK" :nil :nil :@"%@\r%@", [[err userInfo] valueForKey:NSLocalizedDescriptionKey], [[err userInfo] valueForKey:NSLocalizedFailureReasonErrorKey]];
		return;
	}
	[table reloadData];
}

- (void)removeScript
{
    NSIndexSet *idxSet = [table selectedRowIndexes];
	NSMutableArray *names = [NSMutableArray array];
    NSArray *sH = [scriptManager scriptHeaders];
	for (NSUInteger i = 0; i < [sH count]; i++) {
        if ([idxSet containsIndex:i]) {
            [names addObject:[[sH objectAtIndex:i] valueForKey:@"name"]];
        }
    }
    [scriptManager removeScriptsWithNames:[NSArray arrayWithArray:names]];
	[table reloadData];
}

- (IBAction)addRemovePath:(id)sender
{
    NSSegmentedCell *cell = (NSSegmentedCell *)sender;
    switch ([cell selectedSegment]) {
        case 0:
            [self installScript];
            break;
        case 1:
            [self removeScript];
            break;
        default:
            break;
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    NSArray *userPackages = [scriptManager scriptHeaders];
    return [userPackages count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSArray *userScripts = [scriptManager scriptHeaders];
	if ([[tableColumn identifier] isEqualToString:@"Type"]) {
		return [[userScripts objectAtIndex:row] valueForKey:@"type"];
	}
	return [[userScripts objectAtIndex:row] valueForKey:@"name"];
}

@end
