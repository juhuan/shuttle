//
//  SHLaunchAtLogin.m
//  Shuttle
//

#import "SHLaunchAtLogin.h"
#import <ServiceManagement/ServiceManagement.h>

@implementation SHLaunchAtLogin

- (BOOL)launchAtLogin {
    return [SMAppService mainAppService].status == SMAppServiceStatusEnabled;
}

- (void)setLaunchAtLogin:(BOOL)launchAtLogin {
    SMAppService *service = [SMAppService mainAppService];
    if (launchAtLogin) {
        if (service.status != SMAppServiceStatusEnabled) {
            [service registerAndReturnError:NULL];
        }
    } else {
        if (service.status == SMAppServiceStatusEnabled) {
            [service unregisterAndReturnError:NULL];
        }
    }
}

@end