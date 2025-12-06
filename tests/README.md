CC-Switch Test Guide / CC-Switch 测试指南
========================================

## 1. Test Overview / 测试概览
- Frontend: Vitest + React Testing Library + MSW (Tauri API mocks) cover hooks, components, and UI flows. / 前端使用 Vitest、React Testing Library 与 MSW（模拟 Tauri 调用）覆盖 Hook、组件和界面流程。
- Backend: Cargo tests validate MCP 服务器规范、技能元数据处理、Provider 切换与删除逻辑。/ 后端 Cargo 测试覆盖 MCP 校验、技能解析、Provider 切换/删除。
- API Bash: bash + curl + jq 直连 Axum REST API，按固定夹具验证 Provider/MCP/Settings/Usage 端点及持久化流程。/ Bash 测试用 curl/jq 直接打 REST API，带夹具数据。

## 2. Test Locations / 测试位置

### Rust Backend Tests / Rust 后端测试
| 位置 | 说明 |
|------|------|
| src-tauri/src/mcp.rs (底部 #[cfg(test)]) | MCP 验证和转换测试 |
| src-tauri/src/services/skill.rs (底部 #[cfg(test)]) | Skills 路径和解析测试 |
| src-tauri/tests/provider_service.rs | Provider 服务集成测试 |
| src-tauri/tests/support.rs | HOME 隔离与文件清理工具，供集成测试复用 |

### Frontend Tests / 前端测试
| 位置 | 说明 |
|------|------|
| tests/hooks/ | React Hooks 测试 |
| tests/components/ | 组件测试 |
| tests/lib/ | 工具库测试 |
| tests/config/ | 配置与映射测试 |
| tests/integration/ | 前端集成测试 (App / SettingsDialog) |
| tests/msw/ | MSW 处理器、Tauri/HTTP 模拟 |

### API Bash Tests / API Bash 测试
| 位置 | 说明 |
|------|------|
| tests/api/ | REST API 测试脚本 |
| tests/integration/test-full-workflow.sh | Provider 端到端 Bash 流程 |
| tests/integration/test-persistence.sh | 导入/导出持久化校验 Bash 流程 |

辅助/夹具：
- tests/helpers/common.sh & helpers/test-data.json – Bash 断言、HTTP 包装与测试数据。/ Bash 公用函数与夹具。
- tests/run-all.sh – Bash 测试编排脚本。/ 统一执行入口。
- tests/setupTests.ts、tests/utils/testQueryClient.ts – Vitest 全局初始化与 QueryClient 工具。/ 前端测试基建。

## 3. Running Tests / 运行测试
- Frontend / 前端：`pnpm install` 后运行 `pnpm test:unit`（全部），或 `pnpm test:unit -- tests/hooks/useSkills.test.tsx`（单文件），`pnpm test:unit:watch`（监听）。JS 环境依赖 jsdom 与 MSW，无需真实后端。  
- Backend / 后端：`cd src-tauri && cargo test` 运行全部；仅跑文件可用 `cargo test --lib mcp::tests` 或 `cargo test --test provider_service`。测试会把 `HOME`/`USERPROFILE` 指向临时目录，避免污染真实配置。  
- API Bash：`bash tests/run-all.sh` 跑完所有脚本；单个用 `HOST=localhost PORT=8080 USERNAME=admin PASSWORD=test bash tests/api/test-providers.sh`。可通过 `SCHEME`/`API_PREFIX`/`API_BASE`/`REQUEST_TIMEOUT`/`TEST_DATA_FILE` 覆盖默认。  
- Mixed / 组合：需要真实运行中的 Axum Web Server（启用 `web-server` feature），确保 `curl`、`jq`、`bash` 可用；如离线，将 `tests/helpers/test-data.json` 中 `usageScripts.baseUrl` 改为内网回声地址。

## 4. Test File Details / 测试文件详情

**Rust backend / Rust 后端**
- src-tauri/src/mcp.rs – validate MCP server specs (stdio/http/sse), required fields, JSON→TOML 转换断言。
- src-tauri/src/services/skill.rs – 归一化技能路径、SKILL.md 元数据解析、技能去重等逻辑。
- src-tauri/tests/provider_service.rs – Provider 切换/删除集成：同步 live 配置、PackyCode/Google 安全模式、错误分支与文件删除。
- src-tauri/tests/support.rs – HOME 隔离、文件清理、全局互斥，供集成测试共用。

**Frontend hooks / 前端 Hooks**
- tests/hooks/useSkills.test.tsx – 拉取/安装/卸载技能、查询失效处理与缓存失效。
- tests/hooks/useSettingsForm.test.tsx – 设置归一化、语言同步、本地存储优先级与重置逻辑。
- tests/hooks/useProviderActions.test.tsx – Provider 增删改查、切换时托盘与插件同步、用量脚本保存、错误提示与加载状态。
- tests/hooks/useMcpValidation.test.tsx – MCP JSON/TOML 校验、错误格式化与必填项校验。
- tests/hooks/useSettings.test.tsx – 保存/重置设置、目录覆盖、Claude 插件同步、重启标记与错误分支。
- tests/hooks/useSettingsMetadata.test.tsx – 便携模式探测、重启标记读写。
- tests/hooks/useImportExport.test.tsx – 配置导入/导出主流程、Toast 提示、状态重置。
- tests/hooks/useImportExport.extra.test.tsx – 导入文件缺失/失败、导出路径提示等边界场景。
- tests/hooks/useDragSort.test.tsx – Provider 拖拽排序、API 调用、错误提示与无目标分支。
- tests/hooks/useDirectorySettings.test.tsx – 配置目录选择/重置、默认目录推导与错误告警。

**Frontend components / 前端组件**
- tests/components/SettingsDialog.test.tsx – 设置弹窗渲染、Tab 切换、导入导出交互、保存/取消流程与重启提醒。
- tests/components/McpFormModal.test.tsx – MCP 预设/向导、JSON/TOML 模式校验、编辑/新增/无应用保存与失败提示。
- tests/components/ImportExportSection.test.tsx – 导入导出区块的禁用态、成功/失败/导入中 UI。
- tests/components/ProviderList.test.tsx – Provider 卡片排序、空态创建、拖拽属性与动作回调。
- tests/components/AddProviderDialog.test.tsx – Provider 新增提交，处理自定义端点/基准 URL 回退。

**Frontend integration / 前端集成**
- tests/integration/SettingsDialog.test.tsx – MSW 真实数据流：加载默认设置、导入成功回调、保存后的重启提示、目录浏览与重置。
- tests/integration/App.test.tsx – MSW 驱动的 App 端到端：切换应用、增删改 Provider、用量脚本弹窗、导入配置、拖拽复制与事件推送。

**Frontend lib/config/utils / 前端库与配置**
- tests/lib/healthCheck.test.ts – RelayPulse 健康检查映射、可用性计算、缓存与合并策略。
- tests/config/healthCheckMapping.test.ts – Provider 名称/URL 映射到监控源、监控判定。
- tests/utils/providerMetaUtils.test.ts – ProviderMeta 合并、端点覆盖/移除规则。
- tests/utils/testQueryClient.ts – 无重试的测试专用 QueryClient 工厂。

**API Bash scripts / API Bash 脚本**
- tests/api/test-auth.sh – 基础认证 401/200 覆盖。
- tests/api/test-providers.sh – Provider CRUD、切换、恢复原始 Provider。
- tests/api/test-usage.sh – 保存的用量脚本查询、PackyCode/88code/Privnode 测试端点、错误分支。
- tests/api/test-settings.sh – Settings 拉取/更新/恢复。
- tests/api/test-mcp.sh – MCP 服务器增删改查。
- tests/integration/test-full-workflow.sh – Provider 添加→切换→更新→删除端到端流程。
- tests/integration/test-persistence.sh – 导出快照、恢复配置后比对基线。
- tests/helpers/common.sh – curl 包装、断言、配置备份/恢复、彩色输出、ID 生成。
- tests/helpers/test-data.json – Provider/MCP/Settings/Usage 夹具数据与可覆盖的 baseUrl。
- tests/run-all.sh – 依序执行 Bash 脚本，支持自定义列表。

**MSW & setup / MSW 与前置**
- tests/msw/state.ts – 模拟 Provider/Settings/MCP/Skills 状态及变更器。
- tests/msw/handlers.ts – 拦截 Tauri HTTP/事件 API、目录/文件对话框、健康检查请求。
- tests/msw/server.ts – 注册所有 MSW 处理器。
- tests/msw/tauriMocks.ts – 模拟 Tauri invoke/event/path，提供 emitTauriEvent 触发器。
- tests/setupTests.ts – Vitest 全局初始化、i18n/cleanup、MSW 启停与 HOME/路径 mock。

## 5. Cross-Platform Notes / 跨平台注意事项
- Rust 测试自动将 `HOME`（Windows 同步 `USERPROFILE`）指向临时目录，避免写入真实 `~/.claude`、`~/.codex` 等。/ Rust 测试会隔离用户目录。
- 前端测试运行在 jsdom，依赖 MSW，无需真实网络；若使用 Node 18+ 均可。/ 前端在 jsdom 下可跨平台运行。
- Bash 脚本需要类 Unix 环境（bash/curl/jq）；Windows 建议 WSL 或 Git Bash。/ Bash 测试需类 Unix 环境。
- Usage 脚本默认调用 `https://postman-echo.com`，离线可修改 `tests/helpers/test-data.json` 或通过 `TEST_DATA_FILE` 提供自定义夹具。/ 离线可自定义回声地址。

## 6. Adding New Tests / 添加新测试指南
- 前端：在对应目录新增 `.test.tsx`，复用 `tests/setupTests.ts` 中的全局设置，如需新接口请在 `tests/msw/handlers.ts` 增加处理并更新 `tests/msw/state.ts`。/ 添加新 MSW handler 支持新接口。
- 后端：新功能放入相关模块并用 `#[cfg(test)]` 或 `tests/` 集成测试，复用 `src-tauri/tests/support.rs` 隔离 HOME。/ 后端测试请使用 support 工具。
- Bash：脚本放入 `tests/api` 或 `tests/integration`，引用 `helpers/common.sh`，使用 `read_fixture` 取敏感数据，最后把路径加入 `tests/run-all.sh`。/ Bash 脚本记得登记到 run-all。
- 夹具：更新或复制 `tests/helpers/test-data.json`，通过 `TEST_DATA_FILE` 覆盖，保持不把真实密钥写入仓库。/ 夹具里不要放真实密钥。
- 命名/稳健性：优先无状态可重放设计，必要时用 `backup_config`/`restore_config` 或查询缓存失效确保幂等。/ 测试应可重复执行。
