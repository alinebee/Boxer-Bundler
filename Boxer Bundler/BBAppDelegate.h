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

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet BBIconDropzone *iconDropzone;

@property (strong, nonatomic) NSURL *gameboxURL;
@property (strong, nonatomic) NSURL *appIconURL;
@property (copy, nonatomic) NSString *appName;
@property (copy, nonatomic) NSString *appBundleIdentifier;
@property (copy, nonatomic) NSString *appVersion;

@property (copy, nonatomic) NSString *organizationName;
@property (copy, nonatomic) NSString *organizationURL;

@property (readonly, getter=isBusy) BOOL busy;

//An editable array of help links
@property (strong, nonatomic) NSMutableArray *helpLinks;


#pragma mark -
#pragma mark Actions

//Create a bundle.
- (IBAction) createBundle: (id)sender;

- (IBAction) chooseIconURL: (id)sender;

#pragma mark -
#pragma mark Helper class methods

//Given a filename, returns a name suitable for inclusion in a bundle identifier.
+ (NSString *) bundleIdentifierFragmentFromString: (NSString *)inString;

@end
