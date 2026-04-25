#!/bin/bash
# ============================================================
# 服务器 B 部署脚本（110.40.177.238 | 2核4G | 上海）
# Milvus（etcd + MinIO + Standalone）+ Redis
# ============================================================

set -e

DEPLOY_DIR="/usr/service"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$DEPLOY_DIR/server-B"

echo "============================================"
echo " 服务器 B：向量库 + 缓存部署"
echo "============================================"

# 1. 环境检查
command -v docker &>/dev/null || { echo "❌ 请先安装 Docker"; exit 1; }
docker compose version &>/dev/null || { echo "❌ 需要 Docker Compose 插件"; exit 1; }

# 2. 创建目录 & 复制文件
mkdir -p "$SERVER_DIR/data/etcd"
mkdir -p "$SERVER_DIR/data/minio"
mkdir -p "$SERVER_DIR/data/milvus"
mkdir -p "$SERVER_DIR/data/redis"
mkdir -p "$SERVER_DIR/conf"
cp docker-compose.yml "$SERVER_DIR/"
cp redis.conf "$SERVER_DIR/conf/"
cd "$SERVER_DIR"

# 3. 停止旧服务
docker compose down --remove-orphans 2>/dev/null || true

# 4. 释放系统缓存（2C4G 专用）
echo "🧹 释放系统缓存..."
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

# 5. 启动服务
echo "⏳ 启动 Milvus（etcd + MinIO + Standalone）+ Redis..."
docker compose up -d

# 6. 等待 Milvus 就绪（最长 150 秒）
echo "⏳ 等待 Milvus 初始化..."
count=0
while [ $count -lt 30 ]; do
  status=$(docker inspect --format='{{.State.Health.Status}}' milvus-standalone 2>/dev/null)
  if [ "$status" == "healthy" ]; then
    echo "✅ Milvus 就绪！"
    break
  fi
  echo -n "."
  sleep 5
  ((count++))
done

if [ $count -ge 30 ]; then
  echo "⚠️  Milvus 启动超时，请检查日志: docker logs milvus-standalone"
fi

echo ""
echo "============================================"
echo " ✅ 服务器 B 部署完成！"
echo "    Milvus gRPC:  http://110.40.177.238:19530"
echo "    Milvus 健康:  http://110.40.177.238:9091"
echo "    MinIO 控制台: http://110.40.177.238:9001"
echo "    Redis:        110.40.177.238:6379"
echo "============================================"
