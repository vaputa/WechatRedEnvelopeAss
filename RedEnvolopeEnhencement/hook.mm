//
//  hook.mm
//  RedEnvolopeEnhencement
//
//  Created by vaputa on 3/1/17.
//
//

#import <UIKit/UIKit.h>
#import "CaptainHook.h"
#import "NSLogger.h"

static int const kCloseRedEnvPlugin = 0;
static int const kOpenRedEnvPlugin = 1;
static int const kCloseRedEnvPluginForMyselfFromChatroom = 2;

static NSInteger HBPluginType = 1;
static NSInteger HBLatency = 3000;
static BOOL isDebugging = NO;
#define SAVESETTINGS { \
NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); \
NSString *docDir = [paths objectAtIndex:0]; \
if (!docDir){ return;} \
NSMutableDictionary *dict = [NSMutableDictionary dictionary]; \
NSString *path = [docDir stringByAppendingPathComponent:@"HBPluginSettings.txt"]; \
[dict setObject:[NSNumber numberWithInteger:HBPluginType] forKey:@"HBPluginType"]; \
[dict setObject:[NSNumber numberWithInteger:HBLatency] forKey:@"HBLatency"]; \
[dict writeToFile:path atomically:YES]; \
}

@interface AsyncManager : NSObject
+ (AsyncManager*) sharedInstance;
- (void) run:(dispatch_block_t)block;
@end

@implementation AsyncManager
static AsyncManager* sharedObject = nil;
dispatch_queue_t queue;

+ (AsyncManager*) sharedInstance {
    static dispatch_once_t onlyOnceToken;
    dispatch_once(&onlyOnceToken, ^{
        sharedObject = [[self alloc] init];
    });
    return sharedObject;
}

- (instancetype) init {
    if (self = [super init]) {
        queue = dispatch_queue_create("com.vaputa.redenvolopeenhencement", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)run:(dispatch_block_t)block {
    dispatch_async(queue, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            block();
        });
    });
}

@end

CHDeclareClass(CMessageMgr);

CHMethod(2, void, CMessageMgr, AsyncOnAddMsg, id, arg1, MsgWrap, id, arg2)
{
    CHSuper(2, CMessageMgr, AsyncOnAddMsg, arg1, MsgWrap, arg2);
    Ivar uiMessageTypeIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_uiMessageType");
    ptrdiff_t offset = ivar_getOffset(uiMessageTypeIvar);
    unsigned char *stuffBytes = (unsigned char *)(__bridge void *)arg2;
    NSUInteger m_uiMessageType = * ((NSUInteger *)(stuffBytes + offset));
    
    Ivar nsFromUsrIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsFromUsr");
    id m_nsFromUsr = object_getIvar(arg2, nsFromUsrIvar);
    
    Ivar nsContentIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsContent");
    id m_nsContent = object_getIvar(arg2, nsContentIvar);
    
    NSUInteger m_uiAppMsgInnerType = (NSUInteger)[arg2 objectForKey:@"m_uiAppMsgInnerType"];
    
    switch(m_uiMessageType) {
        case 1: {
            Method methodMMServiceCenter = class_getClassMethod(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
            IMP impMMSC = method_getImplementation(methodMMServiceCenter);
            id MMServiceCenter = impMMSC(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
            id contactManager = ((id (*)(id, SEL, Class))objc_msgSend)(MMServiceCenter, @selector(getService:),objc_getClass("CContactMgr"));
            id selfContact = objc_msgSend(contactManager, @selector(getSelfContact));
            
            Ivar nsUsrNameIvar = class_getInstanceVariable([selfContact class], "m_nsUsrName");
            id m_nsUsrName = object_getIvar(selfContact, nsUsrNameIvar);
            BOOL isMesasgeFromMe = [m_nsFromUsr isEqualToString:m_nsUsrName];
            
            LoggerData(1, @"%@: %@", m_nsFromUsr, m_nsContent);

            if (isMesasgeFromMe) {
                
                if ([m_nsContent isEqualToString:@"[Packet][Smart]"]) {
                    isDebugging = YES;
                }
                if ([m_nsContent isEqualToString:@"[Smart][Packet]"]) {
                    isDebugging = NO;
                }
                if (!isDebugging) {
                    break;
                }
                if ([m_nsContent isEqualToString:@"[Smile]"]) {
                    NSString *info = [NSString stringWithFormat:@"PluginType: %d\nLatency: %d", HBPluginType, HBLatency];
                    [[[UIAlertView alloc] initWithTitle:nil
                                                message:info
                                               delegate:nil
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:nil, nil]
                     show];
                } else if ([m_nsContent rangeOfString:@"芝麻开门"].location != NSNotFound
                           || [m_nsContent isEqualToString:@"[Smart]"]
                           || [m_nsContent isEqualToString:@"[Grin]"]) {
                    HBPluginType = kOpenRedEnvPlugin;
                } else if ([m_nsContent rangeOfString:@"芝麻关门"].location != NSNotFound
                           || [m_nsContent isEqualToString:@"[Silent]"]) {
                    HBPluginType = kCloseRedEnvPlugin;
                } else if ([m_nsContent isEqualToString:@"[Tongue]"]) {
                    HBPluginType = kCloseRedEnvPluginForMyselfFromChatroom;
                } else {
                    NSScanner* scan = [NSScanner scannerWithString:m_nsContent];
                    int value = 0;
                    if ([scan scanInt:&value] && [scan isAtEnd]) {
                        HBLatency = value;
                        NSLog(@"Change latency to %d", HBLatency);
                    }
                }
                SAVESETTINGS;
            }
        }
        break;
        case 49: {
            Method methodMMServiceCenter = class_getClassMethod(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
            IMP impMMSC = method_getImplementation(methodMMServiceCenter);
            id MMServiceCenter = impMMSC(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
            id logicMgr = ((id (*)(id, SEL, Class))objc_msgSend)(MMServiceCenter, @selector(getService:),objc_getClass("WCRedEnvelopesLogicMgr"));
            
            id statMgr = ((id (*)(id, SEL, Class))objc_msgSend)(MMServiceCenter, @selector(getService:),objc_getClass("SessionActionStatMgr"));

            id contactManager = ((id (*)(id, SEL, Class))objc_msgSend)(MMServiceCenter, @selector(getService:),objc_getClass("CContactMgr"));
            
            Method methodGetSelfContact = class_getInstanceMethod(objc_getClass("CContactMgr"), @selector(getSelfContact));
            IMP impGS = method_getImplementation(methodGetSelfContact);
            id selfContact = impGS(contactManager, @selector(getSelfContact));
            
            Ivar nsUsrNameIvar = class_getInstanceVariable([selfContact class], "m_nsUsrName");
            id m_nsUsrName = object_getIvar(selfContact, nsUsrNameIvar);
            BOOL isMesasgeFromMe = NO;
            BOOL isChatroom = NO;

            if ([m_nsFromUsr isEqualToString:m_nsUsrName]) {
                isMesasgeFromMe = YES;
            }
            if ([m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound) {
                isChatroom = YES;
            }
            
//            NSLog(@"isMesasgeFromMe: %d isChatroom: %d", isMesasgeFromMe, isChatroom);
//            NSLog(@"content: %@", m_nsContent);
//            NSLog(@"from user: %@", m_nsFromUsr);

            if (isMesasgeFromMe && HBPluginType == kCloseRedEnvPluginForMyselfFromChatroom) {
                break;
            }

            if ([m_nsContent rangeOfString:@"wxpay://"].location != NSNotFound) {
                NSString *nativeUrl = m_nsContent;
                NSRange rangeStart = [m_nsContent rangeOfString:@"wxpay://c2cbizmessagehandler/hongbao"];
                if (rangeStart.location != NSNotFound) {
                    NSUInteger locationStart = rangeStart.location;
                    nativeUrl = [nativeUrl substringFromIndex:locationStart];
                }
                
                NSRange rangeEnd = [nativeUrl rangeOfString:@"]]"];
                if (rangeEnd.location != NSNotFound) {
                    NSUInteger locationEnd = rangeEnd.location;
                    nativeUrl = [nativeUrl substringToIndex:locationEnd];
                }
                
                NSString *naUrl = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
                NSArray *parameterPairs =[naUrl componentsSeparatedByString:@"&"];
                NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:[parameterPairs count]];
                for (NSString *currentPair in parameterPairs) {
                    NSRange range = [currentPair rangeOfString:@"="];
                    if(range.location == NSNotFound)
                        continue;
                    NSString *key = [currentPair substringToIndex:range.location];
                    NSString *value =[currentPair substringFromIndex:range.location + 1];
                    [parameters setObject:value forKey:key];
                }
                
                NSMutableDictionary *params = [@{} mutableCopy];
                
                [params setObject:parameters[@"msgtype"]?:@"null" forKey:@"msgType"];
                [params setObject:parameters[@"sendid"]?:@"null" forKey:@"sendId"];
                [params setObject:parameters[@"channelid"]?:@"null" forKey:@"channelId"];
                
                id getContactDisplayName = objc_msgSend(selfContact, @selector(getContactDisplayName));
                id m_nsHeadImgUrl = objc_msgSend(selfContact, @selector(m_nsHeadImgUrl));
                
                [params setObject:getContactDisplayName forKey:@"nickName"];
                [params setObject:m_nsHeadImgUrl forKey:@"headImg"];
                [params setObject:[NSString stringWithFormat:@"%@", nativeUrl]?:@"null" forKey:@"nativeUrl"];
                [params setObject:m_nsFromUsr?:@"null" forKey:@"sessionUserName"];
                
                if (kCloseRedEnvPlugin != HBPluginType) {
                    NSLog(@"Latency parameter: %d", HBLatency);
                    int64_t delay = HBLatency;
                    if (delay < 0) {
                        delay = arc4random_uniform(-delay) + 1000;
                    } else {
                        delay += arc4random_uniform(1000);
                    }
                    NSLog(@"Actual latency %lldms", delay);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * (NSEC_PER_SEC / 1000))), dispatch_get_main_queue(), ^{
                        NSLog(@"Opening...");
                        objc_msgSend(statMgr, @selector(addIMBehaviorMsgOp:appMsgInnerType:msgOpType:), m_uiMessageType, 2001, 0x2);
                        ((void (*)(id, SEL, NSMutableDictionary*))objc_msgSend)(logicMgr, @selector(OpenRedEnvelopesRequest:), params);
                    });
                }
                return;
            }
            break;
        }
        default:
            break;
    }
    NSLog(@"Plugin Status: %d\nLatency parameter: %d\n", HBPluginType, HBLatency);
}

static void init() {
    LoggerStart(LoggerGetDefaultLogger());
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths objectAtIndex:0];
    if (docDir){
        NSString *path = [docDir stringByAppendingPathComponent:@"HBPluginSettings.txt"];
        NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:path];
        NSLog(@"%@\n", dict);
        if(dict) {
            if ([dict objectForKey:@"HBPluginType"]) {
                HBPluginType = [[dict objectForKey:@"HBPluginType"] integerValue];
            } else {
                HBPluginType = 1;
            }
            if ([dict objectForKey:@"HBLatency"]) {
                HBLatency = [[dict objectForKey:@"HBLatency"] integerValue];
            } else {
                HBLatency = 3000;
            }
        }
    }
}

CHDeclareClass(MMMsgLogicManager);
CHMethod(3, void, MMMsgLogicManager, PushLogicController, id, arg1, navigationController, id, arg2, animated, id, arg3) {
    CHSuper(3, MMMsgLogicManager, PushLogicController, arg1, navigationController, arg2, animated, arg3);
    NSLog(@"MMMsgLogicManager: %s %@ %@", __FUNCTION__, arg1, arg2);
}

CHDeclareClass(BaseMsgContentLogicController);
CHMethod(2, void, BaseMsgContentLogicController, OnAddMsg, id, arg1, MsgWrap, id, arg2) {
    CHSuper(2, BaseMsgContentLogicController, OnAddMsg, arg1, MsgWrap, arg2);
    NSLog(@"BaseMsgContentLogicController: %s %@ %@", __FUNCTION__, arg1, arg2);
}

CHMethod(1, void, BaseMsgContentLogicController, onClickMsg, id, arg1) {
    CHSuper(1, BaseMsgContentLogicController, onClickMsg, arg1);
    NSLog(@"BaseMsgContentLogicController: %s %@", __FUNCTION__, arg1);
}

CHDeclareClass(BaseMsgContentViewController);
CHMethod(0, void, BaseMsgContentViewController, redEnvelopesLogic) {
    CHSuper(0, BaseMsgContentViewController, redEnvelopesLogic);
    NSLog(@"BaseMsgContentViewController: %s", __FUNCTION__);
}

CHMethod(3, void, BaseMsgContentViewController, MessageReturn, unsigned long, arg1, MessageInfo, id, arg2, Event ,unsigned long ,arg3) {
    CHSuper(3, BaseMsgContentViewController, MessageReturn, arg1, MessageInfo, arg2, Event, arg3);
    NSLog(@"BaseMsgContentViewController: %s", __FUNCTION__);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UITableView *tableView = [self valueForKey:@"m_tableView"];
        NSArray *cells = [tableView visibleCells];
        NSLog(@"==================================================");
        for (UITableViewCell *cell in [cells reverseObjectEnumerator]) {
            for (UIView *view in cell.contentView.subviews) {
                id mcv = objc_getClass("WCPayC2CMessageCellView");
                NSLog(@"%@", view);
                if ([view isKindOfClass:mcv]) {
                    static NSMutableArray *messages = [NSMutableArray new];
                    id cMessage = [[view valueForKey:@"m_viewModel"] valueForKey:@"m_messageWrap"]; // CMessageWrap
//                    NSLog(@"### m_descLabel\t %@", [view valueForKey:@"m_descLabel"]);
//                    NSLog(@"### m_titleLabel\t %@", [view valueForKey:@"m_titleLabel"]);
                    NSLog(@"### %@", [cMessage valueForKey:@"m_nsContent"]);
                    if (![messages containsObject:[cMessage valueForKey:@"m_nsContent"]]) {
                        NSLog(@"Trying to open...");
                        [messages addObject:[cMessage valueForKey:@"m_nsContent"]];
                        [[AsyncManager sharedInstance] run:^{
                            NSLog(@"Click Red Packet");
                            [view performSelector:@selector(onTouchUpInside)];
                            NSLog(@"Finish Click");
                        }];
                    }
                }
            }
        }
    });
}

CHDeclareClass(UINavigationController);
CHMethod(2, void, UINavigationController, pushViewController, UIViewController*, viewController, animated, BOOL, animated) {
    if ([viewController isKindOfClass:objc_getClass("WCRedEnvelopesRedEnvelopesDetailViewController")]) {
        return ;
    }
    CHSuper(2, UINavigationController, pushViewController, viewController, animated, animated);
    NSLog(@"UINavigationController: %s %@", __FUNCTION__, viewController);
}

CHDeclareClass(WCRedEnvelopesReceiveHomeView);
CHMethod(1, void, WCRedEnvelopesReceiveHomeView, refreshViewWithData, id, arg1) {
    CHSuper(1, WCRedEnvelopesReceiveHomeView, refreshViewWithData, arg1);
    NSLog(@"WCRedEnvelopesReceiveHomeView: %s", __FUNCTION__);
    if (![[self valueForKey:@"openRedEnvelopesButton"] isHidden]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSLog(@"Opening red envelopes");
            [self performSelector:@selector(OnOpenRedEnvelopes)];
            NSLog(@"Finish opening red envelopes");
            [self performSelector:@selector(OnCancelButtonDone)];
            NSLog(@"Close");
        });
    }
}
CHMethod(0, void, WCRedEnvelopesReceiveHomeView, OnOpenRedEnvelopes) {
    CHSuper(0, WCRedEnvelopesReceiveHomeView, OnOpenRedEnvelopes);
    NSLog(@"WCRedEnvelopesReceiveHomeView: %s", __FUNCTION__);
}

CHDeclareClass(WCRedEnvelopesReceiveControlLogic);
CHMethod(0, void, WCRedEnvelopesReceiveControlLogic, WCRedEnvelopesReceiveHomeViewOpenList) {
    //    CHSuper(0, WCRedEnvelopesReceiveControlLogic, WCRedEnvelopesReceiveHomeViewOpenList);
    NSLog(@"WCRedEnvelopesReceiveControlLogic: %s", __FUNCTION__);
}

__attribute__((constructor)) static void entry() {
    CHLoadLateClass(CMessageMgr);
    CHClassHook(2, CMessageMgr, AsyncOnAddMsg, MsgWrap);
    
    CHLoadLateClass(MMMsgLogicManager);
    CHClassHook(3, MMMsgLogicManager, PushLogicController, navigationController, animated);
    
    CHLoadLateClass(BaseMsgContentLogicController);
    CHClassHook(2, BaseMsgContentLogicController, OnAddMsg, MsgWrap);
    CHClassHook(1, BaseMsgContentLogicController, onClickMsg);
    
    CHLoadLateClass(BaseMsgContentViewController);
    CHClassHook(0, BaseMsgContentViewController, redEnvelopesLogic);
    CHClassHook(3, BaseMsgContentViewController, MessageReturn, MessageInfo, Event);
    
    CHLoadLateClass(WCRedEnvelopesReceiveHomeView);
    CHClassHook(1, WCRedEnvelopesReceiveHomeView, refreshViewWithData);
    CHClassHook(0, WCRedEnvelopesReceiveHomeView, OnOpenRedEnvelopes);
    
    CHLoadLateClass(WCRedEnvelopesReceiveControlLogic);
    CHClassHook(0, WCRedEnvelopesReceiveControlLogic, WCRedEnvelopesReceiveHomeViewOpenList);
    
    CHLoadLateClass(UINavigationController);
    CHClassHook(2, UINavigationController, pushViewController, animated);
    
    init();
}
