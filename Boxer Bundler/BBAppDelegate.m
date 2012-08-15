//
//  BBAppDelegate.m
//  Boxer Bundler
//
//  Created by Alun Bestor on 15/08/2012.
//  Copyright (c) 2012 Alun Bestor. All rights reserved.
//

#import "BBAppDelegate.h"
#import "BBURLTransformer.h"
#import "BBIconDropzone.h"

NSString * const kBBRowIndexSetDropType = @"BBRowIndexSetDropType";

NSString * const kBBValidationErrorDomain = @"net.washboardabs.boxer-bundler.validationErrorDomain";

enum {
    kBBValidationValueMissing,
    kBBValidationInvalidValue
};


@interface BBAppDelegate ()

@property (assign, getter=isBusy) BOOL busy;

@end


@implementation BBAppDelegate
@synthesize helpLinks = _helpLinks;
@synthesize busy = _busy;

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

- (void) dealloc
{
    self.helpLinks = nil;
    
    [super dealloc];
}

- (void) applicationDidFinishLaunching: (NSNotification *)aNotification
{
    //Load initial defaults
    NSString *defaultsPath	= [[NSBundle mainBundle] pathForResource: @"UserDefaults" ofType: @"plist"];
    NSDictionary *defaults	= [NSDictionary dictionaryWithContentsOfFile: defaultsPath];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaults];
    
    [self.window makeKeyAndOrderFront: self];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)sender
{
    return YES;
}


#pragma mark -
#pragma mark Properties

- (NSURL *) gameboxURL
{
    NSString *path = [[NSUserDefaults standardUserDefaults] objectForKey: @"gameboxPath"];
    if (path.length)
        return [NSURL fileURLWithPath: path];
    else
        return nil;
}

- (void) setGameboxURL: (NSURL *)URL
{
    URL = URL.URLByStandardizingPath;
    if (![URL isEqual: self.gameboxURL])
    {
        [[NSUserDefaults standardUserDefaults] setObject: URL.path forKey: @"gameboxPath"];
        
        //Update the application name whenever the gamebox changes
        self.appName = URL.lastPathComponent.stringByDeletingPathExtension;
    }
}

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
            BOOL isGamebox = [[NSWorkspace sharedWorkspace] type: UTI conformsToType: @"net.washboardabs.boxer-game-package"];
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



- (void) setAppIconURL: (NSURL *)URL
{
    URL = URL.URLByStandardizingPath;
    [[NSUserDefaults standardUserDefaults] setObject: URL.path forKey: @"appIconPath"];
}

- (NSURL *) appIconURL
{
    NSString *iconPath = [[NSUserDefaults standardUserDefaults] objectForKey: @"appIconPath"];
    if (iconPath.length)
        return [NSURL fileURLWithPath: iconPath];
    else
        return nil;
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



+ (NSSet *) keyPathsForValuesAffectingAppIcon
{
    return [NSSet setWithObject: @"appIconURL"];
}

- (NSImage *) appIcon
{
    if (self.appIconURL)
        return [[[NSImage alloc] initWithContentsOfURL: self.appIconURL] autorelease];
    else
        return nil;
}

//Defined only to keep the UI binding happy, as otherwise it would throw an assertion if the user
//clears the icon selection.
- (void) setAppIcon: (NSImage *)icon
{
}


- (void) setAppName: (NSString *)name
{
    if (![self.appName isEqualToString: name])
    {
        [[NSUserDefaults standardUserDefaults] setObject: name forKey: @"appName"];
        
        //Synchronize the bundle identifier whenever the application name changes
        if (name.length)
        {
            NSString *fragment = [self.class bundleIdentifierFragmentFromString: name];
            [self setAppBundleIdentifierFragment: fragment];
        }
    }
}

- (NSString *) appName
{
    return [[NSUserDefaults standardUserDefaults] objectForKey: @"appName"];
}

- (BOOL) validateAppName: (id *)ioValue error: (NSError **)outError
{
    NSString *appName = *ioValue;
    if (!appName.length)
    {
        *outError = [self _validationErrorWithCode: kBBValidationValueMissing
                                           message: @"Please specify a name for the application."];
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

- (void) setAppBundleIdentifier: (NSString *)identifier
{
    [[NSUserDefaults standardUserDefaults] setObject: identifier forKey: @"appBundleIdentifier"];
}

- (NSString *) appBundleIdentifier
{
    return [[NSUserDefaults standardUserDefaults] objectForKey: @"appBundleIdentifier"];
}

- (BOOL) validateAppBundleIdentifier: (id *)ioValue error: (NSError **)outError
{
    NSString *bundleIdentifier = *ioValue;
    if (!bundleIdentifier.length)
    {
        *outError = [self _validationErrorWithCode: kBBValidationValueMissing
                                           message: @"Please specify a bundle identifier for the application: e.g. 'com.companyname.game-name'."];
        
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

- (NSString *) appVersion
{
    return [[NSUserDefaults standardUserDefaults] objectForKey: @"appVersion"];
}

- (void) setAppVersion: (NSString *)appVersion
{
    [[NSUserDefaults standardUserDefaults] setObject: appVersion
                                              forKey: @"appVersion"];
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


- (NSString *) organizationName
{
    return [[NSUserDefaults standardUserDefaults] objectForKey: @"organizationName"];
}

- (void) setOrganizationName: (NSString *)organizationName
{
    [[NSUserDefaults standardUserDefaults] setObject: organizationName
                                              forKey: @"organizationName"];
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

- (NSURL *) organizationURL
{
    NSString *URLString = [[NSUserDefaults standardUserDefaults] objectForKey: @"organizationURL"];
    if (URLString.length)
        return [NSURL URLWithString: URLString];
    else
        return nil;
}

- (void) setOrganizationURL: (NSURL *)organizationURL
{
    [[NSUserDefaults standardUserDefaults] setObject: organizationURL.absoluteString
                                              forKey: @"organizationURL"];
}

- (BOOL) validateOrganizationURL: (id *)ioValue error: (NSError **)outError
{
    NSURL *URL = *ioValue;
    
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
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject: message forKey: NSLocalizedDescriptionKey];
    return [NSError errorWithDomain: kBBValidationErrorDomain code: errCode userInfo: userInfo];
}



#pragma mark -
#pragma mark Editing help links

- (NSArray *) helpLinks
{
    //Create the help links array the first time it is needed
    if (!_helpLinks)
    {
        NSArray *helpLinks = [[NSUserDefaults standardUserDefaults] objectForKey: @"helpLinks"];
        _helpLinks = [[NSMutableArray alloc] initWithCapacity: helpLinks.count];
        for (NSDictionary *linkInfo in helpLinks)
        {
            [_helpLinks addObject: [[linkInfo mutableCopy] autorelease]];
        }
    }
    return _helpLinks;
}

- (void) _syncHelpLinks
{
    [[NSUserDefaults standardUserDefaults] setObject: self.helpLinks forKey: @"helpLinks"];
}

- (void) setHelpLinks: (NSMutableArray *)helpLinks
{
    if (![helpLinks isEqualToArray: _helpLinks])
    {
        [_helpLinks release];
        _helpLinks = [helpLinks retain];
        
        [self _syncHelpLinks];
    }
}

- (void) insertObject: (NSMutableDictionary *)object inHelpLinksAtIndex: (NSUInteger)index
{
    [self.helpLinks insertObject: object atIndex: index];
    
    [self _syncHelpLinks];
}

- (void) removeObjectFromHelpLinksAtIndex: (NSUInteger)index
{
    [self.helpLinks removeObjectAtIndex: index];
    [self _syncHelpLinks];
}

- (void) tableView: (NSTableView *)tableView
    setObjectValue: (id)object
    forTableColumn: (NSTableColumn *)tableColumn
               row: (NSInteger)row
{
    [self _syncHelpLinks];
}

- (BOOL) tableView: (NSTableView *)tableView writeRowsWithIndexes: (NSIndexSet *)rowIndexes
      toPasteboard: (NSPasteboard *)pboard
{
    NSArray *dragTypes = [NSArray arrayWithObject: kBBRowIndexSetDropType];
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
#pragma mark Actions


- (IBAction) createBundle: (id)sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.nameFieldStringValue = [self.appName stringByAppendingPathExtension: @"app"];
    panel.allowedFileTypes = [NSArray arrayWithObject: (NSString *)kUTTypeApplicationBundle];
    panel.extensionHidden = YES;
    panel.canSelectHiddenExtension = NO;
    
    [panel beginSheetModalForWindow: self.window completionHandler: ^(NSInteger result)
    {
        if (result == NSFileHandlingPanelOKButton)
        {
            //Dismiss any previous sheet before displaying error/success
            [self.window.attachedSheet orderOut: self];
            
            [self createAppAtDestinationURL: panel.URL];
        }
    }];
}

- (void) createAppAtDestinationURL: (NSURL *)destinationURL
{
    NSURL *bundledAppURL = [[NSBundle mainBundle] URLForResource: @"Boxer Standalone" withExtension: @"app"];
    
    self.busy = YES;
    
    dispatch_queue_t queue = dispatch_queue_create("CreationQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        NSError *creationError;
        BOOL created = [self createAppAtDestinationURL: destinationURL usingAppAtSourceURL: bundledAppURL error: &creationError];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.busy = NO;
            
            [[NSSound soundNamed: @"Glass"] play];
            
            if (!created)
            {
                [NSApp presentError: creationError
                     modalForWindow: self.window
                           delegate: nil
                 didPresentSelector: NULL
                        contextInfo: NULL];
            }
            else
            {
                [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: [NSArray arrayWithObject: destinationURL]];
            }
        });
    });
}

- (BOOL) createAppAtDestinationURL: (NSURL *)destinationURL
               usingAppAtSourceURL: (NSURL *)sourceURL
                             error: (NSError **)outError
{
    NSFileManager *manager = [[[NSFileManager alloc] init] autorelease];
    
    //Delete any file at the destination
    [manager removeItemAtURL: destinationURL error: NULL];
    
    BOOL copied = [manager copyItemAtURL: sourceURL toURL: destinationURL error: outError];
    if (!copied)
    {
        return NO;
    }
    
    
    //Copy across the gamebox.
    NSURL *appResourceURL = [destinationURL URLByAppendingPathComponent: @"Contents/Resources/"];
    NSString *gameboxDestinationName = [self.appName stringByAppendingPathExtension: @"boxer"];
    NSURL *gameboxDestinationURL = [appResourceURL URLByAppendingPathComponent: gameboxDestinationName];
    
    BOOL copiedGamebox = [manager copyItemAtURL: self.gameboxURL toURL: gameboxDestinationURL error: outError];
    if (!copiedGamebox)
    {
        [manager removeItemAtURL: destinationURL error: NULL];
        return NO;
    }
    //Clean up the gamebox while we're at it: eliminate any custom icon and unhide the file extension.
    [[NSWorkspace sharedWorkspace] setIcon: nil forFile: gameboxDestinationURL.path options: 0];
    [gameboxDestinationURL setResourceValue: [NSNumber numberWithBool: NO] forKey: NSURLHasHiddenExtensionKey error: nil];

    
    //Copy across the application icon.
    if (self.appIconURL)
    {
        NSURL *iconDestinationURL = [appResourceURL URLByAppendingPathComponent: @"app.icns"];
        BOOL copiedIcon = [manager copyItemAtURL: self.appIconURL toURL: iconDestinationURL error: outError];
        if (!copiedIcon)
        {
            [manager removeItemAtURL: destinationURL error: NULL];
            return NO;
        }
    }
    
    
    //Rewrite the application's Info.plist to fill it with our own data.
    NSURL *appPlistURL = [destinationURL URLByAppendingPathComponent: @"Contents/Info.plist"];
    
    NSMutableDictionary *appPlistContents = [NSMutableDictionary dictionaryWithContentsOfURL: appPlistURL];
    
    NSMutableDictionary *substitutions = [NSMutableDictionary dictionary];
    
    CFGregorianDate currentDate = CFAbsoluteTimeGetGregorianDate(CFAbsoluteTimeGetCurrent(), CFTimeZoneCopySystem());
    
    [substitutions setObject: [NSString stringWithFormat: @"%04d", currentDate.year] forKey: @"{{YEAR}}"];
    if (self.organizationName)
        [substitutions setObject: self.organizationName forKey: @"{{ORGANIZATION_NAME}}"];
    
    if (self.appBundleIdentifier)
        [substitutions setObject: self.appBundleIdentifier forKey: @"{{BUNDLE_IDENTIFIER}}"];
    
    if (self.appName)
        [substitutions setObject: self.appName forKey: @"{{APPLICATION_NAME}}"];
    
    if (self.organizationURL)
        [substitutions setObject: self.organizationURL.absoluteString forKey: @"{{ORGANIZATION_URL}}"];
    
    if (self.appVersion)
        [substitutions setObject: self.appVersion forKey: @"{{APPLICATION_VERSION}}"];
    
    //Replace all instances of the strings above across every key.
    //Note that this will currently not recurse into arrays and dictionaries.
    for (NSString *key in appPlistContents.allKeys)
    {
        id value = [appPlistContents valueForKey: key];
        
        if ([value respondsToSelector: @selector(stringByReplacingOccurrencesOfString:withString:)])
        {
            for (NSString *pattern in substitutions)
            {
                NSString *replacement = [substitutions objectForKey: pattern];
                value = [value stringByReplacingOccurrencesOfString: pattern withString: replacement];
            }
            
            [appPlistContents setObject: value forKey: key];
        }
    }
    
    //Add in the specified help links
    if (self.helpLinks.count)
    {
        NSMutableArray *helpLinks = [NSMutableArray arrayWithCapacity: self.helpLinks.count];
        for (NSDictionary *linkInfo in self.helpLinks)
        {
            NSDictionary *plistVersion = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          [linkInfo objectForKey: @"title"], @"BXHelpLinkTitle",
                                          [linkInfo objectForKey: @"url"],  @"BXHelpLinkURL",
                                          nil];
            
            [helpLinks addObject: plistVersion];
        }
        
        [appPlistContents setObject: helpLinks forKey: @"BXHelpLinks"];
    }
    
    [appPlistContents setObject: self.appName forKey: @"BXBundledGameboxName"];
    
    if (self.appIconURL)
        [appPlistContents setObject: @"app.icns" forKey: @"CFBundleIconFile"];
    
    
    //Phew! Now let's get to work on the help book.
    NSString *helpbookName = [appPlistContents objectForKey: @"CFBundleHelpBookFolder"];
    if (helpbookName)
    {
        //While we're at it, rename the help book to reflect the application name.
        NSString *destinationHelpbookName = [self.appName stringByAppendingPathExtension: @"help"];
        
        NSURL *helpbookURL = [appResourceURL URLByAppendingPathComponent: helpbookName];
        NSURL *destinationHelpbookURL = [appResourceURL URLByAppendingPathComponent: destinationHelpbookName];
        
        //Since this isn't a necessary step, ignore it if it happens to fail.
        BOOL renamedHelpbook = [manager moveItemAtURL: helpbookURL toURL: destinationHelpbookURL error: NULL];
        if (renamedHelpbook)
        {
            helpbookURL = destinationHelpbookURL;
            [appPlistContents setObject: destinationHelpbookName forKey: @"CFBundleHelpBookFolder"];
        }
        
        NSURL *helpbookPlistURL = [helpbookURL URLByAppendingPathComponent: @"Contents/Info.plist"];
        NSMutableDictionary *helpbookPlistContents = [NSMutableDictionary dictionaryWithContentsOfURL: helpbookPlistURL];
        
        for (NSString *key in helpbookPlistContents.allKeys)
        {
            id value = [helpbookPlistContents valueForKey: key];
            
            if ([value respondsToSelector: @selector(stringByReplacingOccurrencesOfString:withString:)])
            {
                for (NSString *pattern in substitutions)
                {
                    NSString *replacement = [substitutions objectForKey: pattern];
                    value = [value stringByReplacingOccurrencesOfString: pattern withString: replacement];
                }
                
                [helpbookPlistContents setObject: value forKey: key];
            }
        }
        
        //Extract 16x16 version of the icon URL to use for the help book.
        NSString *helpbookIconName = [helpbookPlistContents objectForKey: @"HPDBookIconPath"];
        if (self.appIconURL && helpbookIconName)
        {
            
            NSString *helpbookIcon2xName = [NSString stringWithFormat: @"%@@2x.%@",
                                            helpbookIconName.stringByDeletingPathExtension,
                                            helpbookIconName.pathExtension];
            
            NSURL *helpbookResourceURL = [helpbookURL URLByAppendingPathComponent: @"Contents/Resources/"];
            NSURL *helpbookIconURL = [helpbookResourceURL URLByAppendingPathComponent: helpbookIconName];
            NSURL *helpbookIcon2xURL = [helpbookResourceURL URLByAppendingPathComponent: helpbookIcon2xName];
            
            
            NSImage *icon = [[NSImage alloc] initWithContentsOfURL: self.appIconURL];
            
            NSBitmapImageRep *sourceRep = nil;
            NSBitmapImageRep *source2xRep = nil;
            NSSize targetSize = NSMakeSize(16, 16), target2xSize = NSMakeSize(32, 32);
            for (NSBitmapImageRep *rep in icon.representations)
            {
                if (![rep isKindOfClass: [NSBitmapImageRep class]])
                    continue;
                
                NSSize size = rep.size;
                //Bingo, we found the 16x16 representations
                if (NSEqualSizes(size, targetSize))
                {
                    NSSize pixelSize = NSMakeSize(rep.pixelsWide, rep.pixelsHigh);
                    
                    //Regular 16x16 icon found!
                    if (!sourceRep && NSEqualSizes(pixelSize, targetSize))
                    {
                        sourceRep = rep;
                    }
                    else if (!source2xRep && NSEqualSizes(pixelSize, target2xSize))
                    {
                        source2xRep = rep;
                    }
                }
                //Stop looking once we've found good candidates for both resolutions.
                if (sourceRep && source2xRep) break;
            }
            
            if (sourceRep)
            {
                NSData *data = [sourceRep representationUsingType: NSPNGFileType properties: nil];
                BOOL wroteIcon = [data writeToURL: helpbookIconURL options: NSAtomicWrite error: outError];
                if (!wroteIcon)
                {
                    [manager removeItemAtURL: destinationURL error: NULL];
                    return NO;
                }
            }
            
            if (source2xRep)
            {
                NSData *data = [source2xRep representationUsingType: NSPNGFileType properties: nil];
                BOOL wroteIcon = [data writeToURL: helpbookIcon2xURL options: NSAtomicWrite error: outError];
                if (!wroteIcon)
                {
                    [manager removeItemAtURL: destinationURL error: NULL];
                    return NO;
                }
            }
        }
        
        //Write all of our changes to the helpbook's plist back into the helpbook.
        [helpbookPlistContents writeToURL: helpbookPlistURL atomically: YES];
    }
    
    
    //Write all of our changes to the app's plist back into the app.
    [appPlistContents writeToURL: appPlistURL atomically: YES];
    
    return YES;
}

- (IBAction) dropIcon: (BBIconDropzone *)sender
{
    self.appIconURL = sender.imageURL;
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
