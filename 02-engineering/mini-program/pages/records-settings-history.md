# 微信详情、设置、历史源码阶段

承接WP02/03/04、既有设计和持续实现授权。Figma b34I8tzPpU7tv1sHHdWLkq，本轮读取2:149（含53:2编辑窗）、2:172、2:227的高保真上下文与截图；基座规范来源沿用../../design-system-evidence.json固定069718f51642df16e5c80c757943ce03621fd4a0。

## 实现

- 详情保留原区域/整理/历史背景，编辑窗有16物理px边距、避开宿主顶部，并使用真正ScrollView。可修改日期/时间、区域、间隔、提醒；替换通过微信原生chooseMedia选择拍摄或相册。删除必须确认，取消不删记录。
- 只移动、改间隔、替换或原样保存不改周期和原日期精度；显式改提醒才生成新周期。写失败保留草稿/候选、允许重试；取消、关闭或迟到授权不提交。目标记录发生其它修改时拒绝覆盖；成功后重复保存不再提交。
- 历史有在库/历史数量与切换，连接详情、恢复、永久删除；恢复创建新周期而非复活旧提醒，失败保留卡片可重试。
- 设置默认间隔与时刻只影响未来新记录；连接历史、账号、20语言、系统/浅/深主题、底部法律/反馈和备案。FRIDGE_MINI_FILING注入真实小程序备案号，未配置专用占位。点击备案复制工信部查询网址，不能声称微信可按App方式打开任意外站。
- 反馈仍未接真实服务，当前入口如实显示不可用及fenlengtech@163.com，没有假回执；后续WP05继续实现草稿/SDK提交。微信订阅消息仍属WP06。

## 数据与图片

RecordEditor/Repository保持纯应用层，无Taro/React。current/undo/backup共同保留照片引用。取消清理候选；删除不误删其它记录共享的照片，不回退nextNumber，不能从undo/备份复活已成功永久删除的记录。

启动回收在同意、仓库打开之后且ready之前运行，没有正在拍摄/编辑的候选。仅扫描fridge-photos单目录、匹配本功能命名的普通文件，不递归、不删目录/非规则文件/引用照片。替换旧图在备份和撤销引用过期后可于下次启动回收。

显示偏好用fridge.display.v1单次原生写入，保留并支持读取旧fridge.locale/theme键；失败不留下语言/主题半提交。损坏显示值仅内存回退系统，保留存储证据且不挡库存；无效同意仍不能视为授权。

## 视觉和资源

沿用430设计宽、Taro rpx转换、600物理px限宽、系统文字缩放和宿主安全区。新页面使用同一Token。日期SVG根11.6667×12.5，放入16槽；下拉10×6，设置区域16×16，时钟11.375×11.375。六份SVG与Flutter原始Figma导出逐字节一致；示例食材图不进入产品。

报告../../evidence/mini-program/record-settings-source-results.json验证Token引用、无新增硬编码颜色、SVG字节/根尺寸、20语言153key副本与变量一致及编译路由存在。**没有微信开发者工具/真机截图，不能视为数字保真、原生控件或设备验收。** 三行保持🔶。

## 验证与未完成

全小程序43项通过，新增编辑9、偏好3、设置/恢复/背景4和真实磁盘回收1，共17项。随后终态重复保存保护的编辑9项定向再通过。TypeScript、平台依赖边界、源码Token/资产/语言门禁和最新weapp构建通过。日志.fenleng/mini-details-settings-full.log、mini-record-editor-final-targeted.log、mini-build-details-settings-final.log。

最新编译产物约802KB；common.js379KiB超过webpack244KiB推荐值，保留性能警告。没有上传、发布或宣称正式AppID可用。微信权限、Picker/输入键盘/ScrollView、chooseMedia、图片、RTL/大字仍需开发者工具和真机验证。Node直接导入Taro缺少编译运行时常量，未注入伪wx全局冒充微信运行。

App本轮只同步新增小程序备案文案key，未因此重打Android，旧APK仍为152key；状态标记sourceAheadOfApk。后续继续完整反馈、订阅消息、平台游客/遥测、鸿蒙通知和官网，整体目标进行中。

阶段知识审计 `fl.cmd kno audit --project . --base HEAD` 通过、nextAction=none，日志.fenleng/mini-details-settings-knowledge-audit.log；没有提交、推送或发布。
