//
//  SHTerminalAppBackend.m
//  Shuttle
//

#import "SHTerminalAppBackend.h"

@implementation SHTerminalAppBackend

- (BOOL)dispatchCommand:(SHTerminalCommand *)command error:(NSError **)error {
    NSString *scriptName = nil;
    switch (command.openMode) {
        case SHOpenModeNew:     scriptName = @"terminal-new-window"; break;
        case SHOpenModeCurrent: scriptName = @"terminal-current-window"; break;
        case SHOpenModeTab:     scriptName = @"terminal-new-tab-default"; break;
        default:
            return NO;
    }

    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:scriptName ofType:@"scpt"];
    // 复刻旧 openHost 对 Terminal.app 传参：command / theme / title。
    NSArray *parameters = @[ command.command ?: @"", command.theme ?: @"", command.title ?: @"" ];

    return [self runScript:scriptPath handler:@"scriptRun" parameters:parameters error:error];
}

- (BOOL)runScript:(NSString *)scriptPath
          handler:(NSString *)handlerName
       parameters:(NSArray *)parametersInArray
            error:(NSError **)error {
    NSDictionary *appleScriptCreationError = nil;
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:scriptPath]
                                                                        error:&appleScriptCreationError];

    if (handlerName && [handlerName length]) {
        // 复刻旧 runScript: 的 Apple 事件构建。
        int pid = [[NSProcessInfo processInfo] processIdentifier];
        NSAppleEventDescriptor *thisApplication = [NSAppleEventDescriptor descriptorWithDescriptorType:typeKernelProcessID
                                                                                                bytes:&pid
                                                                                               length:sizeof(pid)];

        // Carbon OpenScripting 常量（无需链接 Carbon.framework）。
        #define kASAppleScriptSuite 'ascr'
        #define kASSubroutineEvent  'psbr'
        #define keyASSubroutineName 'snam'

        NSAppleEventDescriptor *containerEvent = [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite
                                                                                          eventID:kASSubroutineEvent
                                                                                 targetDescriptor:thisApplication
                                                                                         returnID:kAutoGenerateReturnID
                                                                                    transactionID:kAnyTransactionID];
        [containerEvent setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:handlerName]
                                forKeyword:keyASSubroutineName];

        if ([parametersInArray count]) {
            NSAppleEventDescriptor *arguments = [[NSAppleEventDescriptor alloc] initListDescriptor];
            for (NSString *object in parametersInArray) {
                [arguments insertDescriptor:[NSAppleEventDescriptor descriptorWithString:object]
                                   atIndex:([arguments numberOfItems] + 1)];
            }
            [containerEvent setParamDescriptor:arguments forKeyword:keyDirectObject];
        }

        NSAppleEventDescriptor *result = [appleScript executeAppleEvent:containerEvent error:nil];
        return result != nil;
    }
    return NO;
}

@end