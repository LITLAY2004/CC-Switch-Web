#!/usr/bin/env bash
# CC-Switch Web Server 一键部署脚本
# Usage: curl -fsSL https://raw.githubusercontent.com/LITLAY2004/CC-Switch-Web/main/scripts/deploy-web.sh | bash
#
# 环境变量：
#   HOST      - 监听地址，默认 0.0.0.0
#   PORT      - 监听端口，默认 3000
#   INSTALL_DIR - 安装目录，默认 ~/cc-switch-web

set -euo pipefail

# 颜色输出
log() { printf '\033[1;34m[CC-Switch]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[CC-Switch]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[CC-Switch]\033[0m %s\n' "$*" >&2; }
success() { printf '\033[1;32m[CC-Switch]\033[0m %s\n' "$*"; }

# 配置
REPO_URL="${REPO_URL:-https://github.com/LITLAY2004/CC-Switch-Web.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/cc-switch-web}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-3000}"

# 检查命令是否存在
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

# 检查并安装依赖
check_dependencies() {
  log "检查系统依赖..."

  local missing=()

  # 检查 Git
  if ! need_cmd git; then
    missing+=("git")
  fi

  # 检查 Node.js
  if ! need_cmd node; then
    missing+=("nodejs")
  else
    local node_version
    node_version=$(node -v | sed 's/v//' | cut -d. -f1)
    if [[ "$node_version" -lt 18 ]]; then
      warn "Node.js 版本过低 (需要 >= 18)，当前: $(node -v)"
      missing+=("nodejs>=18")
    fi
  fi

  # 检查 pnpm
  if ! need_cmd pnpm; then
    log "安装 pnpm..."
    npm install -g pnpm || {
      err "pnpm 安装失败，请手动安装: npm install -g pnpm"
      exit 1
    }
  fi

  # 检查 Rust/Cargo
  if ! need_cmd cargo; then
    missing+=("rust/cargo")
  fi

  # 检查 curl
  if ! need_cmd curl; then
    missing+=("curl")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    err "缺少以下依赖: ${missing[*]}"
    echo ""
    echo "请先安装缺失的依赖："
    echo "  - Git: sudo apt install git"
    echo "  - Node.js 18+: https://nodejs.org/ 或 nvm install 20"
    echo "  - Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo "  - curl: sudo apt install curl"
    exit 1
  fi

  success "依赖检查通过"
}

# 安装 Linux 系统依赖（用于编译 Tauri）
install_linux_deps() {
  if [[ "$(uname)" != "Linux" ]]; then
    return 0
  fi

  log "检查 Linux 编译依赖..."

  # 检测包管理器
  if need_cmd apt-get; then
    # Debian/Ubuntu
    local packages=(
      build-essential
      pkg-config
      libssl-dev
      libgtk-3-dev
      librsvg2-dev
      libwebkit2gtk-4.1-dev
    )

    local to_install=()
    for pkg in "${packages[@]}"; do
      if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        to_install+=("$pkg")
      fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
      log "安装编译依赖: ${to_install[*]}"
      sudo apt-get update
      sudo apt-get install -y "${to_install[@]}" || {
        # 尝试 webkit2gtk-4.0 作为备选
        sudo apt-get install -y libwebkit2gtk-4.0-dev 2>/dev/null || true
      }
    fi
  elif need_cmd dnf; then
    # Fedora/RHEL
    sudo dnf install -y \
      gcc gcc-c++ \
      openssl-devel \
      gtk3-devel \
      librsvg2-devel \
      webkit2gtk4.1-devel \
      || sudo dnf install -y webkit2gtk3-devel 2>/dev/null || true
  elif need_cmd pacman; then
    # Arch Linux
    sudo pacman -S --needed --noconfirm \
      base-devel \
      openssl \
      gtk3 \
      librsvg \
      webkit2gtk-4.1 \
      || sudo pacman -S --needed --noconfirm webkit2gtk 2>/dev/null || true
  fi

  success "Linux 编译依赖就绪"
}

# 克隆或更新仓库
clone_or_update() {
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    log "更新已有仓库..."
    cd "$INSTALL_DIR"
    git fetch origin
    git reset --hard origin/main
  else
    log "克隆仓库到 $INSTALL_DIR..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
  fi
  success "代码就绪"
}

# 构建前端
build_frontend() {
  log "安装前端依赖..."
  pnpm install --frozen-lockfile || pnpm install

  log "构建 Web 资源..."
  pnpm build:web

  success "前端构建完成"
}

# 构建后端
build_backend() {
  log "构建 Rust Web 服务器..."
  cd src-tauri
  cargo build --release --features web-server --example server
  cd ..

  success "后端构建完成"
}

# 创建 systemd 服务（可选）
create_systemd_service() {
  if [[ "${CREATE_SERVICE:-0}" != "1" ]]; then
    return 0
  fi

  log "创建 systemd 服务..."

  local service_file="/etc/systemd/system/cc-switch-web.service"
  local server_path="$INSTALL_DIR/src-tauri/target/release/examples/server"

  sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=CC-Switch Web Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
Environment=HOST=$HOST
Environment=PORT=$PORT
ExecStart=$server_path
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable cc-switch-web

  success "systemd 服务已创建: cc-switch-web"
}

# 显示完成信息
show_completion() {
  local server_path="$INSTALL_DIR/src-tauri/target/release/examples/server"
  local password_file="$HOME/.cc-switch/web_password"

  echo ""
  success "=========================================="
  success "  CC-Switch Web 服务器部署完成！"
  success "=========================================="
  echo ""
  echo "启动服务器："
  echo "  cd $INSTALL_DIR"
  echo "  HOST=$HOST PORT=$PORT $server_path"
  echo ""
  echo "或使用快捷命令："
  echo "  $INSTALL_DIR/scripts/start-web.sh"
  echo ""
  echo "访问地址："
  echo "  http://$HOST:$PORT"
  echo ""
  echo "登录凭据："
  echo "  用户名: admin"
  echo "  密码: 首次启动后查看 $password_file"
  echo ""
  if [[ "${CREATE_SERVICE:-0}" == "1" ]]; then
    echo "systemd 服务管理："
    echo "  sudo systemctl start cc-switch-web   # 启动"
    echo "  sudo systemctl stop cc-switch-web    # 停止"
    echo "  sudo systemctl status cc-switch-web  # 状态"
    echo ""
  fi
  echo "如需创建 systemd 服务，运行："
  echo "  CREATE_SERVICE=1 $0"
  echo ""
}

# 创建启动脚本
create_start_script() {
  local start_script="$INSTALL_DIR/scripts/start-web.sh"

  cat > "$start_script" <<EOF
#!/usr/bin/env bash
# CC-Switch Web 服务器启动脚本

cd "\$(dirname "\$0")/.."
HOST="\${HOST:-$HOST}" PORT="\${PORT:-$PORT}" ./src-tauri/target/release/examples/server
EOF

  chmod +x "$start_script"
  log "创建启动脚本: $start_script"
}

# 主函数
main() {
  echo ""
  log "CC-Switch Web 服务器一键部署"
  log "=============================="
  echo ""

  check_dependencies
  install_linux_deps
  clone_or_update
  build_frontend
  build_backend
  create_start_script
  create_systemd_service
  show_completion
}

main "$@"
