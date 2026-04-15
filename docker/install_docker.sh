#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}开始安装 Docker...${NC}"

# 1. 卸载旧版本
echo -e "${YELLOW}正在清理旧版本 Docker (如有)...${NC}"
sudo apt-get remove -y docker docker-engine docker.io containerd runc > /dev/null 2>&1

# 2. 安装依赖工具
echo -e "${YELLOW}正在安装必要依赖...${NC}"
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# 3. 添加 Docker 官方 GPG 密钥
echo -e "${YELLOW}正在添加官方 GPG 密钥...${NC}"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes

# 4. 设置远程仓库
echo -e "${YELLOW}正在设置官方仓库源...${NC}"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. 安装 Docker 引擎
echo -e "${YELLOW}正在安装 Docker Engine & Compose...${NC}"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. 配置当前用户权限 (免 sudo 运行)
echo -e "${YELLOW}正在配置用户组权限...${NC}"
sudo usermod -aG docker $USER

# 7. 配置镜像加速器 (可选, 这里使用公共镜像源提升国内下载速度)
echo -e "${YELLOW}正在配置镜像加速器以提升下载速度...${NC}"
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://mirror.baidubce.com",
    "https://dockerproxy.com"
  ]
}
EOF

# 8. 重启 Docker 服务
echo -e "${YELLOW}正在重启 Docker...${NC}"
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker

echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}  Docker 安装成功! 版本信息:${NC}"
docker --version
docker compose version
echo -e "${GREEN}==============================================${NC}"
echo -e "${RED}注意：请运行命令 'newgrp docker' 或 '重新登录终端' 以使免 sudo 权限生效。${NC}"