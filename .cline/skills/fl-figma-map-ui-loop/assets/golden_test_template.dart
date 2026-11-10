// 纯 Flutter UI 卡片/区块的 golden 测试模板（拷到 <module>/test/ 下改用）。
//
// 用途：在设计基准宽下渲染成 PNG，离线 Read 比对 Figma 截图——无需设备/原生/用户确认。
// 生成/更新基准图：flutter test --update-goldens [--plain-name "<用例名>"] test/<this>.dart
//   （若项目用 fvm 等包装器，换成对应命令）。之后 Read test/goldens/<x>.png 与 figma 截图比对。
//
// 局限：flutter_test 默认字体无中文/非拉丁字形，文字会渲染成方块——布局/配色/结构可验，文字内容靠代码/spec 核对。
// 含原生 PlatformView 的卡在测试中渲染空白：不要 golden 整卡，只 golden 其 Flutter 头部/Flutter 态
// （可先 tap 切到 Flutter tab 再截）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:<your_module>/src/.../widgets/<widget>.dart'; // 被测 widget（同包可 import src/）

/// 设计基准宽（按本项目设计稿基准改，常见 375/390/750）。此宽下缩放因子应 == 1，对齐设计稿。
///
/// ⚠️ 正因为因子==1，**尺寸适配层写错与写对，在这个宽度下输出完全一样**——
/// golden 和保真采样都看不出来。含适配层的模块收尾要另跑一次非基准宽，
/// 见下方「非基准宽复看」用例。
const double _designWidth = 375;

/// 渲染单个卡片/区块。默认在设计基准宽下（缩放因子==1，对齐设计稿）；
/// 传 [width] 可换宽度，用于暴露尺寸适配层的错误。
Future<void> _pumpCard(WidgetTester tester, Widget card,
    {double width = _designWidth}) async {
  tester.view.physicalSize = Size(width, 320);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFEFF1FB), // 近似页面底色，便于观察阴影/磨砂
        body: SafeArea(
          // 若项目对 UI 做了等比缩放（Scope/Widget/全局因子），在此包裹以对齐基准宽
          // （基准宽下缩放因子==1）：
          // child: YourScaleScope(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(alignment: Alignment.topCenter, child: card),
          ),
          // ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('<卡名> golden', (tester) async {
    // await _pumpCard(tester, const YourCard(title: 'x', lastUpdateTime: '15:00'));
    // await expectLater(
    //   find.byType(YourCard),
    //   matchesGoldenFile('goldens/your_card.png'),
    // );
  });

  // 非基准宽复看：只有含尺寸适配层的模块需要。
  // 目的**不是**再固化一张基准图，而是确认布局等比跟随了宽度——
  // 缩放两次 / 漏过适配层，都只在这里现形（基准宽下两者输出一模一样）。
  testWidgets('<卡名> 非基准宽 320 布局跟随', (tester) async {
    // await _pumpCard(tester, const YourCard(title: 'x'), width: 320);
    // final w = tester.getSize(find.byType(YourCard)).width;
    // 预期：卡宽随容器等比收窄（这里减去左右各 16 的 Padding）。
    // 若得到的仍是基准宽下的数值 → 尺寸写死了，没过适配层。
    // expect(w, closeTo(320 - 32, 1));
  });

  testWidgets('<卡名·某态> golden', (tester) async {
    // 切到目标 tab/态再截（如原生 tab 测试中空白，先 tap 到 Flutter 态）：
    // await _pumpCard(tester, const YourCard(isLoggedIn: true));
    // await tester.tap(find.text('<目标 tab 文案>'));
    // await tester.pumpAndSettle();
    // await expectLater(find.byType(YourCard), matchesGoldenFile('goldens/your_card_state.png'));
  });
}
