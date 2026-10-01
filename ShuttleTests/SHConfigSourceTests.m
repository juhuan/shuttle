//
//  SHConfigSourceTests.m
//  ShuttleTests
//

#import <XCTest/XCTest.h>
#import "SHConfigSource.h"

@interface SHConfigSourceTests : XCTestCase
@end

@implementation SHConfigSourceTests

- (NSString *)makeTempDir {
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (void)testPrimaryPathFromShuttlePathFile {
    NSString *home = [self makeTempDir];
    [[NSFileManager defaultManager] createFileAtPath:[home stringByAppendingPathComponent:@".shuttle.path"]
                                            contents:[@"  /tmp/shuttle-custom.json\n" dataUsingEncoding:NSUTF8StringEncoding]
                                          attributes:nil];

    SHConfigSource *s = [[SHConfigSource alloc] initWithHomeDirectory:home fileManager:[NSFileManager defaultManager]];
    XCTAssertEqualObjects(s.jsonPath, @"/tmp/shuttle-custom.json");
}

- (void)testDefaultFallbackPath {
    NSString *home = [self makeTempDir];
    SHConfigSource *s = [[SHConfigSource alloc] initWithHomeDirectory:home fileManager:[NSFileManager defaultManager]];
    XCTAssertEqualObjects(s.jsonPath, [home stringByAppendingPathComponent:@".shuttle.json"]);
    XCTAssertFalse(s.parseAltJSON);
}

- (void)testAltPathFileEnablesParse {
    NSString *home = [self makeTempDir];
    [[NSFileManager defaultManager] createFileAtPath:[home stringByAppendingPathComponent:@".shuttle-alt.path"]
                                            contents:[@" /tmp/shuttle-alt.json " dataUsingEncoding:NSUTF8StringEncoding]
                                          attributes:nil];
    SHConfigSource *s = [[SHConfigSource alloc] initWithHomeDirectory:home fileManager:[NSFileManager defaultManager]];
    XCTAssertTrue(s.parseAltJSON);
    XCTAssertEqualObjects(s.altJsonPath, @"/tmp/shuttle-alt.json");
}

- (void)testAltDefaultWhenFileExists {
    NSString *home = [self makeTempDir];
    [[NSFileManager defaultManager] createFileAtPath:[home stringByAppendingPathComponent:@".shuttle-alt.json"]
                                            contents:[@"{}" dataUsingEncoding:NSUTF8StringEncoding]
                                          attributes:nil];
    SHConfigSource *s = [[SHConfigSource alloc] initWithHomeDirectory:home fileManager:[NSFileManager defaultManager]];
    XCTAssertTrue(s.parseAltJSON);
    XCTAssertEqualObjects(s.altJsonPath, [home stringByAppendingPathComponent:@".shuttle-alt.json"]);
}

- (void)testNeedUpdateWhenNoOldTime {
    NSString *home = [self makeTempDir];
    NSString *json = [home stringByAppendingPathComponent:@".shuttle.json"];
    [[NSFileManager defaultManager] createFileAtPath:json contents:[@"{}" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    SHConfigSource *s = [[SHConfigSource alloc] initWithHomeDirectory:home fileManager:[NSFileManager defaultManager]];
    XCTAssertTrue([s needUpdateForFile:json old:nil]);
}

- (void)testNeedUpdateFalseWhenUnchanged {
    NSString *home = [self makeTempDir];
    NSString *json = [home stringByAppendingPathComponent:@".shuttle.json"];
    [[NSFileManager defaultManager] createFileAtPath:json contents:[@"{}" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    SHConfigSource *s = [[SHConfigSource alloc] initWithHomeDirectory:home fileManager:[NSFileManager defaultManager]];
    NSDate *mtime = [s mtimeForFile:json];
    XCTAssertFalse([s needUpdateForFile:json old:mtime]);
}

- (void)testNeedUpdateFalseForMissingFile {
    SHConfigSource *s = [[SHConfigSource alloc] initWithHomeDirectory:[self makeTempDir] fileManager:[NSFileManager defaultManager]];
    XCTAssertFalse([s needUpdateForFile:@"/nonexistent/z" old:nil]);
}

@end