# 应用 AppID/AppSecret 接入契约

## 使用时机

用户表达“申请到 AppID/AppSecret”、“凭据放哪”、“给我存储脚本”或“确保打包能读取”时读取本契约。目标是让 Owner 只手工输入一次凭据，AI 完成其余绑定与最小必要验证。默认效率优先，复用已有工程配置，不为单一凭据引入多余清单、审批或全量扫描。

## 固定存储边界

| 资产 | 规范位置 | 是否进入 Git | 消费时机 |
| --- | --- | --- | --- |
| AppID / Client ID / Team ID 等非敏感标识 | 优先复用宿主项目已有原生配置；无等价位置时使用 `config/application-identifiers/<environment>.env` | 可以 | 客户端构建或服务端运行配置 |
| AppSecret / Client Secret / Token / 密码 / 私钥 | `knowledge/operations/credential-vault.md` 登记的 `/opt/fenleng-credential-vault/` 逻辑名称 | 不可以 | 服务端部署或运行时最小投放 |
| 服务实例所需 Secret 投影 | 已登记的 `/opt/<project>/<environment>/secrets/` 或项目现有等价目录 | 不可以 | 容器/进程启动时，仅对所需服务可见 |

新增 Vault 名称默认使用 `<projectId>-<environment>-<provider>-<purpose>-secret`，全部小写 kebab-case。已在 `credential-vault.md` 登记的历史名称继续使用，不为形式一致擅自重命名。

## 宿主项目绑定清单

当项目同时存在多 provider、多环境或多消费者，且只靠现有构建配置已不易确定绑定关系时，再维护不含凭据值的 `config/application-credential-bindings.json`。单一 provider/环境/消费者可直接以现有构建配置为真相源，不强制新增清单。需要清单时使用以下最小结构：

```json
{
  "schemaVersion": "1.0.0",
  "projectId": "scanister",
  "bindings": [
    {
      "id": "wechat-login",
      "environment": "production",
      "appId": {
        "file": "config/application-identifiers/production.env",
        "keys": ["FENLENG_PLATFORM_WECHAT_APP_ID"],
        "consumers": ["flutter"]
      },
      "appSecret": {
        "vaultName": "scanister-production-wechat-login-secret",
        "runtimeKey": "WECHAT_APP_SECRET",
        "consumers": ["shared-platform"],
        "delivery": "server-runtime-only"
      },
      "forbiddenConsumers": ["flutter", "web", "desktop-client"]
    }
  ]
}
```

绑定清单中只允许出现文件、配置键、Vault 名称、消费者和投放方式，不得出现 Secret 值。

## AI 执行流程

1. 检查宿主项目的 Flutter、Android、iOS、Web、小程序、桌面端、服务端和部署入口，只为真实存在的消费者建立绑定。
2. 明确 provider、purpose、`projectId`、`local|production`、AppID 键、Secret 运行时键、Vault 名称和禁止消费者。只在复杂绑定时更新绑定清单。
3. 对新 Vault 名称直接使用稳定命名生成存储脚本，不阻塞当前接入。当凭据进入生产、被多项目复用或进行发布治理时，再在 Fenlengtechbase `knowledge/operations/credential-vault.md` 批量登记名称和用途，不登记值。
4. 运行 `scripts/render-application-credential-script.mjs` 在宿主项目生成一次性存储脚本。脚本必须使用交互输入 AppID，并通过固定 SSH TTY 调用 `fl-secret set <vaultName>` 让 Owner 直接在远端输入 AppSecret；不得把 AppSecret 作为命令行参数、环境变量、脚本内容或本地临时文件。
5. 将脚本绝对路径和将要写入的非敏感位置告知 Owner；Owner 执行后只需回复“已存储”。
6. 修改项目构建入口，让移动端/网页/桌面端从 AppID 文件读取公开标识。如服务端需要 AppID，可读取同一非敏感来源。
7. 修改部署/运行入口，让已登记服务只在运行时获得 Secret。容器镜像构建、Flutter/Web/小程序打包不访问 Vault。
8. 默认只验证存在性和当前消费链路：`fl-secret list/status`、配置键存在和相关构建成功。生产或认证改动再加运行时健康/认证冒烟。不使用 `copy` 验证 Secret 值。
9. 本地单应用只检查变更文件和构建输出；生产、可分发客户端或多服务链路再扫描 Git diff、日志、bundle 和镜像。

## 生成脚本

```bash
node skills/fl-matrix-operator/scripts/render-application-credential-script.mjs \
  --project-root /absolute/path/to/project \
  --project-id scanister \
  --environment production \
  --provider wechat \
  --purpose login \
  --app-id-file config/application-identifiers/production.env \
  --app-id-key FENLENG_PLATFORM_WECHAT_APP_ID \
  --vault-name scanister-production-wechat-login-secret \
  --secret-runtime-key WECHAT_APP_SECRET \
  --output tool/store-scanister-wechat-production-credential.sh
```

`--app-id-key` 可重复，以便同一 AppID 同时写入 Flutter、Vite 或服务端已有的不同公开配置键。生成脚本不包含 AppID 或 AppSecret 值，可提交 Git；如项目只保留一次性运维脚本，执行验证后也可删除。

## 完成证据

- 现有构建配置或可选绑定清单与代码/构建入口的键一致。
- AppID 文件存在且不包含 Secret 键；Vault 只返回逻辑名称存在。
- 本次变更的客户端完成打包，且打包过程不读取 Secret；不要因单一端凭据变更强制全矩阵重建。
- 服务端镜像不含 Secret，部署后运行时配置存在且认证冒烟通过。
- 输出和审计证据只显示项目、环境、provider、purpose、配置键、Vault 名称和存在状态。
