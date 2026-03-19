#!/bin/bash

# 1. 定义部署目录
DEPLOY_DIR="/home/admin/milvus"
mkdir -p $DEPLOY_DIR/volumes/etcd
mkdir -p $DEPLOY_DIR/volumes/minio
mkdir -p $DEPLOY_DIR/volumes/milvus
cd $DEPLOY_DIR

echo ">>> [1/4] 正在清理旧的容器与隐形缓存..."
docker compose down > /dev/null 2>&1
# 释放磁盘和部分因挂载点残留占用的内存
docker system prune -f

echo ">>> [2/4] 正在检查物理内存状态..."
# 针对 4G 环境，启动前先强制释放一次系统缓存
sync && echo 3 > /proc/sys/vm/drop_caches
free -h

echo ">>> [3/4] 启动 Milvus 2.6.0 (资源受限优化版)..."
docker compose up -d

echo ">>> [4/4] 等待服务初始化 (约 60s)..."
count=0
while true; do
    status=$(docker inspect --format='{{.State.Health.Status}}' milvus-standalone 2>/dev/null)
    if [ "$status" == "healthy" ]; then
        echo "✅ Milvus 启动成功！"
        break
    fi
    if [ $count -gt 30 ]; then
        echo "❌ 启动超时，请执行 'docker logs milvus-standalone' 查看详情。"
        exit 1
    fi
    echo -n "."
    sleep 5
    ((count++))
done

echo "=========================================="
echo "服务状态摘要："
docker stats --no-stream milvus-standalone milvus-minio milvus-etcd
echo "=========================================="