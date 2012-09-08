//
//  BBAppDelegate.m
//  Boxer Bundler
//
//  Created by Alun Bestor on 15/08/2012.
//  Copyright (c) 2012 Alun Bestor. All rights reserved.
//

#import "BBAppDelegate+AppExporting.h"
#import "BBURLTransformer.h"
#import "BBIconDropzone.h"
#import "NSURL+BXFilePaths.h"

NSString * const kBBRowIndexSetDropType = @"BBRowIndexSetDropType";
NSString * const kUTTypeGamebox = @"net.washboardabs.boxer-game-package";

NSString * const kBBValidationErrorDomain = @"net.washboardabs.boxer-bundler.validationErrorDomain";

enum {
    kBBValidationValueMissing,
    kBBValidationInvalidValue,
    kBBValidationUnsupportedApplication
};


@interface BBAppDelegate ()

@property (assign, getter=isBusy) BOOL busy;

@end


@implementation BBAppDelegate
//Defined because we have custom setters for these
@synthesize appName = _appName;
@synthesize gameboxURL = _gameboxURL;

#pragma mark -
#pragma mark Application lifecycle

+ (void) initialize
{
    if (self == [BBAppDelegate class])
    {
        [BBURLTransformer registerWithName: nil];
        [BBFileURLTransformer registerWithName: nil];
    }
}

- (void) applicationWillFinishLaunching: (NSNotification *)aNotification
{
    //Load initial defaults
    NSString *defaultsPath	= [[NSBundle mainBundle] pathForResource: @"UserDefaults" ofType: @"plist"];
    NSDictionary *defaults	= [NSDictionary dictionaryWithContentsOfFile: defaultsPath];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaults];
    
    [self _loadParamsFromUserDefaults];
    
    //Set up the two-way binding for our dropzone
    [self.iconDropzone bind: @"imageURL" toObject: self withKeyPath: @"appIconURL" options: nil];
    [self bind: @"appIconURL" toObject: self.iconDropzone withKeyPath: @"imageURL" options: nil];
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
    self.window.delegate = self;
    [self.window registerForDraggedTypes: @[NSURLPboardType]];
    [self.window makeKeyAndOrderFront: self];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)sender
{
    return YES;
}

- (void) applicationWillTerminate: (NSNotification *)notification
{
    [self _persistParamsIntoUserDefaults];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


#pragma mark -
#pragma mark Property persistence

+ (NSArray *) _persistableKeys
{
    return @[@"appName", @"appBundleIdentifier", @"appVersion", @"organizationName", @"organizationURL", @"showsHotkeyWarning", @"ctrlClickEnabled"];
}

- (void) _loadParamsFromUserDefaults
{
    NSArray *keys = [self.class _persistableKeys];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    //Several values cannot be imported directly and need to be handled separately.
    NSData *gameboxBookmark = [defaults dataForKey: @"gameboxURLBookmark"];
    if (gameboxBookmark)
    {
        self.gameboxURL = [NSURL URLByResolvingBookmarkData: gameboxBookmark
                                                    options: NSURLBookmarkResolutionWithoutUI
                                              relativeToURL: nil
                                        bookmarkDataIsStale: NULL
                                                      error: NULL];
    }
    
    NSData *appIconBookmark = [defaults dataForKey: @"appIconURLBookmark"];
    if (appIconBookmark)
    {
        self.appIconURL = [NSURL URLByResolvingBookmarkData: appIconBookmark
                                                    options: NSURLBookmarkResolutionWithoutUI
                                              relativeToURL: nil
                                        bookmarkDataIsStale: NULL
                                                      error: NULL];
    }
    
    //The help links array needs to be deeply mutable, so we need to do extra work when loading it in.
    NSArray *savedHelpLinks = [defaults arrayForKey: @"helpLinks"];
    if (savedHelpLinks.count)
    {
        NSMutableArray *mutableLinks = [[NSMutableArray alloc] initWithCapacity: savedHelpLinks.count];
        for (NSDictionary *linkInfo in savedHelpLinks)
        {
            [mutableLinks addObject: [linkInfo mutableCopy]];
        }
        
        self.helpLinks = mutableLinks;
    }
    
    //The rest of the values can be loaded as-is.
    for (NSString *key in keys)
    {
        id value = [defaults objectForKey: key];
        [self setValue: value forKey: key];
    }
}

- (void) _persistParamsIntoUserDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    //Most of the values can be copied straight across.
    NSArray *keys = [self.class _persistableKeys];
    NSDictionary *values = [self dictionaryWithValuesForKeys: keys];
    [defaults setValuesForKeysWithDictionary: values];
    
    //...but we have to handle some of the values by hand, so that userdefaults
    //won't poo itself over them.
    NSData *gameboxBookmark = [self.gameboxURL bookmarkDataWithOptions: NSURLBookmarkCreationSuitableForBookmarkFile
                                        includingResourceValuesForKeys: nil
                                                         relativeToURL: nil
                                                                 error: NULL];
    
    NSData *appIconBookmark = [self.appIconURL bookmarkDataWithOptions: NSURLBookmarkCreationSuitableForBookmarkFile
                                        includingResourceValuesForKeys: nil
                                                         relativeToURL: nil
                                                                 error: NULL];
    
    if (gameboxBookmark)
        [defaults setObject: gameboxBookmark forKey: @"gameboxURLBookmark"];
    
    if (appIconBookmark)
        [defaults setObject: appIconBookmark forKey: @"appIconURLBookmark"];
    
    [defaults setObject: self.helpLinks forKey: @"helpLinks"];
}

- (BOOL) _loadParamsFromAppAtURL: (NSURL *)appURL error: (NSError **)outError
{
    NSBundle *app = [NSBundle bundleWithURL: appURL];
    
    NSString *gameboxName = [app objectForInfoDictionaryKey: @"BXBundledGameboxName"];
    
    if (gameboxName == nil)
    {
        if (outError)
        {
            NSString *errorDescriptionFormat = NSLocalizedString(@"%@ is not a bundled game application.",
                                                                 @"Error message shown when the user tries to load settings from an application that is not a bundled game app. %@ is the filename of the application.");
            
            NSString *errorDescription = [NSString stringWithFormat: errorDescriptionFormat, appURL.lastPathComponent];
            *outError = [NSError errorWithDomain: kBBValidationErrorDomain
                                            code: kBBValidationUnsupportedApplication
                                        userInfo: @{ NSLocalizedDescriptionKey : errorDescription }];
        }
        return NO;
    }
    
    if (!gameboxName.pathExtension.length)
        gameboxName = [gameboxName stringByAppendingPathExtension: @"boxer"];
    
    
    //First, import everything we can from the application's Info.plist file.
    self.gameboxURL = [app URLForResource: gameboxName withExtension: nil];
    self.appBundleIdentifier = [app bundleIdentifier];
    self.appVersion = [app objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    self.appName = [app objectForInfoDictionaryKey: @"CFBundleName"];
    
    NSString *iconName = [app objectForInfoDictionaryKey: @"CFBundleIconFile"];
    if (!iconName.pathExtension.length)
        iconName = [iconName stringByAppendingPathExtension: @"icns"];
    self.appIconURL = [app URLForResource: iconName withExtension: nil];
    
    self.organizationName = [app objectForInfoDictionaryKey: @"BXOrganizationName"];
    self.organizationURL = [app objectForInfoDictionaryKey: @"BXOrganizationWebsiteURL"];
    
    NSArray *appHelpLinks = [app objectForInfoDictionaryKey: @"BXHelpLinks"];
    
    NSMutableArray *helpLinks = [NSMutableArray arrayWithCapacity: appHelpLinks.count];
    for (NSDictionary *linkInfo in appHelpLinks)
    {
        NSDictionary * parsedLinkInfo = @{
                                        @"title": linkInfo[@"BXHelpLinkTitle"],
                                        @"url": linkInfo[@"BXHelpLinkURL"]
                                        };
        
        [helpLinks addObject: [parsedLinkInfo mutableCopy]];
    }
    self.helpLinks = helpLinks;
    
    //Next, load toggleable settings from the application's user defaults and game defaults.
    NSURL *appUserDefaultsURL = [app URLForResource: @"UserDefaults.plist" withExtension: nil];
    NSURL *appGameDefaultsURL = [app URLForResource: @"GameDefaults.plist" withExtension: nil];
    NSDictionary *appUserDefaults = [NSDictionary dictionaryWithContentsOfURL: appUserDefaultsURL];
    NSDictionary *appGameDefaults = [NSDictionary dictionaryWithContentsOfURL: appGameDefaultsURL];
    
    NSNumber *showsHotkeyWarningFlag = [appUserDefaults objectForKey: @"showHotkeyWarning"];
    if (showsHotkeyWarningFlag)
        self.showsHotkeyWarning = showsHotkeyWarningFlag.boolValue;
    
    NSNumber *ctrlClickShortcutMask = [appGameDefaults objectForKey: @"mouseButtonModifierRight"];
    if (ctrlClickShortcutMask)
    {
        self.ctrlClickEnabled = (ctrlClickShortcutMask.integerValue == 262144);
    }
    
    return YES;
}


#pragma mark -
#pragma mark Custom getters and setters

- (void) setGameboxURL: (NSURL *)URL
{
    if (![URL isEqual: self.gameboxURL])
    {
        _gameboxURL = URL;
        
        //Update the application name whenever the gamebox changes
        self.appName = URL.lastPathComponent.stringByDeletingPathExtension;
    }
}

- (void) setAppName: (NSString *)name
{
    if (![self.appName isEqualToString: name])
    {
        _appName = [name copy];
        
        //Synchronize the bundle identifier whenever the application name changes
        if (name.length)
        {
            NSString *fragment = [self.class bundleIdentifierFragmentFromString: name];
            [self setAppBundleIdentifierFragment: fragment];
        }
    }
}

- (void) setAppBundleIdentifierFragment: (NSString *)fragment
{
    NSString *baseIdentifier;
    if (self.appBundleIdentifier.length)
    {
        NSArray *components = [self.appBundleIdentifier componentsSeparatedByString: @"."];
        if (components.count > 2)
            components = [components subarrayWithRange: NSMakeRange(0, 2)];
        baseIdentifier = [components componentsJoinedByString: @"."];
    }
    else
    {
        baseIdentifier = @"com.companyname";
    }
    
    NSString *fullIdentifier = [NSString stringWithFormat: @"%@.%@", baseIdentifier, fragment];
    self.appBundleIdentifier = fullIdentifier;
}

- (NSString *) sanitisedAppName
{
    NSString *sanitisedName = self.appName;
    
    sanitisedName = [sanitisedName stringByReplacingOccurrencesOfString: @":" withString: @"-"];
    sanitisedName = [sanitisedName stringByReplacingOccurrencesOfString: @"/" withString: @"-"];
    sanitisedName = [sanitisedName stringByReplacingOccurrencesOfString: @"\\" withString: @"-"];
    return sanitisedName;
}

#pragma mark -
#pragma mark Property validation

- (BOOL) validateGameboxURL: (id *)ioValue error: (NSError **)outError
{
    NSURL *gameboxURL = *ioValue;
    if (gameboxURL)
    {
        NSString *UTI;
        BOOL retrievedUTI = [gameboxURL getResourceValue: &UTI forKey: NSURLTypeIdentifierKey error: outError];
        if (retrievedUTI)
        {
            //Check that it's really a gamebox
            BOOL isGamebox = [[NSWorkspace sharedWorkspace] type: UTI conformsToType: kUTTypeGamebox];
            if (!isGamebox)
            {
                if (outError)
                    *outError = [self _validationErrorWithCode: kBBValidationInvalidValue
                                                       message: @"Please supply a standard gamebox produced by Boxer."];
                return NO;
            }
        }
        else return NO;
    }
    return YES;
}

- (BOOL) validateAppIconURL: (id *)ioValue error: (NSError **)outError
{
    NSURL *appIconURL = *ioValue;
    if (appIconURL)
    {
        NSString *UTI;
        BOOL retrievedUTI = [appIconURL getResourceValue: &UTI forKey: NSURLTypeIdentifierKey error: outError];
        if (retrievedUTI)
        {
            //Check that it's in .icns format
            BOOL isIcns = [[NSWorkspace sharedWorkspace] type: UTI conformsToType: (NSString *)kUTTypeAppleICNS];
            if (!isIcns)
            {
                if (outError)
                    *outError = [self _validationErrorWithCode: kBBValidationInvalidValue
                                                       message: @"Application icons must be supplied in ICNS format."];
                
                return NO;
            }
        }
        else return NO;
    }
    return YES;
}

- (BOOL) validateAppName: (id *)ioValue error: (NSError **)outError
{
    NSString *appName = *ioValue;
    if (!appName.length)
    {
        if (outError)
        {
            *outError = [self _validationErrorWithCode: kBBValidationValueMissing
                                               message: @"Please specify a name for the application."];
        }
        return NO;
    }
    else
    {
        //Make a token effort to sanitise the application name so that it's safe to use in filenames.
        appName = [appName stringByReplacingOccurrencesOfString: @":" withString: @" - "];
        appName = [appName stringByReplacingOccurrencesOfString: @"/" withString: @""];
        
        *ioValue = appName;
    }
    return YES;
}

- (BOOL) validateAppBundleIdentifier: (id *)ioValue error: (NSError **)outError
{
    NSString *bundleIdentifier = *ioValue;
    if (!bundleIdentifier.length)
    {
        if (outError)
        {
            *outError = [self _validationErrorWithCode: kBBValidationValueMissing
                                               message: @"Please specify a bundle identifier for the application: e.g. 'com.companyname.game-name'."];
        }
        return NO;
    }
    else
    {
        bundleIdentifier = [bundleIdentifier.lowercaseString stringByReplacingOccurrencesOfString: @" " withString: @"-"];
        bundleIdentifier = [bundleIdentifier stringByReplacingOccurrencesOfString: @"_" withString: @"-"];
        
        *ioValue = bundleIdentifier;
    }
    return YES;
}

- (BOOL) validateAppVersion: (id *)ioValue error: (NSError **)outError
{
    NSString *version = *ioValue;
    if (!version.length)
    {
        *ioValue = @"1.0";
    }
    return YES;
}

- (BOOL) validateOrganizationName: (id *)ioValue error: (NSError **)outError
{
    NSString *name = *ioValue;
    if (!name.length)
    {
        if (outError)
            *outError = [self _validationErrorWithCode: kBBValidationValueMissing
                                               message: @"Please specify a name for your organization. This will be displayed in the menus of the application."];
        return NO;
    }
    return YES;
}

- (BOOL) validateOrganizationURL: (id *)ioValue error: (NSError **)outError
{
    NSString *URL = *ioValue;
    
    if (!URL)
    {
        if (outError)
            *outError = [self _validationErrorWithCode: kBBValidationValueMissing
                                               message: @"Please specify a website URL for your organization. This will be linked from the About window of the application."];
        return NO;
    }
    return YES;
}

- (NSError *) _validationErrorWithCode: (NSInteger)errCode message: (NSString *)message
{
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: message};
    return [NSError errorWithDomain: kBBValidationErrorDomain code: errCode userInfo: userInfo];
}



#pragma mark -
#pragma mark Editing help links

- (void) insertObject: (NSMutableDictionary *)object inHelpLinksAtIndex: (NSUInteger)index
{
    [self.helpLinks insertObject: object atIndex: index];
}

- (void) removeObjectFromHelpLinksAtIndex: (NSUInteger)index
{
    [self.helpLinks removeObjectAtIndex: index];
}

- (BOOL) tableView: (NSTableView *)tableView writeRowsWithIndexes: (NSIndexSet *)rowIndexes
      toPasteboard: (NSPasteboard *)pboard
{
    NSArray *dragTypes = @[kBBRowIndexSetDropType];
    [tableView registerForDraggedTypes: dragTypes];
    [pboard declareTypes: dragTypes owner: self];
    
    NSData *rowIndexData = [NSKeyedArchiver archivedDataWithRootObject: rowIndexes];
    [pboard setData: rowIndexData forType: kBBRowIndexSetDropType];
    
    return YES;
}
- (NSDragOperation) tableView: (NSTableView *)tableView
                 validateDrop: (id < NSDraggingInfo >)info
                  proposedRow: (NSInteger)row
        proposedDropOperation: (NSTableViewDropOperation)operation

{
    if (operation == NSTableViewDropOn)
    {
        [tableView setDropRow: row dropOperation: NSTableViewDropAbove];
    }
    
    return NSDragOperationMove;
}

- (BOOL)tableView: (NSTableView *)aTableView
       acceptDrop: (id <NSDraggingInfo>)info
              row: (NSInteger)row
    dropOperation: (NSTableViewDropOperation)operation
{
	NSPasteboard *pasteboard = [info draggingPasteboard];
    NSData *rowData = [pasteboard dataForType: kBBRowIndexSetDropType];
    
    if (rowData)
    {
        NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData: rowData];
        
        NSArray *draggedItems = [self.helpLinks objectsAtIndexes: rowIndexes];
        
        __block NSInteger insertionPoint = row;
        
        [rowIndexes enumerateIndexesWithOptions: NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop)
        {
            //If we're removing rows that were before the original insertion point,
            //bump the insertion point down accordingly
            if (idx < row)
                insertionPoint--;
            
            [self removeObjectFromHelpLinksAtIndex: idx];
        }];
        
        //Finally, insert the new items at the specified position
        for (NSMutableDictionary *link in draggedItems)
        {
            [self insertObject: link inHelpLinksAtIndex: insertionPoint];
            insertionPoint++;
        }
        
        return YES;
    }
    else
    {
        return NO;
    }
}


#pragma mark -
#pragma mark Drag-dropping files

- (BOOL) _isLoadableFile: (NSURL *)fileURL
{
    NSString *UTI;
    BOOL retrievedUTI = [fileURL getResourceValue: &UTI
                                           forKey: NSURLTypeIdentifierKey
                                            error: NULL];
    
    
    if (retrievedUTI)
    {
        NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    
        if ([ws type: UTI conformsToType: (NSString *)kUTTypeApplicationBundle])
            return YES;
        
        if ([ws type: UTI conformsToType: kUTTypeGamebox])
            return YES;
    }
    
    return NO;
}

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{
    NSPasteboard *pasteboard = sender.draggingPasteboard;
    if ([pasteboard.types containsObject: NSURLPboardType])
    {
        NSURL *draggedURL = [NSURL URLFromPasteboard: pasteboard];
        if ([self _isLoadableFile: draggedURL])
        {
            return NSDragOperationLink;
        }
    }
    return NSDragOperationNone;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{
    NSPasteboard *pasteboard = sender.draggingPasteboard;
    if ([pasteboard.types containsObject: NSURLPboardType])
    {
        NSURL *draggedURL = [NSURL URLFromPasteboard: pasteboard];
        if ([self _isLoadableFile: draggedURL])
        {
            return [self application: NSApp openFile: draggedURL.path];
        }
    }
    return NO;
}


#pragma mark -
#pragma mark Actions

- (IBAction) exportApp: (id)sender
{
    //Try to clear the first responder, so that if we were in the middle of editing a field
    //then those changes will be committed. If a field refuses to give up the first responder
    //(which usually means there's a validation error) then don't proceed.
    if (self.window.firstResponder && ![self.window makeFirstResponder: nil])
        return;
    
    
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.nameFieldStringValue = [self.appName stringByAppendingPathExtension: @"app"];
    panel.allowedFileTypes = @[(NSString *)kUTTypeApplicationBundle];
    panel.extensionHidden = YES;
    panel.canSelectHiddenExtension = NO;
    
    [panel beginSheetModalForWindow: self.window completionHandler: ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
        {
            //Dismiss the sheet before we begin
            [self.window.attachedSheet orderOut: self];
            
            self.busy = YES;
            [self createAppAtDestinationURL: panel.URL completion: ^(NSURL *appURL, NSError *error) {
                self.busy = NO;
                if (appURL)
                {
                    [[NSSound soundNamed: @"Glass"] play];
                    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: @[appURL]];
                }
                else
                {
                    [NSApp presentError: error
                         modalForWindow: self.window
                               delegate: nil
                     didPresentSelector: NULL
                            contextInfo: NULL];
                }
            }];
        }
    }];
}

- (IBAction) chooseIconURL: (id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    panel.allowedFileTypes = @[(NSString *)kUTTypeAppleICNS];
    panel.allowsMultipleSelection = NO;
    panel.treatsFilePackagesAsDirectories = YES;
    
    [panel beginSheetModalForWindow: self.window completionHandler: ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
        {
            self.appIconURL = panel.URL;
        }
    }];
}

- (IBAction) importSettingsFromExistingApp: (id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    panel.allowedFileTypes = @[
        (NSString *)kUTTypeApplicationBundle,
        kUTTypeGamebox
    ];
    panel.allowsMultipleSelection = NO;
    panel.treatsFilePackagesAsDirectories = NO;
    
    [panel beginSheetModalForWindow: self.window completionHandler: ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
        {
            [self application: NSApp openFile: panel.URL.path];
        }
    }];
}

- (BOOL) application: (NSApplication *)sender openFile: (NSString *)filename
{
    NSURL *fileURL = [NSURL fileURLWithPath: filename];
    
    //Determine whether this is a gamebox or a complete application
    
    BOOL opened;
    NSError *openError;
    
    NSString *UTI;
    BOOL retrievedUTI = [fileURL getResourceValue: &UTI
                                           forKey: NSURLTypeIdentifierKey
                                            error: &openError];
    
    if (retrievedUTI)
    {
        BOOL isGamebox = [[NSWorkspace sharedWorkspace] type: UTI conformsToType: kUTTypeGamebox];
        
        //If this is a gamebox, simply apply it as our current gamebox.
        if (isGamebox)
        {
            self.gameboxURL = fileURL;
            opened = YES;
        }
        //Otherwise, treat it as an application.
        else
        {
            opened = [self _loadParamsFromAppAtURL: fileURL error: &openError];
        }
    }
    else
    {
        opened = NO;
    }
    
    if (opened)
    {
        //Upon successful loading, add this item to the Recent Documents menu.
        [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL: fileURL];
    }
    else
    {
        [self.window.attachedSheet orderOut: self];
        
        [NSApp presentError: openError
             modalForWindow: self.window
                   delegate: nil
         didPresentSelector: NULL
                contextInfo: NULL];
    }
    return opened;
}


#pragma mark -
#pragma mark Helper class methods

+ (NSString *) bundleIdentifierFragmentFromString: (NSString *)inString
{
    NSString *baseName = inString.stringByDeletingPathExtension;
    
    NSString *identifier = [baseName.lowercaseString stringByReplacingOccurrencesOfString: @" " withString: @"-"];
    identifier = [identifier stringByReplacingOccurrencesOfString: @"_" withString: @"-"];
    identifier = [identifier stringByReplacingOccurrencesOfString: @"." withString: @""];
    
    return identifier;
}
@end
