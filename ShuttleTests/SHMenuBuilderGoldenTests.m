//
//  SHMenuBuilderGoldenTests.m
//  ShuttleTests
//
//  加载 ShuttleTests/Fixtures/ 下的样例 JSON 与 SSH config，用 SHMenuBuilder 构建菜单树并
//  与重构前的 golden 基线逐项比对（SC-004 零回归基线）。
//

#import <XCTest/XCTest.h>
#import "SHMenuBuilder.h"
#import "SHMenuNode.h"
#import "SHShuttleConfig.h"
#import "SHSSHConfigParser.h"

static id serializeNode(SHMenuNode *node) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"name"] = node.title;
    d[@"separator"] = @(node.appendSeparator);
    if (node.isLeaf) {
        d[@"cmd"] = node.command.command ?: @"";
        d[@"theme"] = node.command.theme ?: [NSNull null];
        d[@"title"] = node.command.title ?: [NSNull null];
        d[@"in_terminal"] = node.command.inTerminal ?: [NSNull null];
    } else {
        NSMutableArray *children = [NSMutableArray array];
        for (SHMenuNode *c in node.children) {
            [children addObject:serializeNode(c)];
        }
        d[@"children"] = children;
    }
    return d;
}

@interface SHMenuBuilderGoldenTests : XCTestCase
@end

@implementation SHMenuBuilderGoldenTests

- (NSString *)fixturesPath {
    NSString *dir = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
    return [dir stringByAppendingPathComponent:@"Fixtures"];
}

- (void)testMenuMatchesGoldenBaseline {
    NSString *fixtures = [self fixturesPath];
    NSString *menuPath = [fixtures stringByAppendingPathComponent:@"menu.json"];
    NSString *sshPath = [fixtures stringByAppendingPathComponent:@"ssh_config"];
    NSString *goldenPath = [fixtures stringByAppendingPathComponent:@"golden.json"];

    NSData *data = [NSData dataWithContentsOfFile:menuPath];
    XCTAssertNotNil(data);
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    XCTAssertNotNil(json);

    SHShuttleConfig *config = [SHShuttleConfig configWithJSON:json];
    NSMutableArray *hosts = config.hosts;

    SHSSHConfigParser *parser = [SHSSHConfigParser new];
    NSDictionary *servers = [parser parseConfigFile:sshPath];

    SHMenuBuilder *builder = [SHMenuBuilder new];
    if (config.showSshConfigHosts && servers != nil) {
        hosts = [builder injectSSHHosts:servers intoHosts:hosts ignoreHosts:config.ignoreHosts ignoreKeywords:config.ignoreKeywords];
    }

    NSArray<SHMenuNode *> *tree = [builder buildTreeFromHosts:hosts terminalType:config.terminalType];
    NSMutableArray *actual = [NSMutableArray array];
    for (SHMenuNode *n in tree) {
        [actual addObject:serializeNode(n)];
    }

    NSData *goldenData = [NSData dataWithContentsOfFile:goldenPath];
    XCTAssertNotNil(goldenData);
    id expected = [NSJSONSerialization JSONObjectWithData:goldenData options:0 error:nil];
    XCTAssertNotNil(expected);

    XCTAssertEqualObjects(actual, expected);
}

@end