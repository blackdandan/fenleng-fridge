# WP04 照片替换与文件回收子阶段

承接已批准WP04，不变更权限、账号或库存语义。原问题：替换图已复制到私有目录后，库存写盘失败会遗留候选文件；成功替换后的旧图也没有回收路径。旧图同时可能由撤销或backup引用，不能在替换成功后直接删除。

新增application/PhotoLifecycle与PhotoLibrary端口，ManagedFoodPhotos实现端口。替换失败只在current/undo/main/backup均无引用时删除本次候选，读取失败保留文件且重新抛出原保存错误；取消不改库存，记录已消失时也清理候选。成功替换保留原有撤销能力与可恢复快照。

应用同意后的启动：先repository.open完成恢复/提交/backup轮转，再执行文件回收，然后才展示业务就绪页。在没有拍摄或替换候选并发写入的这个窗口，扫描本应用photos目录的规则命名.image和.pending文件，保留current/undo/main/backup所有引用；不递归、不跟随链接、不触及其他文件名。Windows路径用规范化URI处理分隔符与大小写，避免把仍被引用的照片误判为垃圾。回收失败不阻止已有库存使用，下次启动重试。私有复制失败也会清理本次.pending文件。

当前验证：photo_lifecycle_test.dart新增3项真实临时磁盘测试，涵盖替换、真实undo、重启后backup轮转和旧图回收；保存失败/取消/记录消失；损坏backup停止回收、空源不留pending。bootstrap/capture/detail-history定向共10项通过，核心file_storage/repository7项通过，改动文件Dart analyze无问题。日志.fenleng/flutter-photo-lifecycle-{validation,analyze}.log。最后补充undo断言后单独3项再跑通过。

这是WP04内部定向验证，尚未重新打APK或验证Android系统相册替换全过程。当前APK仍为设置/反馈阶段74781b70，sourceAheadOfApk=true；将在相机UI阶段边界集中构建/设备复核，避免每个微步骤重跑全仓。旧图在仍被快照引用期间被有意保留，不承诺即时释放全部空间。完整相机视觉、系统通知、iOS/Harmony运行仍待完成。

后续相机阶段收口更新：上段为当时状态。当前已纳入APK；Android业务包ea64ffb8验证启动回收自建无引用.image/.pending、保留原3张引用照片及非规则文件，原库存/照片/权限/密度恢复。最终视觉包f8b4b951亦通过启动与430/320复核。全部App57项（含本文件3项）、10份golden、核心15项与Dart analyze通过。Bootstrap库存动作按文件职责移入inventory_actions分片，保留动态方法调用，不改变领域行为。系统相册替换全过程仍未做原生验收；本机磁盘替换失败/undo/备份轮转已验。详见../flutter-ui/pages/camera.md。
