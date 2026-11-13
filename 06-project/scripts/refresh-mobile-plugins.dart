// Fixed Flutter-OH tooling API: refresh only Android/iOS generated plugin files
// when the full pub command is unavailable without an installed Harmony SDK.
// Run the repository's check-flutter-oh.mjs first. This does not compile iOS,
// emulate a Harmony SDK, or edit the shared Flutter installation.
import 'dart:io';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/base/template.dart';
import 'package:flutter_tools/src/isolated/mustache_template.dart';
import 'package:flutter_tools/src/context_runner.dart' as runner;
import 'package:flutter_tools/src/flutter_plugins.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';

Future<void> main(List<String> args) async {
  if (args.length!=2 || !Directory(args[0]).existsSync() ||
      !File('${args[1]}/packages/flutter_tools/.dart_tool/package_config.json').existsSync()) {
    throw ArgumentError('Expected application root and verified fixed Flutter root');
  }
  Cache.flutterRoot=args[1];
  await runner.runInContext<void>(() async {
    final project=FlutterProject.fromDirectory(globals.fs.directory(args[0]));
    await refreshPluginsList(project);
    await injectPlugins(project,releaseMode:false,androidPlatform:true,iosPlatform:true);
  },overrides:{TemplateRenderer:()=>MustacheTemplateRenderer()});
  stdout.writeln('Refreshed Android/iOS plugin metadata using fixed Flutter tooling; no Harmony/iOS build claimed.');
}
