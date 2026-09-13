#import "LegacyLocations.h"
#import "../Libs/TrollStore/CoreServices.h"
#import <dlfcn.h>

NSDictionary<NSString *, id> *TRLegacyLocations(void) {
    @try {
        Class proxyClass = NSClassFromString(@"LSApplicationProxy");
        if (![proxyClass respondsToSelector:@selector(applicationProxyForIdentifier:)]) {
            return @{@"error": @"The installed-app database is unavailable."};
        }
        LSApplicationProxy *proxy = [(id)proxyClass applicationProxyForIdentifier:@"com.son3ra1n.andromeda"];
        BOOL installed = proxy.installed || proxy.bundleURL != nil;
        NSMutableArray *paths = [NSMutableArray arrayWithObject:@"/var/mobile/Library/Preferences/com.son3ra1n.andromeda.plist"];
        NSURL *container = proxy.dataContainerURL;
        if (container) {
            [paths addObject:[[container URLByAppendingPathComponent:@"Library/Preferences/com.son3ra1n.andromeda.plist"] path]];
        }
        NSURL *group = proxy.groupContainerURLs[@"group.live.cclerc.geraniumBookmarks"];
        if (!group) {
            // Read-only MCM discovery also works when the old app is no longer registered.
            dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_LAZY);
            Class sharedClass = NSClassFromString(@"MCMSharedDataContainer");
            if ([sharedClass respondsToSelector:@selector(containerWithIdentifier:createIfNecessary:existed:error:)]) {
                BOOL existed = NO;
                id error = nil;
                MCMContainer *existing = [(id)sharedClass containerWithIdentifier:@"group.live.cclerc.geraniumBookmarks"
                    createIfNecessary:NO existed:&existed error:&error];
                if (existed) group = existing.url;
            }
        }
        NSMutableDictionary *result = [@{@"installed": @(installed), @"preferences": paths} mutableCopy];
        if (group) result[@"favorites"] = [[group URLByAppendingPathComponent:@"Library/Preferences/group.live.cclerc.geraniumBookmarks.plist"] path];
        return result;
    } @catch (NSException *exception) {
        return @{@"error": @"Could not inspect Andromeda's existing containers. Keep Andromeda installed and retry."};
    }
}
