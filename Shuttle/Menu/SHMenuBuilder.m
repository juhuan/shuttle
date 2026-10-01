//
//  SHMenuBuilder.m
//  Shuttle
//

#import "SHMenuBuilder.h"

@implementation SHMenuBuilder

#pragma mark - SSH 主机注入（复刻旧 loadMenu）

- (NSMutableArray *)injectSSHHosts:(NSDictionary<NSString *, NSDictionary *> *)servers
                          intoHosts:(NSMutableArray *)hosts
                        ignoreHosts:(NSArray *)ignoreHosts
                     ignoreKeywords:(NSArray *)ignoreKeywords {
    for (NSString *key in servers) {
        BOOL skipCurrent = NO;
        NSDictionary *cfg = servers[key];

        NSString *name = cfg[@"name"] ? cfg[@"name"] : key;

        // 通配符
        if ([name rangeOfString:@"*"].length != 0) {
            skipCurrent = YES;
        }
        // 以 `.` 开头
        if ([name hasPrefix:@"."]) {
            skipCurrent = YES;
        }
        // 精确匹配 ignoreHosts
        for (NSString *ignore in ignoreHosts) {
            if ([name isEqualToString:ignore]) {
                skipCurrent = YES;
            }
        }
        // 包含 ignoreKeywords 任一子串
        for (NSString *ignore in ignoreKeywords) {
            if ([name rangeOfString:ignore].location != NSNotFound) {
                skipCurrent = YES;
            }
        }

        if (skipCurrent) {
            continue;
        }

        // 按 / 切分，末段为叶子名，前面为嵌套目录。
        NSMutableArray *path = [NSMutableArray arrayWithArray:[name componentsSeparatedByString:@"/"]];
        NSString *leaf = [path lastObject];
        if (leaf == nil) {
            continue;
        }
        [path removeLastObject];

        NSMutableArray *itemList = hosts;
        for (NSString *part in path) {
            BOOL createList = YES;
            for (NSDictionary *item in itemList) {
                // 遇到 cmd/name 叶子则无法下钻
                if (item[@"cmd"] || item[@"name"]) {
                    continue;
                }
                if (item[part]) {
                    if ([item[part] isKindOfClass:[NSArray class]]) {
                        itemList = item[part];
                        createList = NO;
                    } else {
                        itemList = nil;
                    }
                    break;
                }
            }

            if (itemList == nil) {
                break;
            }

            if (createList) {
                NSMutableArray *newList = [NSMutableArray array];
                [itemList addObject:[NSDictionary dictionaryWithObject:newList forKey:part]];
                itemList = newList;
            }
        }

        if (itemList) {
            NSString *cmd = [NSString stringWithFormat:@"ssh %@", key];
            [itemList addObject:[NSDictionary dictionaryWithObjects:@[leaf, cmd]
                                                            forKeys:@[@"name", @"cmd"]]];
        }
    }
    return hosts;
}

#pragma mark - 菜单树构建（复刻旧 buildMenu + separatorSortRemoval）

- (NSArray<SHMenuNode *> *)buildTreeFromHosts:(NSArray *)hosts terminalType:(SHTerminalType)terminalType {
    NSMutableDictionary<NSString *, id> *menus = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSDictionary *> *leafs = [NSMutableDictionary dictionary];

    for (NSDictionary *item in hosts) {
        if (item[@"cmd"] && item[@"name"]) {
            leafs[item[@"name"]] = item;
        } else {
            for (NSString *key in item) {
                menus[key] = item[key];
            }
        }
    }

    NSArray<NSString *> *menuKeys = [[menus allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray<NSString *> *leafKeys = [[leafs allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    NSMutableArray<SHMenuNode *> *result = [NSMutableArray array];

    // 目录在前
    for (NSString *key in menuKeys) {
        BOOL appendSeparator = NO;
        NSString *title = [self displayNameForName:key separator:&appendSeparator];

        SHMenuNode *node = [[SHMenuNode alloc] init];
        node.leaf = NO;
        node.title = title;
        node.appendSeparator = appendSeparator;
        node.children = [self buildTreeFromHosts:menus[key] terminalType:terminalType];
        [result addObject:node];
    }

    // 叶子在后
    for (NSString *key in leafKeys) {
        NSDictionary *cfg = leafs[key];
        BOOL appendSeparator = NO;
        NSString *title = [self displayNameForName:cfg[@"name"] separator:&appendSeparator];

        SHTerminalCommand *command = [[SHTerminalCommand alloc] init];
        command.command = cfg[@"cmd"];
        command.theme = cfg[@"theme"];
        command.title = cfg[@"title"];
        command.inTerminal = cfg[@"inTerminal"];
        command.fallbackName = title;
        command.terminalType = terminalType;

        SHMenuNode *node = [[SHMenuNode alloc] init];
        node.leaf = YES;
        node.title = title;
        node.command = command;
        node.appendSeparator = appendSeparator;
        [result addObject:node];
    }

    return result;
}

#pragma mark - 标记去除（复刻 separatorSortRemoval）

- (NSString *)displayNameForName:(NSString *)currentName separator:(BOOL *)outSeparator {
    BOOL addSeparator = NO;

    NSRegularExpression *regexSort = [NSRegularExpression regularExpressionWithPattern:@"([\\[][a-z]{3}[\\]])"
                                                                               options:0
                                                                                 error:NULL];
    NSRegularExpression *regexSeparator = [NSRegularExpression regularExpressionWithPattern:@"([\\[][-]{3}[\\]])"
                                                                                    options:0
                                                                                      error:NULL];

    NSUInteger sortMatches = [regexSort numberOfMatchesInString:currentName
                                                        options:0
                                                          range:NSMakeRange(0, [currentName length])];
    NSUInteger separatorMatches = [regexSeparator numberOfMatchesInString:currentName
                                                                  options:0
                                                                    range:NSMakeRange(0, [currentName length])];

    NSString *displayName = currentName;
    if (sortMatches == 1 || separatorMatches == 1) {
        if (sortMatches == 1 && separatorMatches == 1) {
            displayName = [regexSort stringByReplacingMatchesInString:currentName
                                                              options:0
                                                                range:NSMakeRange(0, [currentName length])
                                                          withTemplate:@""];
            displayName = [regexSeparator stringByReplacingMatchesInString:displayName
                                                                   options:0
                                                                     range:NSMakeRange(0, [displayName length])
                                                               withTemplate:@""];
            addSeparator = YES;
        } else {
            if (sortMatches == 1) {
                displayName = [regexSort stringByReplacingMatchesInString:currentName
                                                                  options:0
                                                                    range:NSMakeRange(0, [currentName length])
                                                              withTemplate:@""];
                addSeparator = NO;
            }
            if (separatorMatches == 1) {
                displayName = [regexSeparator stringByReplacingMatchesInString:currentName
                                                                       options:0
                                                                         range:NSMakeRange(0, [currentName length])
                                                                   withTemplate:@""];
                addSeparator = YES;
            }
        }
    }

    if (outSeparator != NULL) {
        *outSeparator = addSeparator;
    }
    return displayName;
}

@end