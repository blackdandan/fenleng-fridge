#import "FridgeDeferredPluginRegistrant.h"
@import camera_avfoundation;
@import fenleng_sdk_flutter_native_identity;
@import image_picker_ios;
@import permission_handler_apple;

#if __has_include(<firebase_core/FLTFirebaseCorePlugin.h>) && __has_include(<firebase_auth/FLTFirebaseAuthPlugin.h>) && __has_include(<google_sign_in_ios/GoogleSignInPlugin.h>)
#import <firebase_core/FLTFirebaseCorePlugin.h>
#import <firebase_auth/FLTFirebaseAuthPlugin.h>
#import <google_sign_in_ios/GoogleSignInPlugin.h>
#define FRIDGE_GLOBAL_PLUGINS 1
#else
#define FRIDGE_GLOBAL_PLUGINS 0
#endif

@implementation FridgeDeferredPluginRegistrant
+ (void)registerLocalWithRegistry:(NSObject<FlutterPluginRegistry>*)registry china:(BOOL)china {
    [CameraPlugin registerWithRegistrar:[registry registrarForPlugin:@"CameraPlugin"]];
    [FLTImagePickerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTImagePickerPlugin"]];
    [PermissionHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
    if (china) [FenlengNativeIdentityPlugin registerWithRegistrar:[registry registrarForPlugin:@"FenlengNativeIdentityPlugin"]];
}
+ (BOOL)registerGlobalWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
#if FRIDGE_GLOBAL_PLUGINS
    [FLTFirebaseCorePlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseCorePlugin"]];
    [FLTFirebaseAuthPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseAuthPlugin"]];
    [GoogleSignInPlugin registerWithRegistrar:[registry registrarForPlugin:@"GoogleSignInPlugin"]];
    return YES;
#else
    return NO;
#endif
}
@end
