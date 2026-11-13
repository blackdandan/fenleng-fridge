# 迁移报告 · 已确认并执行

日期：2026-11-13。模式：`migrate-existing-project`。确定性程序已执行规划模式，未使用 `--apply-migration`。规划阶段创建目录/指导文件；Owner 随后确认包名与迁移，现已按下列映射执行，原资产完整保留。下列表格与步骤保留为迁移前方案追溯。

## 顶层强映射

| 当前路径 | 动作 | 目标 | 说明 |
| --- | --- | --- | --- |
| `.agents` | keep | `.agents` | 已安装 Skills，不迁移 |
| `.claude` | keep | `.claude` | 宿主配置 |
| `.cline` | keep | `.cline` | 宿主配置 |
| `.fenleng` | ignore | `.fenleng` | 本机状态，不作为产品资产迁移 |
| `.gemini` | keep | `.gemini` | 宿主配置 |
| `.git` | ignore | `.git` | Git 元数据 |
| `00-context` | keep | `00-context` | 本轮新建的标准资产目录 |
| `01-product` | keep | `01-product` | 本轮新建的标准资产目录 |
| `02-engineering` | keep | `02-engineering` | 本轮新建的标准资产目录 |
| `03-deployment` | keep | `03-deployment` | 本轮新建的标准资产目录 |
| `04-operations` | keep | `04-operations` | 本轮新建的标准资产目录 |
| `05-knowledge` | keep | `05-knowledge` | 本轮新建的标准资产目录 |
| `06-project` | keep | `06-project` | 本轮新建的标准资产目录 |
| `AGENTS.md` | keep | `AGENTS.md` | 宿主指令 |
| `CLAUDE.md` | keep | `CLAUDE.md` | 宿主指令 |
| `GEMINI.md` | keep | `GEMINI.md` | 宿主指令 |
| `docs` | merge | `见分项` | 按产品/排障分类，目录空后移除 |
| `fenleng.project.yaml` | keep | `fenleng.project.yaml` | 根知识清单骨架，迁移后更新 docs/mvp 根 |
| `preview` | move | `06-project/prototype/` | 先移出 figma-qa，剩余原型整体保留内部结构 |
| `product-core-openapi.json` | keep | `product-core-openapi.json` | 无自建后端的空 paths 索引骨架 |
| `scripts` | move | `06-project/scripts/` | 整体迁移，随后修复 legal 构建脚本路径 |

## 文档与原型分项

| 当前路径 | 动作 | 目标 |
| --- | --- | --- |
| docs/mvp/ | move | 01-product/mvp/ |
| docs/spec/knowledge-fetch-reliability.md | move | 05-knowledge/troubleshooting/knowledge-fetch-reliability.md |
| preview/figma-qa/ | move | 01-product/references/figma-qa/ |
| preview/ 下其余内容 | move | 06-project/prototype/，内部 mvp/website/shared/server.cjs 与源文件相对布局不变 |
| scripts/ | move | 06-project/scripts/，保持源文件集合 |

`docs/spec/` 与 `preview/figma-qa/` 在本轮开始前已为未跟踪资产；一并保留，不混同于本轮新增文件，不清理。诊断 spec 是上游知识抓取排障来源，不作为本产品业务开发 spec。迁移前记录原有 docs/preview/scripts 文件集合与内容基线，迁移后核验数量与内容，允许的差异仅为下文路径适配。若目标存在同名文件，停止并列出冲突，不覆盖。

## 确认后的执行顺序

1. 记录 Git 状态与源文件清单/哈希，先移动文档、截图，再整体移动原型与脚本。最终绝对路径必须位于当前仓库根 `D:/Development/WorkSpaces/CodeXWP/fenleng-fridge/` 内，使用原生 PowerShell LiteralPath 或 Python Path，不跨 shell 计算删除。
2. 适配 `06-project/scripts/build-preview-legal.mjs`：仓库根改为脚本目录向上两级，输入改为 `01-product/mvp`，输出改为 `06-project/prototype/shared`；同时修复生成物注释。协议版本保持 V0.3（产品 V0.4 不等于法律版本升级）。
3. 全仓更新文档中的旧 docs/mvp、preview、scripts 命令与链接；重点修复 handoff/MVP/surface-scope 相互链接、project.yaml 的事件/协议目录、根 manifest knowledge roots 及链接入口。历史证据中的旧路径标注“迁移前”，不篡改历史事实。相机与通知等业务逻辑本轮不修改。
4. 用新脚本重新生成共同法律正文并确认仅预期路径/注释变化；验证原型与官网现有验证器的路径假设，必要时只调整路径。保留原型/官网的内部相对资源与返回链接。
5. 重启 4173 原型与 4180 统一预览服务，4173 指向 `06-project/prototype/mvp/`，4180 使用 `node 06-project/prototype/server.cjs`。检查首页、CSS/JS、官网、两份协议和返回路径；端口与可访问 URL 不变。
6. 依据本地草案 `registry-entry.json`，按 ID 去重将本项目登记至基座 `knowledge/project-matrix/projects.json`，保留其他条目；本报告确认范围包含这项登记，不包含 Shared Platform/SDK 功能升级、推送或发布。基座文件若有并发修改先保留并合并，不能整表覆盖。当前仍是草案，未跨仓修改。
7. 验证全路径映射、源资产保全、无旧运行路径与断链、三个空工程容器，更新迁移状态及结构化结果。文档验收不代替原型功能或原生设备验收。

## 风险、恢复与范围

移动前停止依赖旧绝对路径的预览进程；短时本地预览中断可恢复。遇到验证失败先保留所有资产，按本报告逆向映射移回并恢复路径适配，不使用 reset --hard 或删除未跟踪文件。已有进程启动命令应先记录再重启。

没有自建 server；不初始化 Flutter/Taro 业务工程，不安装 SDK，不部署官网，不修改 DNS/凭据，不推送仓库。三端包名已确认 com.fenlengtech.fridge，微信 AppID 未确定；官网域名已确定但上线未核实。

报告中的所有路径均有明确动作，现无未归属的 manual-review 路径。迁移批准后如发现新增路径或冲突，补充强映射并说明，不能直接忽略或删除。

## 确认要求来源

[fl-mvp-to-project](../.agents/skills/fl-mvp-to-project/SKILL.md) 明确要求：“实际迁移前必须先生成 `00-context/migration-report.md`，经用户确认后才能执行移动或合并。” Owner 已于 2026-11-13 明确回复“com.fenlengtech.fridge 确认迁移”，满足该要求；已执行迁移与本地中央登记，未提交推送。

## 执行记录

- 全部 88 个原有文件在迁移前记录 SHA-256，移动后、路径适配前逐一一致。文件清单见 `migration-inventory.json`。
- 产品、排障、Figma 截图、原型与脚本已按映射归位；旧 docs/preview/scripts 目录已移除。原型首次整体重命名遇到 Windows 目录占用，重试后成功，未覆盖或丢失文件。
- 法律构建脚本按新根路径运行，版本维持 V0.3；协议正文未变。4173/4180 服务已使用新工作目录重启。
- 中央登记仅新增 fenleng-fridge 条目，保留基座仓库原有未提交修改；不包含上游功能变更。
- 验证结果最终记录于 `execution-result.json`。
