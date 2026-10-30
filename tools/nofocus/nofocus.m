// Loaded into Claude's private Godot copy for screenshot runs: the app may never become the front app,
// so Brandon's windows and keyboard focus stay where they are.
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
static void noop_b(id s, SEL c, BOOL f) {}
static void noop(id s, SEL c) {}
static BOOL keep_policy(id s, SEL c, NSInteger p) { return YES; }
static BOOL no_activate(id s, SEL c, NSUInteger o) { return NO; }
static void swap(Class k, SEL sel, IMP imp) { Method m = class_getInstanceMethod(k, sel); if (m) method_setImplementation(m, imp); }
__attribute__((constructor)) static void lodestone_nofocus(void) {
	Class app = [NSApplication class];
	swap(app, @selector(activateIgnoringOtherApps:), (IMP)noop_b);
	swap(app, @selector(activate), (IMP)noop);
	swap(app, @selector(setActivationPolicy:), (IMP)keep_policy);
	swap([NSRunningApplication class], @selector(activateWithOptions:), (IMP)no_activate);
}
