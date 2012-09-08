//
//  BBAppDelegate.h
//  Boxer Bundler
//
//  Created by Alun Bestor on 15/08/2012.
//  Copyright (c) 2012 Alun Bestor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BBIconDropzone;
@interface BBAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSWindowDelegate>

#pragma mark -
#pragma mark Properties

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet BBIconDropzone *iconDropzone;

@property (strong, nonatomic) NSURL *gameboxURL;
@property (strong, nonatomic) NSURL *appIconURL;
@property (copy, nonatomic) NSString *appName;
@property (copy, nonatomic) NSString *appBundleIdentifier;
@property (copy, nonatomic) NSString *appVersion;

@property (copy, nonatomic) NSString *organizationName;
@property (copy, nonatomic) NSString *organizationURL;

@property (nonatomic) BOOL showsHotkeyWarning;
@property (nonatomic) BOOL ctrlClickEnabled;

@property (readonly, getter=isBusy) BOOL busy;

//A version of the app name suitable for use as a filename.
//This replaces or removes restricted characters like :, / and \.
@property (readonly, nonatomic) NSString *sanitisedAppName;

//An editable array of help links
@property (strong, nonatomic) NSMutableArray *helpLinks;


#pragma mark -
#pragma mark Actions

//Create a bundle.
- (IBAction) exportApp: (id)sender;

- (IBAction) chooseIconURL: (id)sender;

- (IBAction) importSettingsFromExistingApp: (id)sender;


#pragma mark -
#pragma mark Helper class methods

//Given a filename, returns a name suitable for inclusion in a bundle identifier.
+ (NSString *) bundleIdentifierFragmentFromString: (NSString *)inString;

@end
