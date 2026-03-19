#!/bin/bash

# =====================================================================
# 项目自动化部署脚本 (专业增强版 - 含强制重启逻辑)
# 适用环境：Vue (Vite) + Docker Compose + 阿里云 ECS
# =====================================================================

# --- 1. 配置参数 ---
PROJECT_PATH="/usr/servise/web-ui"
CONTAINER_NAME="web-ui-app"  # 对应 docker-compose.yml 中的 container_name
BRANCH="main"

# 设置颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 [$(date +'%Y-%m-%d %H:%M:%S')] 启动部署任务...${NC}"

# --- 2. 环境检查 ---
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}❌ 错误: 找不到项目目录 $PROJECT_PATH${NC}"
    exit 1
fi

cd $PROJECT_PATH || exit

# --- 3. 代码强行同步 ---
echo -e "${YELLOW}📥 正在强制从 GitHub 同步代码 (分支: $BRANCH)...${NC}"
git fetch --all
# 放弃本地所有修改，强制对齐远程仓库，解决 Git 冲突
git reset --hard origin/$BRANCH

# --- 4. 彻底重启逻辑 ---
echo -e "${YELLOW}🔄 正在执行重启逻辑...${NC}"

# 步骤 A: 停止并删除旧容器及网络（确保环境干净）
echo "   - 停止旧服务..."
docker compose down

# 步骤 B: 重新构建镜像并启动（后台运行）
# --build: 即使代码没变，也强制检查构建缓存并应用 Dockerfile 修改
# --force-recreate: 强制重新创建容器
echo "   - 重新构建镜像并启动容器..."
docker compose up -d --build --force-recreate

# --- 5. 部署后验证 ---
echo -e "${YELLOW}🔍 正在验证服务状态...${NC}"
sleep 3 # 给容器 3 秒启动时间

# 检查容器是否正在运行
STATUS=$(docker inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)

if [ "$STATUS" == "true" ]; then
    echo -e "${GREEN}✅ 部署成功！容器 $CONTAINER_NAME 运行正常。${NC}"
else
    echo -e "${RED}❌ 部署失败: 容器未能正常启动。${NC}"
    echo -e "${YELLOW}--- 错误日志预览 ---${NC}"
    docker logs --tail 20 $CONTAINER_NAME
    exit 1
fi

# --- 6. 维护与清理 ---
echo -e "${YELLOW}🧹 正在清理过期镜像碎片...${NC}"
# 删除所有悬空镜像 (dangling images)，释放磁盘空间
docker image prune -f

echo -e "${GREEN}===============================================================${NC}"
echo -e "${GREEN}🎉 部署并重启任务圆满完成！${NC}"
echo -e "🌐 公网访问地址: ${YELLOW}http://8.140.221.150${NC}"
echo -e "${GREEN}===============================================================${NC}"