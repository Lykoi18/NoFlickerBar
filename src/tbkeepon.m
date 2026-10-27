// tbkeepon: keep the Touch Bar panel out of its flickering idle state while the Mac is
// in use. On idle TouchBarServer drops DFRDimmingStep to 4 (displayState stays on), and
// some panels flicker there; a forced turnOff (displayState 1) flickers too. Lift step 4
// back to a dim step and power the panel back on if it was turned off. TouchBarServer has
// already stopped rendering by then, so the panel stays black.
//
// Exits 0 when the Mac has no Touch Bar or the private framework is missing, so a
// launchd KeepAlive {SuccessfulExit = false} job does not respawn it.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <IOKit/IOKitLib.h>
#import <objc/runtime.h>
#include <dlfcn.h>

#define TBKEEPON_VERSION "1.0.0"

@interface DFRBrightnessClient : NSObject
- (long long)displayState;
- (id)copyPropertyForKey:(id)key;
- (void)flushPropertyCache;
- (BOOL)turnOnWithPeriod:(float)period;
- (BOOL)dimToStep:(long long)step withPeriod:(float)period;
@end

enum { kPanelOff = 1, kFlickerStep = 4 };

static DFRBrightnessClient *client;
static long long dimStep = 2;
static io_registry_entry_t rootDomain;

// No DFR HID service behind the client means there is no Touch Bar panel.
// Unknown layout (ivar renamed) counts as present, so we never bail out wrongly.
static BOOL hasTouchBar(void) {
    Ivar iv = class_getInstanceVariable([client class], "_DFRService");
    if (!iv) return YES;
    return *(void **)((__bridge void *)client + ivar_getOffset(iv)) != NULL;
}

static BOOL lidClosed(void) {
    if (!rootDomain) return NO;
    CFTypeRef v = IORegistryEntryCreateCFProperty(rootDomain, CFSTR("AppleClamshellState"), kCFAllocatorDefault, 0);
    if (!v) return NO;
    BOOL closed = CFGetTypeID(v) == CFBooleanGetTypeID() && CFBooleanGetValue(v);
    CFRelease(v);
    return closed;
}

static void check(void) {
    if (CGDisplayIsAsleep(CGMainDisplayID()) || lidClosed()) return;
    [client flushPropertyCache];
    if ([client displayState] == kPanelOff) {
        BOOL ok = [client turnOnWithPeriod:0];
        NSLog(@"panel off -> turnOn %@", ok ? @"YES" : @"NO");
    }
    if ([[client copyPropertyForKey:@"DFRDimmingStep"] longLongValue] == kFlickerStep) {
        BOOL ok = [client dimToStep:dimStep withPeriod:0];
        NSLog(@"dimming step %d -> %lld %@", kFlickerStep, dimStep, ok ? @"YES" : @"NO");
    }
}

static void usage(FILE *out) {
    fprintf(out,
            "usage: tbkeepon [poll_s=0.25] [dim_step=2]\n"
            "Keeps the Touch Bar out of dimming step 4, where some panels flicker on idle.\n");
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc > 1 && (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help"))) { usage(stdout); return 0; }
        if (argc > 1 && !strcmp(argv[1], "--version")) { puts(TBKEEPON_VERSION); return 0; }

        double poll = argc > 1 ? atof(argv[1]) : 0.25;
        if (argc > 2) dimStep = atoll(argv[2]);
        if (poll <= 0 || dimStep < 0 || dimStep >= kFlickerStep) { usage(stderr); return 2; }

        if (!dlopen("/System/Library/PrivateFrameworks/DFRBrightness.framework/DFRBrightness", RTLD_NOW)) {
            NSLog(@"DFRBrightness framework unavailable (%s), nothing to do", dlerror());
            return 0;
        }
        client = [[NSClassFromString(@"DFRBrightnessClient") alloc] init];
        if (!client || !hasTouchBar()) {
            NSLog(@"no Touch Bar found, nothing to do");
            return 0;
        }
        // MACH_PORT_NULL is the default main port on every macOS with a Touch Bar.
        rootDomain = IOServiceGetMatchingService(MACH_PORT_NULL, IOServiceMatching("IOPMrootDomain"));

        dispatch_queue_t q = dispatch_get_main_queue();
        dispatch_source_t t = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
        dispatch_source_set_timer(t, DISPATCH_TIME_NOW, (uint64_t)(poll * NSEC_PER_SEC), (uint64_t)(poll * NSEC_PER_SEC / 10));
        dispatch_source_set_event_handler(t, ^{ check(); });
        dispatch_resume(t);

        NSLog(@"tbkeepon %s running, poll %.2fs, dim step %lld", TBKEEPON_VERSION, poll, dimStep);
        dispatch_main();
    }
}
