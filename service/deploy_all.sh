#!/bin/bash

# =====================================================================
# 项目全自动化部署脚本 (Vue 3 + Java 21 + Docker Compose)
# 运行环境：阿里云 ECS (建议 512MB 内存限制配置)
# =====================================================================

# --- 1. 环境准备与变量加载 ---
set -e # 遇到错误立即停止
source /etc/environment # 加载 CLOUD_IP, OPENAI_API_KEY 等

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🚀 [$(date +'%Y-%m-%d %H:%M:%S')] 启动全栈部署任务...${NC}"

# 定义路径 (请根据实际目录调整)
UI_PATH="/usr/servise/web-ui"
BACKEND_PATH="/usr/servise/spring-ai-rag"

# --- 2. 同步后端代码 (Java 21) ---
echo -e "${YELLOW}📦 正在同步后端代码: $BACKEND_PATH...${NC}"
cd $BACKEND_PATH
git fetch --all
git reset --hard origin/main
git pull origin main

# --- 3. 同步前端代码 (Vue 3) ---
echo -e "${YELLOW}📦 正在同步前端代码: $UI_PATH...${NC}"
cd $UI_PATH
git fetch --all
git reset --hard origin/main
git pull origin main

chmod -R 777 $BACKEND_PATH
chmod -R 777 $UI_PATH

# --- 4. 执行 Docker Compose 重启 ---
echo -e "${YELLOW}🔄 正在通过 Docker Compose 重启所有服务...${NC}"

# 停止旧服务
docker compose down

# 强制重新构建并启动
# 这里会读取 Dockerfile 中的多阶段构建逻辑
docker compose up -d --build --force-recreate

# --- 5. 状态验证 ---
echo -e "${YELLOW}🔍 正在验证服务存活状态...${NC}"
sleep 5 # 等待 Java 启动

# 检查前端
UI_STATUS=$(docker inspect -f '{{.State.Running}}' web-ui-app 2>/dev/null || echo "false")
# 检查后端
BE_STATUS=$(docker inspect -f '{{.State.Running}}' ai-rag-backend 2>/dev/null || echo "false")

if [ "$UI_STATUS" == "true" ] && [ "$BE_STATUS" == "true" ]; then
    echo -e "${GREEN}✅ 部署成功！前后端服务均已正常运行。${NC}"
else
    echo -e "${RED}❌ 部署异常: 请检查日志。${NC}"
    [ "$UI_STATUS" != "true" ] && echo -e "${RED}- 前端容器未启动${NC}"
    [ "$BE_STATUS" != "true" ] && echo -e "${RED}- 后端容器未启动${NC}"
    exit 1
fi

# --- 6. 内存与磁盘清理 ---
echo -e "${YELLOW}🧹 正在清理构建缓存与过期镜像...${NC}"
docker image prune -f

echo -e "${GREEN}===============================================================${NC}"
echo -e "${GREEN}🎉 部署完成！${NC}"
echo -e "📱 前端地址: ${YELLOW}http://你的公网IP (80)${NC}"
echo -e "⚙️  后端变量: CLOUD_IP=${CLOUD_IP}${NC}"
echo -e "🧠 内存统计: $(free -h | grep Mem | awk '{print $3 "/" $2}') 已用/总量${NC}"
echo -e "${GREEN}===============================================================${NC}"