# fenleng-fridge

冰箱照片记录产品：Flutter Android/iOS/HarmonyOS NEXT App、微信小程序和静态官网。照片与库存留在本机，联网功能复用Shared Platform。

开发预览：https://fridge.fenlengtech.com/ 。当前APK为明确标注的未加固Debug预览，不是正式发行。

## 工程入口

- `06-project/app`：固定Flutter-OH/FVM的Melos工作区。先按`.fvmrc`安装对应fork，然后执行`fvm dart pub get`；App入口在`apps/fridge`。
- `06-project/mini-program`：`pnpm install --frozen-lockfile`、`pnpm typecheck`、`pnpm build:weapp`。
- `06-project/web`：`npm ci`、`npm run build`、`npm run check`。默认构建要求实际已验证APK可用；仅预览源页面时显式使用`node scripts/build.mjs --without-android`及`node scripts/check.mjs --without-android`。

Flutter的三份官方SDK候选位于`06-project/app/vendor/flsdk`，工作区使用相对路径override；来源commit和逐文件哈希见candidate-provenance.json。它们与已验证交付包同版，尚未冒充正式上游发行。构建不依赖同级SDK工作区；本地私有override、签名、缓存和构建输出不提交。

完整源归档/构建命令、固定签名Vault恢复、原生工具限制见[交付入口](04-operations/delivery-candidate.md)。正式AppID、Provider、微信主机、iOS/Mac、Harmony工具及正式发行待办见[Owner清单](04-operations/owner-follow-ups.md)。线上部署/回滚见[预览站手册](03-deployment/preview-website-runbook.md)。

`00-context`至`05-knowledge`保存产品、工程、部署和证据；旧MVP与原型已迁入`01-product/mvp`及`06-project/prototype`。`.fenleng`仅存本机临时产物，已筛选的验收证据在`02-engineering/evidence`。
