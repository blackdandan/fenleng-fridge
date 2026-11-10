// fl-figma-map-ui-loop · 真机/模拟器「到目标屏可靠入口」脚本。
//
// 经 VM Service WebSocket 调用 app 注册的路由直跳服务扩展（默认 `ext.app.goto`），
// **一行命令跳任意页**，免「截图 → 定位坐标 → adb tap」。无需第三方包（仅 dart:io），
// 也不依赖 Dart 3.9+ 的 driver 通道——低版本 SDK 同样能用。
//
// 用法：
//   dart run <本 skill 目录>/assets/vm_goto.dart <vmServiceHttpUri> <route> [extName]
// 例：
//   dart run vm_goto.dart http://127.0.0.1:57102/aBcDeFgHiJk=/ my_detail_page
// vmServiceHttpUri 取自 `flutter run` 打印的 "A Dart VM Service ... is available at:"。
//
// ---- 前置：app 侧要先注册这个扩展 ----
// 在 `main()` 里加（**必须 kDebugMode 守卫**，否则会进生产包）：
//
//   import 'dart:convert';
//   import 'dart:developer' as developer;
//   import 'package:flutter/foundation.dart';
//
//   final navigatorKey = GlobalKey<NavigatorState>();  // 也挂到 MaterialApp.navigatorKey
//
//   void _registerDebugGoto() {
//     if (!kDebugMode) return;
//     developer.registerExtension('ext.app.goto', (method, params) async {
//       final route = params['route'];
//       final ctx = navigatorKey.currentContext;
//       if (route == null || ctx == null) {
//         return developer.ServiceExtensionResponse.error(
//           developer.ServiceExtensionResponse.extensionError,
//           jsonEncode({'ok': false, 'reason': 'no route or app not ready'}),
//         );
//       }
//       // 换成本项目的导航方式（Navigator / go_router / 自研 Router 均可）：
//       Navigator.of(ctx).pushNamed(route);
//       return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true}));
//     });
//   }
//
// ⚠️ 调用方必须等 app 到首页再调——闪屏期 `navigatorKey.currentContext` 还是 null。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run vm_goto.dart <vmServiceHttpUri> <route> [extName]');
    exit(2);
  }
  final httpUri = args[0];
  final route = args[1];
  final ext = args.length >= 3 ? args[2] : 'ext.app.goto';

  // http(s)://host:port/token/  ->  ws(s)://host:port/token/ws
  final u = Uri.parse(httpUri);
  final wsUri = u
      .replace(scheme: u.scheme == 'https' ? 'wss' : 'ws')
      .resolve('ws')
      .toString();

  final ws = await WebSocket.connect(wsUri);
  var id = 0;
  final pending = <int, Completer<Map<String, dynamic>>>{};
  ws.listen((data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    final mid = msg['id'];
    if (mid is int && pending.containsKey(mid)) {
      pending.remove(mid)!.complete(msg);
    }
  });

  Future<Map<String, dynamic>> call(String method, [Map<String, dynamic>? params]) {
    final myId = ++id;
    final c = Completer<Map<String, dynamic>>();
    pending[myId] = c;
    ws.add(jsonEncode({'jsonrpc': '2.0', 'id': myId, 'method': method, if (params != null) 'params': params}));
    return c.future;
  }

  final vm = await call('getVM');
  final isolates = (vm['result']?['isolates'] as List?) ?? const [];
  if (isolates.isEmpty) {
    stderr.writeln('no isolates');
    await ws.close();
    exit(1);
  }
  final isolateId = isolates.first['id'] as String;

  final res = await call(ext, {'isolateId': isolateId, 'route': route});
  stdout.writeln(jsonEncode(res['result'] ?? res['error'] ?? res));
  await ws.close();
  exit(0); // WS stream 会保活 isolate，显式退出，否则进程挂住。
}
