//
//  SHTerminalCommandTests.m
//  ShuttleTests
//

#import <XCTest/XCTest.h>
#import "SHTerminalCommand.h"

@interface SHTerminalCommandTests : XCTestCase
@end

@implementation SHTerminalCommandTests

- (SHTerminalCommand *)commandWithCommand:(NSString *)cmd {
    SHTerminalCommand *c = [SHTerminalCommand new];
    c.command = cmd;
    c.fallbackName = @"Fallback";
    return c;
}

- (void)testTerminalTypeFromPref {
    XCTAssertEqual(SHTerminalTypeFromPref(@"Ghostty.app"), SHTerminalTypeGhostty);
    XCTAssertEqual(SHTerminalTypeFromPref(@"iTerm"), SHTerminalTypeITerm);
    XCTAssertEqual(SHTerminalTypeFromPref(@"Terminal.app"), SHTerminalTypeTerminal);
    XCTAssertEqual(SHTerminalTypeFromPref(nil), SHTerminalTypeTerminal);
}

- (void)testThemeDefaultsToBasicForTerminal {
    SHTerminalCommand *c = [self commandWithCommand:@"echo"];
    c.terminalType = SHTerminalTypeTerminal;
    [c resolveWithGlobalTheme:nil globalOpenIn:@"tab" error:nil];
    XCTAssertEqualObjects(c.theme, @"basic");
}

- (void)testThemeDefaultsToDefaultForITerm {
    SHTerminalCommand *c = [self commandWithCommand:@"echo"];
    c.terminalType = SHTerminalTypeITerm;
    [c resolveWithGlobalTheme:nil globalOpenIn:@"tab" error:nil];
    XCTAssertEqualObjects(c.theme, @"Default");
}

- (void)testGlobalThemeWinsWhenNoLocalTheme {
    SHTerminalCommand *c = [self commandWithCommand:@"echo"];
    c.terminalType = SHTerminalTypeTerminal;
    [c resolveWithGlobalTheme:@"Homebrew" globalOpenIn:@"tab" error:nil];
    XCTAssertEqualObjects(c.theme, @"Homebrew");
}

- (void)testTitleFallsBackToFallbackName {
    SHTerminalCommand *c = [self commandWithCommand:@"echo"];
    c.terminalType = SHTerminalTypeTerminal;
    [c resolveWithGlobalTheme:nil globalOpenIn:@"tab" error:nil];
    XCTAssertEqualObjects(c.title, @"Fallback");
}

- (void)testTitleKeepsExplicitValue {
    SHTerminalCommand *c = [self commandWithCommand:@"echo"];
    c.title = @"Custom";
    c.terminalType = SHTerminalTypeTerminal;
    [c resolveWithGlobalTheme:nil globalOpenIn:@"tab" error:nil];
    XCTAssertEqualObjects(c.title, @"Custom");
}

- (void)testOpenModeUsesGlobalOpenIn {
    SHTerminalCommand *c = [self commandWithCommand:@"echo"];
    c.terminalType = SHTerminalTypeTerminal;
    [c resolveWithGlobalTheme:nil globalOpenIn:@"new" error:nil];
    XCTAssertEqual(c.openMode, SHOpenModeNew);
}

- (void)testOpenModeForcesTabOnBadGlobal {
    SHTerminalCommand *c = [self commandWithCommand:@"echo"];
    c.terminalType = SHTerminalTypeTerminal;
    [c resolveWithGlobalTheme:nil globalOpenIn:@"bogus" error:nil];
    XCTAssertEqual(c.openMode, SHOpenModeTab);
}

- (void)testInvalidInTerminalReturnsError {
    SHTerminalCommand *c = [self commandWithCommand:@"echo"];
    c.inTerminal = @"weird";
    c.terminalType = SHTerminalTypeTerminal;
    NSError *error = nil;
    BOOL ok = [c resolveWithGlobalTheme:nil globalOpenIn:@"tab" error:&error];
    XCTAssertFalse(ok);
    XCTAssertNotNil(error);
}

- (void)testVirtualOpenMode {
    SHTerminalCommand *c = [self commandWithCommand:@"echo"];
    c.inTerminal = @"virtual";
    c.terminalType = SHTerminalTypeTerminal;
    [c resolveWithGlobalTheme:nil globalOpenIn:@"tab" error:nil];
    XCTAssertEqual(c.openMode, SHOpenModeVirtual);
}

@end