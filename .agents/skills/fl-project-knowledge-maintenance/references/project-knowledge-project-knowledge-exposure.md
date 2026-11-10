# Project Knowledge Exposure Rule

## 适用场景

当宿主项目创建、修改或校验 `fenleng.project.yaml`，或 Project Knowledge MCP 读取项目资产时，必须遵守本规则。

## 真相源

项目仓库维护自己的 Manifest、Contract、Schema、架构文档和发布记录。Project Registry 只保存发现元数据，MCP 只负责受控读取，不复制完整项目知识。

## 暴露边界

- `knowledge.roots` 必须是仓库内相对目录，不得使用仓库根、绝对路径、反斜杠或 `..`。
- `knowledge.entrypoints` 必须位于声明的知识根内并真实存在。
- `.git/`、`.env`、密钥、凭据、用户数据和构建秘密不得成为知识入口。
- `deniedPaths` 的优先级高于知识根和入口。
- `allowedConsumers: ["*"]` 仅表示已认证的 Fenlengtech 项目矩阵内可读，不表示互联网公开。
- MCP 查询结果必须携带 repository、ref、commit、source 和 retrievedAt，不得把缓存内容无版本地表述为当前事实。

## 维护触发条件

公开 API、Schema、跨项目依赖、服务边界、兼容性、Owner、项目状态或知识入口变化时，代码交付必须同步更新对应知识资产。

## 人类控制点

中央 Registry 登记、跨项目契约修改、远程仓库写入、提交、推送和发布必须经过人类明确授权。接入和查询阶段默认只读。
