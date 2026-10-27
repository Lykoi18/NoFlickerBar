// tbkeepon: keep the Touch Bar panel out of its flickering idle state while the main
// display is awake. On idle TouchBarServer drops DFRDimmingStep to 4 (displayState stays
// on), and the panel flickers there; a forced turnOff (displayState 1) flickers too.
// Lift step 4 back to a dim step and power the panel back on if it was turned off.
// usage: tbkeepon [poll_s=0.25] [dim_step=2]
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>

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

static void check(void) {
    if (CGDisplayIsAsleep(CGMainDisplayID())) return;
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

int main(int argc, char **argv) {
    @autoreleasepool {
        if (!dlopen("/System/Library/PrivateFrameworks/DFRBrightness.framework/DFRBrightness", RTLD_NOW)) {
            fprintf(stderr, "dlopen: %s\n", dlerror());
            return 1;
        }
        client = [[NSClassFromString(@"DFRBrightnessClient") alloc] init];
        if (!client) { fprintf(stderr, "DFRBrightnessClient unavailable\n"); return 1; }

        double poll = argc > 1 ? atof(argv[1]) : 0.25;
        if (argc > 2) dimStep = atoll(argv[2]);

        dispatch_queue_t q = dispatch_get_main_queue();
        dispatch_source_t t = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
        dispatch_source_set_timer(t, DISPATCH_TIME_NOW, (uint64_t)(poll * NSEC_PER_SEC), (uint64_t)(poll * NSEC_PER_SEC / 10));
        dispatch_source_set_event_handler(t, ^{ check(); });
        dispatch_resume(t);

        NSLog(@"tbkeepon running, poll %.1fs, dim step %lld", poll, dimStep);
        dispatch_main();
    }
}
