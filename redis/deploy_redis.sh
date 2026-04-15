#!/bin/bash

# --- 配置区 ---
REPO_URL="<您的代码仓地址>"             # 替换为您的 Git 仓库地址
PROJECT_DIR="$HOME/service/redis"      # 部署的目标目录

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- 核心函数 ---

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

# 1. 检查环境依赖
check_env() {
    if ! command -v docker &> /dev/null; then
        err "未检测到 Docker，请先运行之前的安装脚本！"
        exit 1
    fi
    if ! docker compose version &> /dev/null; then
        err "未检测到 Docker Compose 插件！"
        exit 1
    fi
}

# 2. 同步代码仓
sync_code() {
    if [ ! -d "$PROJECT_DIR/.git" ]; then
        log "首次部署，正在克隆仓库..."
        git clone "$REPO_URL" "$PROJECT_DIR"
    else
        log "目录已存在，正在拉取最新代码..."
        cd "$PROJECT_DIR" && git pull
    fi
    cd "$PROJECT_DIR"
}

# 3. 部署/重启服务
deploy() {
    log "正在启动 Redis 服务 (基于 Docker Compose)..."
    # --remove-orphans 清理过期的容器
    docker compose up -d --remove-orphans
    
    if [ $? -eq 0 ]; then
        log "服务已在后台运行！"
    else
        err "部署失败，请检查 docker-compose.yml 语法"
        exit 1
    fi
}

# 4. 强制重启
restart() {
    log "正在重新启动 Redis 服务..."
    cd "$PROJECT_DIR" && docker compose restart
}

# 5. 查看状态
status() {
    log "当前 Redis 容器状态："
    cd "$PROJECT_DIR" && docker compose ps
    echo -e "\n${YELLOW}Redis 实时日志 (最近10行):${NC}"
    docker compose logs --tail=10
}

# --- 菜单逻辑 ---

case "$1" in
    deploy)
        check_env
#        sync_code
        deploy
        status
        ;;
    restart)
        restart
        status
        ;;
    stop)
        log "正在停止服务..."
        cd "$PROJECT_DIR" && docker compose down
        ;;
    status)
        status
        ;;
    update)
        log "正在更新代码并滚动升级..."
#        sync_code
        deploy
        ;;
    *)
        echo -e "${YELLOW}使用方法:${NC}"
        echo "  $0 deploy  - [首次/覆盖] 拉取代码并启动部署"
        echo "  $0 update  - 拉取最新代码并滚动更新容器"
        echo "  $0 restart - 仅执行容器重启"
        echo "  $0 stop    - 停止并移除容器"
        echo "  $0 status  - 查看运行状态和日志"
        exit 1
        ;;
esac