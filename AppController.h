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
#import <Cocoa/Cocoa.h>

@interface ManibulatorImageView : NSImageView
{
  NSURL*      _url;
  IBOutlet id _delegate;
  NSImage*    _origImage;
  BOOL        _accepting;
}
-(NSURL*)URL;
-(void)setURL:(NSURL*)url;
@end

@interface AppController : NSObject
{
  IBOutlet NSWindow*               _window;
  IBOutlet ManibulatorImageView*   _well;
  IBOutlet NSPopUpButton*          _locMenu;
  IBOutlet NSPopUpButton*          _fileMenu;
  IBOutlet NSDictionaryController* _dc;
  NSProgressIndicator*             _pind;
  NSMutableDictionary*             _dict;
  NSString*                        _locnone;
  NSThread*                        _thread;
  BOOL                             _noaccum;
}
-(IBAction)extractAction:(id)sender;
@end
