#!/bin/bash
# ============================================================
# 服务器 C 部署脚本（8.140.221.150 | 2核4G | 北京）
# Nginx（反向代理 + 前端）+ Jaeger（链路追踪）
# ============================================================

set -e

DEPLOY_DIR="/usr/service"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$DEPLOY_DIR/server-C"

echo "============================================"
echo " 服务器 C：流量入口 + 监控部署"
echo "============================================"

# 1. 环境检查
command -v docker &>/dev/null || { echo "❌ 请先安装 Docker"; exit 1; }
docker compose version &>/dev/null || { echo "❌ 需要 Docker Compose 插件"; exit 1; }

# 2. 创建目录 & 复制文件
mkdir -p "$SERVER_DIR/data/web-ui"
cp docker-compose.yml "$SERVER_DIR/"
cp nginx.conf "$SERVER_DIR/"
cd "$SERVER_DIR"

# 3. 停止旧服务
docker compose down --remove-orphans 2>/dev/null || true

# 4. 启动服务
echo "⏳ 启动 Nginx + Jaeger..."
docker compose up -d

# 5. 验证
sleep 3

echo ""
echo "============================================"
echo " ✅ 服务器 C 部署完成！"
echo "    前端入口:     http://8.140.221.150"
echo "    Jaeger 大屏:  http://8.140.221.150:16686"
echo ""
echo " 📌 使用前注意："
echo "    1. 将 Vue 前端构建产物放到 data/web-ui/ 目录"
echo "    2. 用 sftp/scp 上传: scp -r dist/* root@8.140.221.150:$SERVER_DIR/data/web-ui/"
echo "    3. 前端 API 请求会自动代理到 124.223.22.34:8080"
echo "============================================"
