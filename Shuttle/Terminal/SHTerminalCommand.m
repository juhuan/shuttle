//
//  SHTerminalCommand.m
//  Shuttle
//

#import "SHTerminalCommand.h"

SHTerminalType SHTerminalTypeFromPref(NSString *terminalPref) {
    NSString *pref = [terminalPref lowercaseString] ?: @"";
    if ([pref rangeOfString:@"ghostty"].location != NSNotFound) {
        return SHTerminalTypeGhostty;
    }
    if ([pref rangeOfString:@"iterm"].location != NSNotFound) {
        return SHTerminalTypeITerm;
    }
    return SHTerminalTypeTerminal;
}

static SHOpenMode SHOpenModeFromString(NSString *s) {
    if ([s isEqualToString:@"tab"])     return SHOpenModeTab;
    if ([s isEqualToString:@"new"])     return SHOpenModeNew;
    if ([s isEqualToString:@"current"]) return SHOpenModeCurrent;
    if ([s isEqualToString:@"virtual"]) return SHOpenModeVirtual;
    return SHOpenModeInvalid;
}

@implementation SHTerminalCommand

- (BOOL)resolveWithGlobalTheme:(NSString *)globalTheme
                  globalOpenIn:(NSString *)globalOpenIn
                         error:(NSError **)error
{
    // 1. theme
    NSString *theme = nil;
    if (self.theme == nil) {
        if (globalTheme == nil) {
            theme = (self.terminalType == SHTerminalTypeITerm) ? @"Default" : @"basic";
        } else {
            theme = globalTheme;
        }
    } else {
        theme = self.theme;
    }

    // 2. title
    NSString *title = self.title ?: self.fallbackName;

    // 3. openMode
    SHOpenMode mode = SHOpenModeInvalid;
    if (self.inTerminal == nil) {
        NSString *openIn = globalOpenIn;
        if (![openIn isEqualToString:@"tab"] && ![openIn isEqualToString:@"new"]) {
            openIn = @"tab";
        }
        mode = SHOpenModeFromString(openIn);
    } else {
        NSString *w = self.inTerminal;
        if (![w isEqualToString:@"new"] &&
            ![w isEqualToString:@"current"] &&
            ![w isEqualToString:@"tab"] &&
            ![w isEqualToString:@"virtual"]) {
            if (error != NULL) {
                NSString *desc = [NSString stringWithFormat:@"'%@' %@", w,
                                  NSLocalizedString(@"is not a valid value for inTerminal. Please fix this in the JSON file", nil)];
                *error = [NSError errorWithDomain:@"ShuttleErrorDomain"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: desc}];
            }
            return NO;
        }
        mode = SHOpenModeFromString(w);
    }

    self.theme = theme;
    self.title = title;
    self.openMode = mode;
    return YES;
}

@end