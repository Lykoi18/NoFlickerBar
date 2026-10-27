// dfrbright: probe and drive the Touch Bar panel through private DFRBrightness.framework.
// usage: dfrbright status
//        dfrbright step <n> [period_s=0] [hold_s=0]
//        dfrbright off [period_s=0] [hold_s=0]
//        dfrbright on [period_s=0]
//        dfrbright watch [seconds=120]   (status every second, cache flushed)
#import <Foundation/Foundation.h>
#include <dlfcn.h>

@interface DFRBrightnessClient : NSObject
- (long long)displayState;
- (long long)getDimmingStep;
- (long long)harmonyState;
- (id)copyPropertyForKey:(id)key;
- (BOOL)dimToStep:(long long)step withPeriod:(float)period;
- (BOOL)turnOffWithPeriod:(float)period;
- (BOOL)turnOnWithPeriod:(float)period;
- (void)flushPropertyCache;
@end

static void status(DFRBrightnessClient *c) {
    id step = [c copyPropertyForKey:@"DFRDimmingStep"];
    printf("displayState=%lld dimmingStep=%lld harmonyState=%lld DFRDimmingStep=%s\n",
           [c displayState], [c getDimmingStep], [c harmonyState],
           step ? [[step description] UTF8String] : "(nil)");
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (!dlopen("/System/Library/PrivateFrameworks/DFRBrightness.framework/DFRBrightness", RTLD_NOW)) {
            fprintf(stderr, "dlopen: %s\n", dlerror());
            return 1;
        }
        Class cls = NSClassFromString(@"DFRBrightnessClient");
        DFRBrightnessClient *c = cls ? [[cls alloc] init] : nil;
        if (!c) { fprintf(stderr, "DFRBrightnessClient unavailable\n"); return 1; }

        NSString *cmd = argc > 1 ? @(argv[1]) : @"status";
        float period = 0;
        unsigned hold = 0;
        BOOL ok = YES;
        if ([cmd isEqualToString:@"step"] && argc > 2) {
            period = argc > 3 ? atof(argv[3]) : 0;
            hold = argc > 4 ? (unsigned)atoi(argv[4]) : 0;
            ok = [c dimToStep:atoll(argv[2]) withPeriod:period];
        } else if ([cmd isEqualToString:@"off"]) {
            period = argc > 2 ? atof(argv[2]) : 0;
            hold = argc > 3 ? (unsigned)atoi(argv[3]) : 0;
            ok = [c turnOffWithPeriod:period];
        } else if ([cmd isEqualToString:@"on"]) {
            period = argc > 2 ? atof(argv[2]) : 0;
            ok = [c turnOnWithPeriod:period];
        } else if ([cmd isEqualToString:@"watch"]) {
            int seconds = argc > 2 ? atoi(argv[2]) : 120;
            NSDateFormatter *f = [NSDateFormatter new];
            f.dateFormat = @"HH:mm:ss";
            for (int i = 0; i < seconds; i++) {
                [c flushPropertyCache];
                printf("%s ", [[f stringFromDate:[NSDate date]] UTF8String]);
                status(c);
                fflush(stdout);
                sleep(1);
            }
            return 0;
        } else if (![cmd isEqualToString:@"status"]) {
            fprintf(stderr, "unknown command\n");
            return 2;
        }
        if (![cmd isEqualToString:@"status"]) printf("%s -> %s\n", argv[1], ok ? "YES" : "NO");
        status(c);
        if (hold) { sleep(hold); status(c); }
    }
    return 0;
}
