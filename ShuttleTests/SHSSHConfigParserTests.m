//
//  SHSSHConfigParserTests.m
//  ShuttleTests
//

#import <XCTest/XCTest.h>
#import "SHSSHConfigParser.h"

@interface SHSSHConfigParserTests : XCTestCase
@end

@implementation SHSSHConfigParserTests

- (NSString *)writeTempFile:(NSString *)content name:(NSString *)name {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return path;
}

- (void)testHostAliasTakesFirstOnly {
    SHSSHConfigParser *parser = [SHSSHConfigParser new];
    NSString *path = [self writeTempFile:@"Host a.example.com b.example.com\n    User u\n" name:@"t_alias"];
    NSDictionary *servers = [parser parseConfigFile:path];
    XCTAssertNotNil(servers[@"a.example.com"]);
    XCTAssertNil(servers[@"b.example.com"]);
}

- (void)testIncludeRecursionMerges {
    SHSSHConfigParser *parser = [SHSSHConfigParser new];
    [self writeTempFile:@"Host sub.example.com\n    User s\n" name:@"t_ssh_inc_sub"];
    NSString *main = [self writeTempFile:@"Include t_ssh_inc_sub\nHost main.example.com\n    User m\n" name:@"t_ssh_main"];
    NSDictionary *servers = [parser parseConfigFile:main];
    XCTAssertNotNil(servers[@"sub.example.com"]);
    XCTAssertNotNil(servers[@"main.example.com"]);
}

- (void)testOrdinaryCommentsSkipped {
    SHSSHConfigParser *parser = [SHSSHConfigParser new];
    NSString *path = [self writeTempFile:@"# just a comment\nHost real.example.com\n    User r\n" name:@"t_comment"];
    NSDictionary *servers = [parser parseConfigFile:path];
    XCTAssertNotNil(servers[@"real.example.com"]);
    XCTAssertNil(servers[@"just"]);
}

- (void)testShuttleNameMetadata {
    SHSSHConfigParser *parser = [SHSSHConfigParser new];
    NSString *path = [self writeTempFile:@"Host dev.example.net\n    # shuttle.name = Work/dev box\n    Hostname dev.example.net\n" name:@"t_shuttle_name"];
    NSDictionary *servers = [parser parseConfigFile:path];
    XCTAssertEqualObjects(servers[@"dev.example.net"][@"name"], @"Work/dev box");
}

- (void)testEmptyFileReturnsEmpty {
    SHSSHConfigParser *parser = [SHSSHConfigParser new];
    NSString *path = [self writeTempFile:@"" name:@"t_empty"];
    NSDictionary *servers = [parser parseConfigFile:path];
    XCTAssertEqual(servers.count, 0U);
}

- (void)testMissingFileReturnsEmpty {
    SHSSHConfigParser *parser = [SHSSHConfigParser new];
    NSDictionary *servers = [parser parseConfigFile:@"/nonexistent/shuttle/zzz"];
    XCTAssertEqual(servers.count, 0U);
}

@end