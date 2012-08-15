//
//  BBAppDelegate.h
//  Boxer Bundler
//
//  Created by Alun Bestor on 15/08/2012.
//  Copyright (c) 2012 Alun Bestor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BBIconDropzone;
@interface BBAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource>

#pragma mark -
#pragma mark Properties

@property (assign) IBOutlet NSWindow *window;

@property (copy, nonatomic) NSURL *gameboxURL;
@property (copy, nonatomic) NSString *appName;
@property (copy, nonatomic) NSString *appBundleIdentifier;
@property (copy, nonatomic) NSString *appVersion;
@property (copy, nonatomic) NSURL *appIconURL;
@property (readonly, nonatomic) NSImage *appIcon;

@property (copy, nonatomic) NSString *organizationName;
@property (copy, nonatomic) NSURL *organizationURL;

//An editable array of help links
@property (retain, nonatomic) NSMutableArray *helpLinks;


#pragma mark -
#pragma mark Actions

//Create a bundle.
- (IBAction) createBundle: (id)sender;

//Called when a new icon is dropped into the dropzone.
- (IBAction) dropIcon: (BBIconDropzone *)sender;

#pragma mark -
#pragma mark Helper class methods

//Given a filename, returns a name suitable for inclusion in a bundle identifier.
+ (NSString *) bundleIdentifierFragmentFromString: (NSString *)inString;

@end
