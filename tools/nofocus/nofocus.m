// Loaded into Claude's private Godot copy for screenshot runs: the app may never become the front app,
// so Brandon's windows and keyboard focus stay where they are. Its windows are also invisible and
// click-through (Brandon, 2026-11-02: "These screenshots still pop up over my laptop screen, is there any
// way to do them totally silently"): Godot still renders into them, so viewport captures work, but nothing
// shows on his screen and his mouse goes straight through. LODESTONE_SHOW_WINDOWS=1 shows them for debugging.
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <stdlib.h>
static void noop_b(id s, SEL c, BOOL f) {}
static void noop(id s, SEL c) {}
static BOOL keep_policy(id s, SEL c, NSInteger p) { return YES; }
static BOOL no_activate(id s, SEL c, NSUInteger o) { return NO; }
static void swap(Class k, SEL sel, IMP imp) { Method m = class_getInstanceMethod(k, sel); if (m) method_setImplementation(m, imp); }

static IMP orig_order_front, orig_key_front, orig_regardless, orig_set_alpha;
static void hide(NSWindow *w) {
	((void (*)(id, SEL, CGFloat))orig_set_alpha)(w, @selector(setAlphaValue:), 0.0);
	[w setIgnoresMouseEvents:YES];
	[w setHasShadow:NO];
}
static void order_front(id s, SEL c, id sender) { hide(s); ((void (*)(id, SEL, id))orig_order_front)(s, c, sender); }
static void key_front(id s, SEL c, id sender) { hide(s); ((void (*)(id, SEL, id))orig_key_front)(s, c, sender); }
static void regardless(id s, SEL c) { hide(s); ((void (*)(id, SEL))orig_regardless)(s, c); }
static void keep_alpha(id s, SEL c, CGFloat a) { ((void (*)(id, SEL, CGFloat))orig_set_alpha)(s, c, 0.0); }
static IMP replace(Class k, SEL sel, IMP imp) { Method m = class_getInstanceMethod(k, sel); return m ? method_setImplementation(m, imp) : NULL; }

__attribute__((constructor)) static void lodestone_nofocus(void) {
	Class app = [NSApplication class];
	swap(app, @selector(activateIgnoringOtherApps:), (IMP)noop_b);
	swap(app, @selector(activate), (IMP)noop);
	swap(app, @selector(setActivationPolicy:), (IMP)keep_policy);
	swap([NSRunningApplication class], @selector(activateWithOptions:), (IMP)no_activate);
	const char *show = getenv("LODESTONE_SHOW_WINDOWS");
	if (show && show[0] == '1') return;
	Class win = [NSWindow class];
	orig_set_alpha = replace(win, @selector(setAlphaValue:), (IMP)keep_alpha);
	orig_order_front = replace(win, @selector(orderFront:), (IMP)order_front);
	orig_key_front = replace(win, @selector(makeKeyAndOrderFront:), (IMP)key_front);
	orig_regardless = replace(win, @selector(orderFrontRegardless), (IMP)regardless);
}
