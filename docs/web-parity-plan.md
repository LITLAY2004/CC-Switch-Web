# CC-Switch Web 端整改方案与验收清单

## 背景与目标
Web Server 模式目前存在多处 404 / 无效功能（提示词、技能、MCP 应用开关、目录选择、外链打开等）。目标是补齐前后端契约或在 Web 模式下优雅降级，确保主要功能可用、不可用功能有明确提示，并改善开发体验（端口冲突）。

## 待解决问题概览
- 后端路由缺失：提示词、技能、MCP 应用启用/禁用、目录选择/路径获取、外链打开等 API 在 web-api 中未暴露（仅 providers/MCP CRUD/settings/config 导入导出）。
- 前端调用直接落到缺失 API：`settingsApi.openExternal`、prompt/skill/MCP toggle、目录浏览等在 Web 端触发 fetch 404。
- 开发端口冲突：`vite.config.web.mts` 使用 3000（strict），与 cc-switch-server 默认端口一致，导致请求打到错误服务。

## 解决方案规划

### 1) 后端 API 补齐（Axum 路由）
- **提示词**：新增 `/api/prompts/:app` CRUD 路由及当前文件内容获取，复用现有服务层；保持与 Tauri IPC 同名命令。
- **技能**：新增 `/api/skills` 列表/安装/卸载 与 `/api/skills/repos` 管理路由，封装调用现有服务。
- **MCP 应用开关**：新增 `/api/mcp/servers/:id/apps/:app` POST，用于启用/禁用特定客户端。
- **目录/路径**：新增 `/api/config/:app/dir` 读取、`/api/config/:app/open` 打开目录（可在 Web 返回 noop）、`/api/fs/pick-directory` 返回 501 或安全替代；`/api/config/app/override` GET/PUT。
- **外链打开**：新增 `/api/system/open-external`，但实际 Web 端应只回传错误提示，推荐前端改为 `window.open`。
- **通用配置片段**：新增 `/api/config/:app/common-snippet` GET/PUT，保持与现有调用一致。

### 2) 前端行为调整
- **外链打开**：`settingsApi.openExternal` 在 Web 模式直接 `window.open(url, "_blank", "noopener")`，不走后端；失败时 toast 友好提示。
- **不可用能力的降级**：在 Web 模式下隐藏或禁用“选择目录/打开目录”按钮，并用气泡提示“云端暂不可用”；若后端返回 501，也要提示而非报错。
- **MCP 应用开关**：在后端补齐前可禁用切换并提示“Web 版暂不支持”；补齐后保留错误提示。
- **提示词/技能**：确保 fetch 失败时给出可读错误并不阻塞其他功能；后端补齐后移除兜底。

### 3) 开发体验
- 调整 Web Vite 开发端口（如 4173）并添加 `/api` 代理到 cc-switch-server，避免端口冲突。
- 在 README/WEB_SERVER_GUIDE 增加“dev:web 端口 & proxy”说明。

## 验收清单
- [ ] Web 前端主要按钮不再触发 404：提示词 CRUD、技能列表/安装/卸载、MCP 应用开关、目录相关请求均有有效响应或明确的 501 提示。
- [ ] Web 端打开官网/文档时在浏览器新标签页正常打开，不依赖服务器打开系统浏览器。
- [ ] 目录选择/打开在 Web 端要么被隐藏/禁用，要么提示“服务器模式不支持”，不会抛未捕获错误。
- [ ] MCP 开关操作有对应 REST 路由并能成功持久化（或明确禁用说明）。
- [ ] Web 开发模式默认端口不与 cc-switch-server 冲突，请求能通过代理正确命中 `/api`。
- [ ] 文档更新：新增/修改的 API、限制说明、开发启动步骤在 README/WEB_SERVER_GUIDE 可查。
