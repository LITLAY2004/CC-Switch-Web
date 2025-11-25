# CC-Switch Web 快速访问指南

> 模板示例（请替换为你的服务器信息，不要提交真实 IP/密码）

## ⚠️ 重要安全说明

**CC-Switch Web 服务器已启用安全保护：**

1. ✅ **仅监听本地回环地址** (`127.0.0.1`)
   - 外网完全无法访问，即使配置云安全组也无效
   - 必须通过 SSH 隧道访问

2. ✅ **HTTP Basic Auth 密码保护**
   - 每台服务器首次启动时自动生成独立的 16 位随机密码
   - 密码存储在 `~/.cc-switch/web_password`（权限 600）
   - 访问时需要输入用户名（admin）和密码

3. ✅ **双重保护机制**
   - 网络层：只能从本地访问
   - 应用层：需要密码认证
   - 确保 API 密钥不会泄露

---

## 🔑 查看登录密码

启动服务器时会在终端显示密码，或手动查看：

```bash
cat ~/.cc-switch/web_password
```

当前密码：请查看 `~/.cc-switch/web_password`（首次启动自动生成）

---

## 方法 1: SSH 端口转发（唯一访问方式）

### A. 在已有 SSH 连接中添加转发

如果你已经通过 SSH 连接到服务器：

1. 按 `Enter` 键
2. 输入 `~C` (波浪号 + 大写C)
3. 看到 `ssh>` 提示符后，输入：`-L 3000:localhost:8080`
4. 按 `Enter`
5. 浏览器访问：`http://localhost:3000`

### B. 重新建立 SSH 连接（带端口转发）

```bash
# 退出当前 SSH
exit

# 重新连接（带端口转发）
ssh -L 3000:localhost:8080 user@your-server

# 或者转发到本地 8080 端口
ssh -L 8080:localhost:8080 user@your-server
```

然后浏览器访问：
- `http://localhost:3000` (第一种)
- `http://localhost:8080` (第二种)

**登录凭证：**
- 用户名：`admin`
- 密码：查看 `~/.cc-switch/web_password`

---

## 方法 2: 在服务器本地测试

如果你在服务器的 SSH 终端内：

```bash
# 安装文本浏览器（可选）
apt-get install -y lynx

# 测试访问
curl http://localhost:8080/
lynx http://localhost:8080/
```

---

## 快速测试 API

**注意：所有 API 请求都需要 Basic Auth 认证**

```bash
# 获取密码
PASSWORD=$(cat ~/.cc-switch/web_password)

# 测试 Provider API
curl -u admin:$PASSWORD http://localhost:8080/api/providers/claude

# 测试 Settings API
curl -u admin:$PASSWORD http://localhost:8080/api/settings

# 测试 MCP API
curl -u admin:$PASSWORD http://localhost:8080/api/mcp/servers

# 或直接使用密码
curl -u admin:c3UEBlNq39biO9Ot http://localhost:8080/api/settings
```

---

## 服务器管理命令

### 查看服务状态
```bash
ps aux | grep cc-switch-server
netstat -tulpn | grep 8080
```

### 停止服务
```bash
pkill cc-switch-server
```

### 启动服务（前台）
```bash
cd /root/cc-switch/src-tauri
./target/debug/cc-switch-server
```

### 启动服务（后台）
```bash
cd /root/cc-switch/src-tauri
nohup ./target/debug/cc-switch-server > /var/log/cc-switch.log 2>&1 &
```

### 自定义端口
```bash
PORT=3000 ./target/debug/cc-switch-server
```

### 查看日志
```bash
tail -f /var/log/cc-switch.log
```

---

## 故障排查

### 端口被占用
```bash
# 查找占用 8080 端口的进程
lsof -i:8080
netstat -tulpn | grep 8080

# 杀死进程
kill -9 <PID>
```

### 防火墙问题
```bash
# 检查防火墙状态
ufw status
iptables -L -n

# 临时开放端口（如果使用 ufw）
ufw allow 8080/tcp
```

### 服务无响应
```bash
# 检查进程是否运行
ps aux | grep cc-switch

# 重启服务
pkill cc-switch-server
./target/debug/cc-switch-server
```

---

## 🛡️ 安全特性总结

### 为什么这样设计？

1. **防止 API 密钥泄露**
   - Claude/Codex/Gemini API 密钥非常敏感
   - 服务器只监听 127.0.0.1，外网无法访问
   - 即使端口冲突顺延（8081/8082），依然安全

2. **每台服务器独立密码**
   - 首次启动自动生成随机密码
   - 未来开源后，每个用户部署都有自己的密码
   - 密码文件权限 600，只有服务器所有者可读

3. **双重保护**
   - 网络层：必须通过 SSH 隧道访问
   - 应用层：必须输入 Basic Auth 密码
   - 保护级别：军事级加密（SSH）+ 密码认证

### 适用场景

| 场景 | 适用性 | 说明 |
|------|--------|------|
| 个人云服务器 | ✅ 完美 | SSH 隧道简单安全 |
| 多人协作 | ✅ 可行 | 共享 SSH 密钥或设置多个用户 |
| 公开服务 | ❌ 不适用 | 设计目标是个人使用，不适合暴露在公网 |

---

## 🎯 推荐使用方式

**最佳实践：**
1. 启动服务器（自动生成密码）
2. 建立 SSH 隧道：`ssh -L 3000:localhost:8080 root@49.235.180.6`
3. 浏览器访问：`http://localhost:3000`
4. 输入用户名 `admin` 和密码（查看 `~/.cc-switch/web_password`）
5. 享受安全的可视化管理

**端口冲突处理：**
- 如果 8080 被占用，服务器会失败并提示
- 手动指定其他端口：`PORT=8081 ./target/debug/cc-switch-server`
- 即使使用其他端口，依然只监听 127.0.0.1，外网无法访问
