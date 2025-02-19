#import "MacDarkMode.hpp"
#include "wx/osx/core/cfstring.h"

#import <algorithm>

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <AppKit/NSScreen.h>

#include <objc/runtime.h>

@interface MacDarkMode : NSObject {}
@end

@implementation MacDarkMode

namespace Slic3r {
namespace GUI {

NSTextField* mainframe_text_field = nil;

bool mac_dark_mode()
{
    NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    return style && [style isEqualToString:@"Dark"];

}

double mac_max_scaling_factor()
{
    double scaling = 1.;
    if ([NSScreen screens] == nil) {
        scaling = [[NSScreen mainScreen] backingScaleFactor];
    } else {
	    for (int i = 0; i < [[NSScreen screens] count]; ++ i)
	    	scaling = std::max<double>(scaling, [[[NSScreen screens] objectAtIndex:0] backingScaleFactor]);
	}
    return scaling;
}
    
void set_miniaturizable(void * window)
{
    CGFloat rFloat = 38/255.0;
    CGFloat gFloat = 46/255.0;
    CGFloat bFloat = 48/255.0;
    [(NSView*) window window].titlebarAppearsTransparent = true;
    [(NSView*) window window].backgroundColor = [NSColor colorWithCalibratedRed:rFloat green:gFloat blue:bFloat alpha:1.0];
    [(NSView*) window window].styleMask |= NSMiniaturizableWindowMask;

    NSEnumerator *viewEnum = [[[[[[[(NSView*) window window] contentView] superview] titlebarViewController] view] subviews] objectEnumerator];
    NSView *viewObject;

    while(viewObject = (NSView *)[viewEnum nextObject]) {
        if([viewObject class] == [NSTextField self]) {
            //[(NSTextField*)viewObject setTextColor :  NSColor.whiteColor];
            mainframe_text_field = viewObject;
        }
    }
}

void set_title_colour_after_set_title()
{
    if(mainframe_text_field){
        [(NSTextField*)mainframe_text_field setTextColor :  NSColor.whiteColor];
    }
}

void WKWebView_evaluateJavaScript(void * web, wxString const & script, void (*callback)(wxString const &))
{
    [(WKWebView*)web evaluateJavaScript:wxCFStringRef(script).AsNSString() completionHandler: ^(id result, NSError *error) {
        if (callback && error != nil) {
            wxString err = wxCFStringRef(error.localizedFailureReason).AsString();
            callback(err);
        }
    }];
}
    
}
}

@end

/* textColor for NSTextField */
@implementation NSTextField (NSTextField_Extended)

- (void)setTextColor2:(NSColor *)textColor
{
    if (Slic3r::GUI::mainframe_text_field != self){
        [self setTextColor2: textColor];
    }else{
        [self setTextColor2 : NSColor.whiteColor];
    }
}


+ (void) load
{
    Method setTextColor = class_getInstanceMethod([NSTextField class], @selector(setTextColor:));
    Method setTextColor2 = class_getInstanceMethod([NSTextField class], @selector(setTextColor2:));
    method_exchangeImplementations(setTextColor, setTextColor2);
}

@end

/* textColor for NSButton */

@implementation NSButton (NSButton_Extended)

- (NSColor *)textColor
{
    NSAttributedString *attrTitle = [self attributedTitle];
    int len = [attrTitle length];
    NSRange range = NSMakeRange(0, MIN(len, 1)); // get the font attributes from the first character
    NSDictionary *attrs = [attrTitle fontAttributesInRange:range];
    NSColor *textColor = [NSColor controlTextColor];
    if (attrs)
    {
        textColor = [attrs objectForKey:NSForegroundColorAttributeName];
    }
    
    return textColor;
}

- (void)setTextColor:(NSColor *)textColor
{
    NSMutableAttributedString *attrTitle =
        [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedTitle]];
    int len = [attrTitle length];
    NSRange range = NSMakeRange(0, len);
    [attrTitle addAttribute:NSForegroundColorAttributeName value:textColor range:range];
    [attrTitle fixAttributesInRange:range];
    [self setAttributedTitle:attrTitle];
    [attrTitle release];
}

- (void)setBezelStyle2:(NSBezelStyle)bezelStyle
{
    if (bezelStyle != NSBezelStyleShadowlessSquare)
        [self setBordered: YES];
    [self setBezelStyle2: bezelStyle];
}

+ (void) load
{
    Method setBezelStyle = class_getInstanceMethod([NSButton class], @selector(setBezelStyle:));
    Method setBezelStyle2 = class_getInstanceMethod([NSButton class], @selector(setBezelStyle2:));
    method_exchangeImplementations(setBezelStyle, setBezelStyle2);
}

- (NSFocusRingType) focusRingType
{
    return NSFocusRingTypeNone;
}

@end

/* edit column for wxTableView */

#include <wx/dataview.h>
#include <wx/osx/cocoa/dataview.h>
#include <wx/osx/dataview.h>

@implementation wxCocoaOutlineView (Edit)

- (BOOL)outlineView: (NSOutlineView*) view shouldEditTableColumn:(nullable NSTableColumn *)tableColumn item:(nonnull id)item
{
    wxDataViewColumn* const col((wxDataViewColumn *)[tableColumn getColumnPointer]);
    wxDataViewItem item2([static_cast<wxPointerObject *>(item) pointer]);

    wxDataViewCtrl* const dvc = implementation->GetDataViewCtrl();
    // Before doing anything we send an event asking if editing of this item is really wanted.
    wxDataViewEvent event(wxEVT_DATAVIEW_ITEM_EDITING_STARTED, dvc, col, item2);
    dvc->GetEventHandler()->ProcessEvent( event );
    if( !event.IsAllowed() )
        return NO;
    return YES;
}

@end

/* remove focused border for wxTextCtrl */

@implementation NSTextField (FocusRing)

- (NSFocusRingType) focusRingType
{
    return NSFocusRingTypeNone;
}

@end

/* gesture handle for Canvas3D */

@interface wxNSCustomOpenGLView : NSOpenGLView
{
}
@end


@implementation wxNSCustomOpenGLView (Gesture)

wxEvtHandler * _gestureHandler = nullptr;

- (void) onGestureMove: (NSPanGestureRecognizer*) gesture
{
    wxPanGestureEvent evt;
    NSPoint tr = [gesture translationInView: self];
    evt.SetDelta({(int) tr.x, (int) tr.y});
    [self postEvent:evt withGesture:gesture];
}

- (void) onGestureScale: (NSMagnificationGestureRecognizer*) gesture
{
    wxZoomGestureEvent evt;
    evt.SetZoomFactor(gesture.magnification + 1.0);
    [self postEvent:evt withGesture:gesture];
}

- (void) onGestureRotate: (NSRotationGestureRecognizer*) gesture
{
    wxRotateGestureEvent evt;
    evt.SetRotationAngle(-gesture.rotation);
    [self postEvent:evt withGesture:gesture];
}

- (void) postEvent: (wxGestureEvent &) evt withGesture: (NSGestureRecognizer* ) gesture
{
    NSPoint pos = [gesture locationInView: self];
    evt.SetPosition({(int) pos.x, (int) pos.y});
    if (gesture.state == NSGestureRecognizerStateBegan)
        evt.SetGestureStart();
    else if (gesture.state == NSGestureRecognizerStateEnded)
        evt.SetGestureEnd();
    _gestureHandler->ProcessEvent(evt);
}

- (void) scrollWheel2:(NSEvent *)event
{
    bool shiftDown = [event modifierFlags] & NSShiftKeyMask;
    if (_gestureHandler && shiftDown && event.hasPreciseScrollingDeltas) {
        wxPanGestureEvent evt;
        evt.SetDelta({-(int)[event scrollingDeltaX], -	(int)[event scrollingDeltaY]});
        _gestureHandler->ProcessEvent(evt);
    } else {
        [self scrollWheel2: event];
    }
}

+ (void) load
{
    Method scrollWheel = class_getInstanceMethod([wxNSCustomOpenGLView class], @selector(scrollWheel:));
    Method scrollWheel2 = class_getInstanceMethod([wxNSCustomOpenGLView class], @selector(scrollWheel2:));
    method_exchangeImplementations(scrollWheel, scrollWheel2);
}

- (void) initGesturesWithHandler: (wxEvtHandler*) handler
{
//    NSPanGestureRecognizer * pan = [[NSPanGestureRecognizer alloc] initWithTarget: self action: @selector(onGestureMove:)];
//    pan.numberOfTouchesRequired = 2;
//    pan.allowedTouchTypes = 0;
//    NSMagnificationGestureRecognizer * magnification = [[NSMagnificationGestureRecognizer alloc] initWithTarget: self action: @selector(onGestureScale:)];
//    NSRotationGestureRecognizer * rotation = [[NSRotationGestureRecognizer alloc] initWithTarget: self action: @selector(onGestureRotate:)];
//    [self addGestureRecognizer:pan];
//    [self addGestureRecognizer:magnification];
//    [self addGestureRecognizer:rotation];
    _gestureHandler = handler;
}

@end

namespace Slic3r {
namespace GUI {

void initGestures(void * view,  wxEvtHandler * handler)
{
    NSOpenGLView * glView = (NSOpenGLView *) view;
    [glView initGesturesWithHandler: handler];
}

}
}
