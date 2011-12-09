/*
Copyright © 2008-2011 Brian S. Hall

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
*/
#import <Carbon/Carbon.h>
#import "AppController.h"
#import "Onizuka.h"
#include <sys/stat.h>

@interface ManibulatorImageView (Private)
-(BOOL)validates:(id <NSDraggingInfo>)sender;
@end

@implementation ManibulatorImageView : NSImageView
-(id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  [self registerForDraggedTypes:[NSArray arrayWithObject:NSURLPboardType]];
  return self;
}

-(void)dealloc
{
  if (_url) [_url release];
  if (_origImage) [_origImage release];
  [super dealloc];
}

-(NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  #pragma unused (sender)
  (void)[super draggingEntered:sender];
  BOOL accept = [self validates:sender];
  if ([self image])
  {
    if (_origImage) [_origImage release];
    _origImage = [[self image] copy];
  }
  [self setImage:[NSImage imageNamed:(accept)? @"ArrowDown.pdf":@"NoGo.pdf"]];
  return NSDragOperationEvery;
}

-(void)draggingExited:(id <NSDraggingInfo>)sender
{
   #pragma unused (sender)
  [self setImage:(_origImage)? _origImage:nil];
}

-(void)draggingEnded:(id <NSDraggingInfo>)sender
{
  #pragma unused (sender)
  [self setImage:(_origImage && !_accepting)? _origImage:nil];
}

-(BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  BOOL accept = [self validates:sender];
  if (accept)
  {
    NSURL* url = [NSURL URLFromPasteboard:[sender draggingPasteboard]];
    [self setURL:url];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ManibulatorURL"
                                          object:self];
  }
  //if (!accept) [self setImage:nil];
  _accepting = accept;
  return accept;
}

-(BOOL)validates:(id <NSDraggingInfo>)sender
{
  BOOL valid = NO;
  SEL sel = @selector(validateDrop:);
  if (_delegate && [_delegate respondsToSelector:sel])
  {
    NSMethodSignature* methodSignature = [_delegate methodSignatureForSelector:sel];
    // could use [methodSignature methodReturnType] to validate it returns what we want
    // could use [methodSignature getArgumentTypeAtIndex] to validate it takes was we want to send it
    NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
		[invocation setTarget:_delegate];				    // index 0
		[invocation setSelector:sel];               // index 1
		[invocation setArgument:&sender atIndex:2];	// index 2
		[invocation invoke];
		[invocation getReturnValue:&valid];
  }
  return valid;
}

-(NSURL*)URL {return _url;}
-(void)setURL:(NSURL*)url
{
  [url retain];
  if (_url) [_url release];
  _url = url;
}
@end

@interface AppController (Private)
-(void)takeNote:(NSNotification*)note;
-(BOOL)candidatesForURL:(NSURL*)url;
-(BOOL)isManibulableAtPath:(NSString*)nibpath fileManager:(NSFileManager*)dm
       enumerator:(NSDirectoryEnumerator*)direnum
       localization:(NSMutableString*)loc;
-(void)_sheetDidEnd:(NSWindow*)sheet returnCode:(int)code contextInfo:(void*)ctx;
@end

@implementation AppController
-(void)awakeFromNib
{
  [[Onizuka sharedOnizuka] localizeMenu:[NSApp mainMenu]];
  [[Onizuka sharedOnizuka] localizeWindow:_window];
  [_window makeKeyAndOrderFront:self];
  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(takeNote:) name:@"ManibulatorURL" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(takeNote:) name:@"ManibulatorThread" object:nil];
  _locnone = [[Onizuka sharedOnizuka] copyLocalizedTitle:@"__NONE__"];
  NSString* where = [[NSBundle mainBundle] pathForResource:@"defaults" ofType:@"plist"];
  NSDictionary* d = [NSDictionary dictionaryWithContentsOfFile:where];
  [[NSUserDefaults standardUserDefaults] registerDefaults:d];
}

-(void)dealloc
{
  if (_locnone) [_locnone release];
  if (_dict) [_dict release];
  [super dealloc];
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)app
{
  #pragma unused (app)
  return YES;
}

-(IBAction)extractAction:(id)sender
{
  #pragma unused (sender)
  NSString* name = [[[[_well URL] path] stringByAppendingPathComponent:[[_fileMenu selectedItem] title]] lastPathComponent];
  [[NSSavePanel savePanel] beginSheetForDirectory:nil file:name
                modalForWindow:_window modalDelegate:self
                didEndSelector:@selector(_sheetDidEnd:returnCode:contextInfo:)
                contextInfo:@"EXPORT"];
}

-(void)takeNote:(NSNotification*)note
{
  if ([[note name] isEqualToString:@"ManibulatorURL"])
  {
    NSURL* url = [_well URL];
    [_well setImage:nil];
    _dict = [[NSMutableDictionary alloc] init];
    [_dc setContent:_dict];
    [_well setImage:nil];
    [_window display];
    _pind = [[NSProgressIndicator alloc] init];
    [_pind setControlSize:NSSmallControlSize];
    [_pind setStyle:NSProgressIndicatorSpinningStyle];
    NSRect piFrame = NSMakeRect(_well.bounds.size.width / 2.0,
                                _well.bounds.size.height / 2.0,
                                0.0, 0.0);
    [_pind setFrame:piFrame];
    [_pind setIndeterminate:YES];
    [_pind setDisplayedWhenStopped:NO];
    [_pind setHidden:NO];
    [_pind setAutoresizingMask:(NSViewMaxXMargin | NSViewMinXMargin |
                               NSViewMaxYMargin | NSViewMinYMargin)]; 
    [_pind sizeToFit];
    piFrame = [_pind frame];
    piFrame.origin.x -= (piFrame.size.width / 2.0);
    piFrame.origin.y -= (piFrame.size.height / 2.0);
    [_pind setFrame:piFrame];
    [_well addSubview:_pind];
    [_pind setUsesThreadedAnimation:YES];
    [_pind startAnimation:self];
    _thread = [[NSThread alloc] initWithTarget:self selector:@selector(vcandidatesForURL:) object:url];
    [_thread start];
  }
  else if ([[note name] isEqualToString:@"ManibulatorThread"])
  {
    [_pind stopAnimation:self];
    [_pind removeFromSuperview];
    [_pind release];
    NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:[[_well URL] path]];
    [_well setImage:icon];
    [_dc setContent:_dict];
    if (_dict) [_dict release];
    _dict = nil;
    [_thread release];
    _thread = nil;
  }
}

-(NSDragOperation)validateDrop:(id <NSDraggingInfo>)sender
{
  if (_thread) return NSDragOperationNone;
  NSURL* url = [NSURL URLFromPasteboard:[sender draggingPasteboard]];
  if (_dict) [_dict release];
  _dict = nil;
  return ([self candidatesForURL:url])?
         NSDragOperationEvery:NSDragOperationNone;
}

-(void)vcandidatesForURL:(NSURL*)url
{
  NSAutoreleasePool* arp = [[NSAutoreleasePool alloc] init];
  (void)[self candidatesForURL:url];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"ManibulatorThread"
                                        object:self];
  [arp release];
}

-(BOOL)candidatesForURL:(NSURL*)url
{
  BOOL gotOne = NO;
  NSString* path = [url path];
  NSFileManager* dm = [NSFileManager defaultManager];
  BOOL isDir;
  BOOL ignore = [[NSUserDefaults standardUserDefaults] boolForKey:@"ignoreFrameworks"];
  NSMutableString* loc = [[NSMutableString alloc] init];
  if ([dm fileExistsAtPath:path isDirectory:&isDir] && isDir)
  {
    NSDirectoryEnumerator* direnum = [dm enumeratorAtPath:path];
    NSString* pname;
    NSAutoreleasePool* arp = [[NSAutoreleasePool alloc] init];
    while ((pname = [direnum nextObject]))
    {
      //NSLog(@"%@", pname);
      if (ignore && [[pname lastPathComponent] isEqualToString:@"Frameworks"])
      {
        [direnum skipDescendents];
        continue;
      }
      if ([[pname pathExtension] isEqualToString:@"nib"])
      {
        NSString* nibpath = [path stringByAppendingPathComponent:pname];
        if ([self isManibulableAtPath:nibpath fileManager:dm enumerator:direnum
                  localization:loc])
        {
          gotOne = YES;
          //NSLog(@"%@ is COMPILED, loc %@", pname, loc);
          NSObject* key = ([loc length])? [[loc copy] autorelease]:_locnone;
          if (_dict)
          {
            NSMutableArray* a = [_dict objectForKey:key];
            if (!a)
            {
              a = [[NSMutableArray alloc] init];
              [_dict setObject:a forKey:key];
              [a release];
            }
            [a addObject:pname];
          }
          else
          {
            gotOne = YES;
            goto Cleanup;
          }
        }
      } // is .nib
      if (arp) [arp release];
      arp = [[NSAutoreleasePool alloc] init];
    } // while loop
    if (arp) [arp release];
  }
Cleanup:
  [loc release];
  return gotOne;
}

-(BOOL)isManibulableAtPath:(NSString*)nibpath fileManager:(NSFileManager*)dm
       enumerator:(NSDirectoryEnumerator*)direnum
       localization:(NSMutableString*)loc
{
  const char* nibpathc = [[NSFileManager defaultManager]
                           fileSystemRepresentationWithPath:nibpath];
  struct stat fileInfo;
  if (lstat(nibpathc, &fileInfo) < 0) return NO;
  if (S_ISLNK(fileInfo.st_mode)) return NO;
  FSRef fsref;
  Boolean isDir;
  OSStatus err = FSPathMakeRefWithOptions((UInt8*)nibpathc,
                                  kFSPathMakeRefDoNotFollowLeafSymlink,
                                  &fsref, &isDir);
  if (err != noErr) return NO;
  Boolean isAlias;
  err = FSIsAliasFile(&fsref, &isAlias, &isDir);
  if (err || isAlias) return NO;
  BOOL isDirB;
  if ([dm fileExistsAtPath:nibpath isDirectory:&isDirB])
  {
    if (isDirB)
    {
      [direnum skipDescendents];
      NSArray* contents = [dm contentsOfDirectoryAtPath:nibpath error:NULL];
      if ([contents count] == 2 &&
          (([[[contents objectAtIndex:0] lastPathComponent] isEqualToString:@"keyedobjects.nib"] &&
            [[[contents objectAtIndex:1] lastPathComponent] isEqualToString:@"objects.nib"]) ||
           ([[[contents objectAtIndex:1] lastPathComponent] isEqualToString:@"keyedobjects.nib"] &&
            [[[contents objectAtIndex:0] lastPathComponent] isEqualToString:@"objects.nib"])))
      {
        
      }
      else return NO;
    }
    [loc setString:@""];
    for (NSString* comp in [nibpath pathComponents])
    {
      if ([[comp pathExtension] isEqualToString:@"lproj"])
      {
        NSRange range = [comp rangeOfString:@".lproj" options:NSBackwardsSearch];
        [loc setString:[comp substringToIndex:range.location]];
        break;
      }
    }
  }
  return YES;
}

// If the source file is a single file, copy it into my internal nib as
// keyedobjects.nib
// If the source file is a directory, copy it to the destination and populate
// it with classes.nib and info.nib
-(void)_sheetDidEnd:(NSWindow*)sheet returnCode:(int)code contextInfo:(void*)ctx
{
  [sheet orderOut:self];
  if (code != NSAlertDefaultReturn) return;
  NSFileManager* dm = [NSFileManager defaultManager];
  NSError* error = nil;
  BOOL success;
  if ([(NSString*)ctx isEqualToString:@"EXPORT"])
  {
    NSSavePanel* sp = (NSSavePanel*)sheet;
    NSString* inpath = [[[_well URL] path] stringByAppendingPathComponent:[[_fileMenu selectedItem] title]];
    NSString* outpath = [[sp URL] path];
    BOOL isDir;
    [dm removeItemAtPath:outpath error:NULL];
    if (![dm fileExistsAtPath:inpath isDirectory:&isDir]) return;
    NSString* nibpath = [[NSBundle mainBundle] pathForResource:@"v2" ofType:@"nib"];
    if (isDir)
    {
      success = [dm copyItemAtPath:inpath toPath:outpath error:&error];
      NSString* infilepath = [nibpath stringByAppendingPathComponent:@"info.nib"];
      NSString* outfileopath = [outpath stringByAppendingPathComponent:@"info.nib"];
      success = [dm copyItemAtPath:infilepath toPath:outfileopath error:&error];
      infilepath = [nibpath stringByAppendingPathComponent:@"classes.nib"];
      outfileopath = [outpath stringByAppendingPathComponent:@"classes.nib"];
      success = [dm copyItemAtPath:infilepath toPath:outfileopath error:&error];
      //NSLog(@"%@", error);
    }
    else
    {
      NSString* keyedpath = [outpath stringByAppendingPathComponent:@"keyedobjects.nib"];
      //NSLog(@"I will copy %@ into my internal doc at %@ at %@", inpath, nibpath, outpath);
      (void)[dm copyItemAtPath:nibpath toPath:outpath error:&error];
      [dm removeItemAtPath:keyedpath error:NULL];
      (void)[dm copyItemAtPath:inpath toPath:keyedpath error:&error];
    }
    BOOL xib = [[NSUserDefaults standardUserDefaults] boolForKey:@"convertXIB"];
    if (xib)
    {
      NSString* systemStr = [[NSString alloc] initWithFormat:@"ibtool --upgrade \"%@\" > /dev/null 2>&1", outpath];
      system([systemStr UTF8String]);
      [systemStr release];
    }
  }
}
@end



