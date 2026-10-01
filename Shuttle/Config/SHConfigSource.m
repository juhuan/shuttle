//
//  SHConfigSource.m
//  Shuttle
//

#import "SHConfigSource.h"

@interface SHConfigSource ()
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, copy) NSString *jsonPath;
@property (nonatomic, copy) NSString *altJsonPath;
@property (nonatomic, assign) BOOL parseAltJSON;
@end

@implementation SHConfigSource

- (instancetype)init {
    return [self initWithHomeDirectory:NSHomeDirectory() fileManager:[NSFileManager defaultManager]];
}

- (instancetype)initWithHomeDirectory:(NSString *)home fileManager:(NSFileManager *)fileManager {
    self = [super init];
    if (self) {
        _fileManager = fileManager;

        NSString *shuttleJSONPathPref = [home stringByAppendingPathComponent:@".shuttle.path"];
        NSString *shuttleJSONPathAlt = [home stringByAppendingPathComponent:@".shuttle-alt.path"];

        // 主配置路径解析（复刻 awakeFromNib）。
        if ([fileManager fileExistsAtPath:shuttleJSONPathPref]) {
            NSString *p = [NSString stringWithContentsOfFile:shuttleJSONPathPref encoding:NSUTF8StringEncoding error:NULL];
            _jsonPath = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        } else {
            NSString *defaultPath = [home stringByAppendingPathComponent:@".shuttle.json"];
            if (![fileManager fileExistsAtPath:defaultPath]) {
                NSString *bundleDefault = [[NSBundle mainBundle] pathForResource:@"shuttle.default" ofType:@"json"];
                if (bundleDefault != nil) {
                    [fileManager copyItemAtPath:bundleDefault toPath:defaultPath error:nil];
                }
            }
            _jsonPath = defaultPath;
        }

        // 第二配置路径解析。
        if ([fileManager fileExistsAtPath:shuttleJSONPathAlt]) {
            NSString *p = [NSString stringWithContentsOfFile:shuttleJSONPathAlt encoding:NSUTF8StringEncoding error:NULL];
            _altJsonPath = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            _parseAltJSON = YES;
        } else {
            NSString *altDefault = [home stringByAppendingPathComponent:@".shuttle-alt.json"];
            _altJsonPath = altDefault;
            _parseAltJSON = [fileManager fileExistsAtPath:altDefault];
        }
    }
    return self;
}

- (NSDate *)mtimeForFile:(NSString *)file {
    NSDictionary *attributes = [self.fileManager attributesOfItemAtPath:[file stringByExpandingTildeInPath] error:nil];
    return [attributes fileModificationDate];
}

- (BOOL)needUpdateForFile:(NSString *)file old:(NSDate *)old {
    if (![self.fileManager fileExistsAtPath:[file stringByExpandingTildeInPath]]) {
        return NO;
    }
    if (old == nil) {
        return YES;
    }
    NSDate *date = [self mtimeForFile:file];
    return [date compare:old] == NSOrderedDescending;
}

- (BOOL)needsMenuReload {
    BOOL needs = [self needUpdateForFile:self.jsonPath old:self.jsonMTime] ||
                 [self needUpdateForFile:self.altJsonPath old:self.altJsonMTime] ||
                 [self needUpdateForFile:@"/etc/ssh/ssh_config" old:self.sshSystemMTime] ||
                 [self needUpdateForFile:@"~/.ssh/config" old:self.sshUserMTime];

    if (needs) {
        self.jsonMTime = [self mtimeForFile:self.jsonPath];
        self.altJsonMTime = [self mtimeForFile:self.altJsonPath];
        self.sshSystemMTime = [self mtimeForFile:@"/etc/ssh/ssh_config"];
        self.sshUserMTime = [self mtimeForFile:@"~/.ssh/config"];
    }
    return needs;
}

@end