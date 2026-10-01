//
//  SHShuttleConfigTests.m
//  ShuttleTests
//

#import <XCTest/XCTest.h>
#import "SHShuttleConfig.h"

@interface SHShuttleConfigTests : XCTestCase
@end

@implementation SHShuttleConfigTests

- (void)testFieldsLowercased {
    SHShuttleConfig *c = [SHShuttleConfig configWithJSON:@{
        @"terminal": @"Terminal.App",
        @"editor": @"Default",
        @"iTerm_version": @"Nightly",
        @"open_in": @"New",
    }];
    XCTAssertEqualObjects(c.terminal, @"terminal.app");
    XCTAssertEqualObjects(c.editor, @"default");
    XCTAssertEqualObjects(c.iTermVersion, @"nightly");
    XCTAssertEqualObjects(c.openIn, @"new");
}

- (void)testDefaults {
    SHShuttleConfig *c = [SHShuttleConfig configWithJSON:@{}];
    XCTAssertNil(c.terminal);
    XCTAssertNil(c.editor);
    XCTAssertFalse(c.launchAtLogin);
    XCTAssertTrue(c.showSshConfigHosts);
    XCTAssertEqual(c.hosts.count, 0U);
    XCTAssertEqual(c.ignoreHosts.count, 0U);
    XCTAssertEqual(c.ignoreKeywords.count, 0U);
}

- (void)testShowSshConfigHostsExplicitFalse {
    SHShuttleConfig *c = [SHShuttleConfig configWithJSON:@{ @"show_ssh_config_hosts": @NO }];
    XCTAssertFalse(c.showSshConfigHosts);
}

- (void)testMalformedHostsBecomesEmpty {
    SHShuttleConfig *c = [SHShuttleConfig configWithJSON:@{ @"hosts": @"not-an-array" }];
    XCTAssertEqual(c.hosts.count, 0U);
}

- (void)testLaunchAtLogin {
    SHShuttleConfig *c = [SHShuttleConfig configWithJSON:@{ @"launch_at_login": @YES }];
    XCTAssertTrue(c.launchAtLogin);
}

@end