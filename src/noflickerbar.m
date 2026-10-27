// noflickerbar: keep the Touch Bar panel out of its flickering idle state while the Mac is
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

#define NOFLICKERBAR_VERSION "1.0.0"

@interface DFRBrightnessClient : NSObject
- (long long)displayState;
- (id)copyPropertyForKey:(id)key;
- (void)flushPropertyCache;
- (BOOL)turnOnWithPeriod:(float)period;
- (BOOL)dimToStep:(long long)step withPeriod:(float)period;
@end

enum { kPanelOff = 1, kFullStep = 1, kFlickerStep = 4 };

static DFRBrightnessClient *client;
static long long dimStep = 2;
static io_registry_entry_t rootDomain, hidSystem;
// Set while the panel sits at a step we chose. TouchBarServer only writes on its own
// transitions, so if input lands between its step-4 write and ours, it believes the
// panel is at full brightness and never restores it; we must.
static BOOL lifted;

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

// Seconds since the last HID input; large when unknown so we never restore spuriously.
static double hidIdleSeconds(void) {
    if (!hidSystem) return 1e9;
    CFTypeRef v = IORegistryEntryCreateCFProperty(hidSystem, CFSTR("HIDIdleTime"), kCFAllocatorDefault, 0);
    if (!v) return 1e9;
    long long ns = 0;
    BOOL ok = CFGetTypeID(v) == CFNumberGetTypeID() && CFNumberGetValue(v, kCFNumberSInt64Type, &ns);
    CFRelease(v);
    return ok ? ns / 1e9 : 1e9;
}

static void check(void) {
    if (CGDisplayIsAsleep(CGMainDisplayID()) || lidClosed()) return;
    [client flushPropertyCache];
    if ([client displayState] == kPanelOff) {
        BOOL ok = [client turnOnWithPeriod:0];
        NSLog(@"panel off -> turnOn %@", ok ? @"YES" : @"NO");
    }
    long long step = [[client copyPropertyForKey:@"DFRDimmingStep"] longLongValue];
    if (step == kFlickerStep) {
        lifted = [client dimToStep:dimStep withPeriod:0];
        NSLog(@"dimming step %d -> %lld %@", kFlickerStep, dimStep, lifted ? @"YES" : @"NO");
    } else if (lifted && step != dimStep) {
        lifted = NO;  // TouchBarServer took over again
    } else if (lifted && hidIdleSeconds() < 1) {
        lifted = NO;
        BOOL ok = [client dimToStep:kFullStep withPeriod:0];
        NSLog(@"input while at step %lld -> %d %@", dimStep, kFullStep, ok ? @"YES" : @"NO");
    }
}

static void usage(FILE *out) {
    fprintf(out,
            "usage: noflickerbar [poll_s=0.25] [dim_step=2]\n"
            "Keeps the Touch Bar out of dimming step 4, where some panels flicker on idle.\n");
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc > 1 && (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help"))) { usage(stdout); return 0; }
        if (argc > 1 && !strcmp(argv[1], "--version")) { puts(NOFLICKERBAR_VERSION); return 0; }

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
        hidSystem = IOServiceGetMatchingService(MACH_PORT_NULL, IOServiceMatching("IOHIDSystem"));

        dispatch_queue_t q = dispatch_get_main_queue();
        dispatch_source_t t = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
        dispatch_source_set_timer(t, DISPATCH_TIME_NOW, (uint64_t)(poll * NSEC_PER_SEC), (uint64_t)(poll * NSEC_PER_SEC / 10));
        dispatch_source_set_event_handler(t, ^{ check(); });
        dispatch_resume(t);

        NSLog(@"noflickerbar %s running, poll %.2fs, dim step %lld", NOFLICKERBAR_VERSION, poll, dimStep);
        dispatch_main();
    }
}
