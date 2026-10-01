//
//  SHSSHConfigParser.m
//  Shuttle
//

#import "SHSSHConfigParser.h"

@implementation SHSSHConfigParser

- (instancetype)init {
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];
    }
    return self;
}

- (NSDictionary<NSString *, NSDictionary *> *)parseConfigFiles {
    NSString *configFile = nil;

    // 系统级：优先 /etc/ssh_config（复刻旧 parseSSHConfigFile，注意不是 /etc/ssh/ssh_config）。
    if ([self.fileManager fileExistsAtPath:@"/etc/ssh_config"]) {
        configFile = @"/etc/ssh_config";
    }

    // 用户级：存在则覆盖。
    if ([self.fileManager fileExistsAtPath:[@"~/.ssh/config" stringByExpandingTildeInPath]]) {
        configFile = [@"~/.ssh/config" stringByExpandingTildeInPath];
    }

    if (configFile == nil) {
        return nil;
    }
    return [self parseConfigFile:configFile];
}

- (NSDictionary<NSString *, NSDictionary *> *)parseConfigFile:(NSString *)filepath {
    return [self parseConfigFile:filepath seenPaths:[NSMutableSet set]];
}

- (NSDictionary<NSString *, NSDictionary *> *)parseConfigFile:(NSString *)filepath
                                                   seenPaths:(NSMutableSet *)seenPaths {
    // 循环 Include 保护：重复访问同一文件则安全终止。
    NSString *standardPath = [filepath stringByStandardizingPath];
    if ([seenPaths containsObject:standardPath]) {
        return @{};
    }
    [seenPaths addObject:standardPath];

    NSString *fh = [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:nil];
    if (fh == nil) {
        // 空文件 / 编码异常：安全返回。
        return @{};
    }

    NSRegularExpression *rx = [NSRegularExpression regularExpressionWithPattern:@"^(#?)[ \\t]*([^ \\t=]+)[ \\t=]+(.*)$"
                                                                        options:0
                                                                          error:NULL];
    NSMutableDictionary *servers = [NSMutableDictionary dictionary];
    NSString *key = nil;

    for (NSString *line in [fh componentsSeparatedByString:@"\n"]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        NSTextCheckingResult *matches = [rx firstMatchInString:trimmed
                                                       options:0
                                                         range:NSMakeRange(0, [trimmed length])];
        if ([matches numberOfRanges] != 4) {
            continue;
        }

        BOOL isComment = [[trimmed substringWithRange:[matches rangeAtIndex:1]] isEqualToString:@"#"];
        NSString *first = [trimmed substringWithRange:[matches rangeAtIndex:2]];
        NSString *second = [trimmed substringWithRange:[matches rangeAtIndex:3]];

        // 注释且键前缀 shuttle.：写入 servers[key][去掉前缀后的键名] = 值（如 #shuttle.name）。
        if (isComment && key != nil && [first hasPrefix:@"shuttle."]) {
            servers[key][[first substringFromIndex:8]] = second;
        }

        if (isComment) {
            continue;
        }

        if ([first isEqualToString:@"Include"]) {
            NSString *includePath = ([second isAbsolutePath])
                ? [second stringByExpandingTildeInPath]
                : [[filepath stringByDeletingLastPathComponent] stringByAppendingPathComponent:second];
            [servers addEntriesFromDictionary:[self parseConfigFile:includePath seenPaths:seenPaths]];
        }

        if ([first isEqualToString:@"Host"]) {
            NSArray *hostAliases = [second componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            hostAliases = [hostAliases filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != ''"]];
            key = [hostAliases firstObject];
            servers[key] = [NSMutableDictionary dictionary];
        }
    }

    return servers;
}

@end