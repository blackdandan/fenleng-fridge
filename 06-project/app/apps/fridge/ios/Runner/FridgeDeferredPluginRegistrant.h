#import <Flutter/Flutter.h>

@interface FridgeDeferredPluginRegistrant : NSObject
+ (void)registerLocalWithRegistry:(NSObject<FlutterPluginRegistry>*)registry china:(BOOL)china
    NS_SWIFT_NAME(registerLocal(with:china:));
+ (BOOL)registerGlobalWithRegistry:(NSObject<FlutterPluginRegistry>*)registry
    NS_SWIFT_NAME(registerGlobal(with:));
@end
