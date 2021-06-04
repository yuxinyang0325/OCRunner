//
//  ORThreadContext.m
//  OCRunner
//
//  Created by APPLE on 2021/6/4.
//

#import "ORThreadContext.h"
#import "MFValue.h"
#import "MFScopeChain.h"
@interface ORCallFrameStack()
@property(nonatomic, strong) NSMutableArray<NSArray *> *array;
@end
@implementation ORCallFrameStack
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.array = [NSMutableArray array];
    }
    return self;
}
+ (void)pushMethodCall:(ORMethodImplementation *)imp instance:(MFValue *)instance{
    [[ORCallFrameStack threadStack].array addObject:@[instance, imp]];
}
+ (void)pushFunctionCall:(ORFunctionImp *)imp scope:(MFScopeChain *)scope{
    [[ORCallFrameStack threadStack].array addObject:@[scope, imp]];
}
+ (void)pop{
    [[ORCallFrameStack threadStack].array removeLastObject];
}
+ (instancetype)threadStack{
    return ORThreadContext.threadContext.callFrameStack;
}
+ (NSString *)history{
    NSMutableArray *frames = [ORCallFrameStack threadStack].array;
    NSMutableString *log = [@"OCRunner Frames:\n\n" mutableCopy];
    for (int i = 0; i < frames.count; i++) {
        NSArray *frame = frames[i];
        if ([frame.firstObject isKindOfClass:[MFValue class]]) {
            MFValue *instance = frame.firstObject;
            ORMethodImplementation *imp = frame.lastObject;
            [log appendFormat:@"%@ %@ %@\n", imp.declare.isClassMethod ? @"+" : @"-", instance.objectValue, imp.declare.selectorName];
        }else{
            MFScopeChain *scope = frame.firstObject;
            ORFunctionImp *imp = frame.lastObject;
            if (imp.declare.funVar.varname == nil){
                [log appendFormat:@"Block Call: Captured external variables '%@' \n",[scope.vars.allKeys componentsJoinedByString:@","]];
                // 比如dispatch_after中的block，此时只会孤零零的提醒你一个Block Call
                // 异步调用时，此时通过语法树回溯，可以定位到 block 所在的类以及方法名
                if (i == 0) {
                    ORNode *parent = imp.parentNode;
                    while (parent != nil ) {
                        if ([parent isKindOfClass:[ORClass class]]) {
                            [log appendFormat:@"Block Code in Class: %@\n", [(ORClass *)parent className]];
                        }else if ([parent isKindOfClass:[ORMethodImplementation class]]){
                            ORMethodImplementation *imp = (ORMethodImplementation *)parent;
                            [log appendFormat:@"Block Code in Method: %@%@\n", imp.declare.isClassMethod ? @"+" : @"-", imp.declare.selectorName];
                        }
                        parent = parent.parentNode;
                    }
                }
            }else{
                [log appendFormat:@" CFunction: %@\n", imp.declare.funVar.varname];
            }
        }
    }
    return log;
}
@end

@interface ORArgsStack()
@property(nonatomic, strong) NSMutableArray<NSMutableArray *> *array;
@end
@implementation ORArgsStack
- (instancetype)init{
    if (self = [super init]) {
        _array = [NSMutableArray array];
    }
    return self;
}
+ (instancetype)threadStack{
    return ORThreadContext.threadContext.argsStack;
}
+ (void)push:(NSMutableArray <MFValue *> *)value{
    NSAssert(value, @"value can not be nil");
    [ORArgsStack.threadStack.array addObject:value];
}

+ (NSMutableArray <MFValue *> *)pop{
    NSMutableArray *value = [ORArgsStack.threadStack.array  lastObject];
    NSAssert(value, @"stack is empty");
    [ORArgsStack.threadStack.array removeLastObject];
    return value;
}
+ (BOOL)isEmpty{
    return [ORArgsStack.threadStack.array count] == 0;
}
+ (NSUInteger)size{
    return ORArgsStack.threadStack.array.count;
}
@end

@implementation ORThreadContext
+ (instancetype)threadContext{
    //每一个线程拥有一个独立的上下文
    NSMutableDictionary *threadInfo = [[NSThread currentThread] threadDictionary];
    ORThreadContext *ctx = threadInfo[@"ORThreadContext"];
    if (!ctx) {
        ctx = [[ORThreadContext alloc] init];
        threadInfo[@"ORThreadContext"] = ctx;
    }
    return ctx;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.argsStack = [[ORArgsStack alloc] init];
        self.callFrameStack = [[ORCallFrameStack alloc] init];
    }
    return self;
}
@end
