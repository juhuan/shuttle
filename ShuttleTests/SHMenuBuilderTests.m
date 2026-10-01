//
//  SHMenuBuilderTests.m
//  ShuttleTests
//

#import <XCTest/XCTest.h>
#import "SHMenuBuilder.h"
#import "SHMenuNode.h"

@interface SHMenuBuilderTests : XCTestCase
@end

@implementation SHMenuBuilderTests

- (NSArray<NSString *> *)titles:(NSArray<SHMenuNode *> *)nodes {
    NSMutableArray *t = [NSMutableArray array];
    for (SHMenuNode *n in nodes) {
        [t addObject:n.title];
    }
    return t;
}

- (void)testDirectoriesBeforeLeavesEachSorted {
    SHMenuBuilder *b = [SHMenuBuilder new];
    NSArray *hosts = @[
        @{ @"name": @"Zebra", @"cmd": @"echo z" },
        @{ @"Alpha": @[ @{ @"name": @"inner", @"cmd": @"echo i" } ] },
        @{ @"name": @"Apple", @"cmd": @"echo a" },
    ];
    NSArray<SHMenuNode *> *tree = [b buildTreeFromHosts:hosts terminalType:SHTerminalTypeTerminal];
    XCTAssertEqualObjects([self titles:tree], (@[ @"Alpha", @"Apple", @"Zebra" ]));
    XCTAssertTrue(tree[0].isLeaf == NO);
    XCTAssertTrue(tree[1].isLeaf == YES);
}

- (void)testSortMarkerRemoved {
    SHMenuBuilder *b = [SHMenuBuilder new];
    NSArray *hosts = @[ @{ @"name": @"[bbb]Foo", @"cmd": @"echo" } ];
    NSArray<SHMenuNode *> *tree = [b buildTreeFromHosts:hosts terminalType:SHTerminalTypeTerminal];
    SHMenuNode *leaf = tree[0];
    XCTAssertEqualObjects(leaf.title, @"Foo");
    XCTAssertFalse(leaf.appendSeparator);
}

- (void)testSeparatorMarkerStripsAndFlags {
    SHMenuBuilder *b = [SHMenuBuilder new];
    NSArray *hosts = @[ @{ @"name": @"[---]Bar", @"cmd": @"echo" } ];
    NSArray<SHMenuNode *> *tree = [b buildTreeFromHosts:hosts terminalType:SHTerminalTypeTerminal];
    SHMenuNode *leaf = tree[0];
    XCTAssertEqualObjects(leaf.title, @"Bar");
    XCTAssertTrue(leaf.appendSeparator);
}

- (void)testBothMarkersStripAndFlagSeparator {
    SHMenuBuilder *b = [SHMenuBuilder new];
    NSArray *hosts = @[ @{ @"name": @"[aaa][---]Baz", @"cmd": @"echo" } ];
    NSArray<SHMenuNode *> *tree = [b buildTreeFromHosts:hosts terminalType:SHTerminalTypeTerminal];
    SHMenuNode *leaf = tree[0];
    XCTAssertEqualObjects(leaf.title, @"Baz");
    XCTAssertTrue(leaf.appendSeparator);
}

- (void)testLeafCarriesCommandFields {
    SHMenuBuilder *b = [SHMenuBuilder new];
    NSArray *hosts = @[ @{
        @"name": @"x",
        @"cmd": @"echo hi",
        @"theme": @"Homebrew",
        @"title": @"T",
        @"inTerminal": @"new",
    } ];
    NSArray<SHMenuNode *> *tree = [b buildTreeFromHosts:hosts terminalType:SHTerminalTypeITerm];
    SHMenuNode *leaf = tree[0];
    XCTAssertEqualObjects(leaf.command.command, @"echo hi");
    XCTAssertEqualObjects(leaf.command.theme, @"Homebrew");
    XCTAssertEqualObjects(leaf.command.title, @"T");
    XCTAssertEqualObjects(leaf.command.inTerminal, @"new");
    XCTAssertEqual(leaf.command.terminalType, SHTerminalTypeITerm);
}

- (void)testInjectSSHHostsBuildsCommandAndPath {
    SHMenuBuilder *b = [SHMenuBuilder new];
    NSDictionary *servers = @{
        @"github.com": @{},
        @"A/B.example.com": @{},
        @"*.wild.com": @{},
        @".hidden.com": @{},
    };
    NSMutableArray *hosts = [NSMutableArray array];
    [b injectSSHHosts:servers intoHosts:hosts ignoreHosts:@[] ignoreKeywords:@[]];

    BOOL hasGithub = NO, hasDirA = NO;
    NSArray *dirAChildren = nil;
    for (NSDictionary *item in hosts) {
        if ([item[@"name"] isEqualToString:@"github.com"] && [item[@"cmd"] isEqualToString:@"ssh github.com"]) {
            hasGithub = YES;
        }
        if (item[@"A"]) {
            hasDirA = YES;
            dirAChildren = item[@"A"];
        }
    }
    XCTAssertTrue(hasGithub);
    XCTAssertTrue(hasDirA);
    XCTAssertNotNil(dirAChildren);
    XCTAssertEqualObjects(dirAChildren[0][@"name"], @"B.example.com");
    XCTAssertEqualObjects(dirAChildren[0][@"cmd"], @"ssh A/B.example.com");
}

- (void)testInjectSSHHostsHonorsIgnoreRules {
    SHMenuBuilder *b = [SHMenuBuilder new];
    NSDictionary *servers = @{
        @"skipme": @{ @"name": @"skipme" },
        @"sub.example.com": @{},
    };
    NSMutableArray *hosts = [NSMutableArray array];
    [b injectSSHHosts:servers intoHosts:hosts ignoreHosts:@[ @"skipme" ] ignoreKeywords:@[ @"sub" ]];
    XCTAssertEqual(hosts.count, 0U);
}

@end