#!/bin/bash

# =================================================================
# AgentX 基础设施部署脚本 - Jaeger 链路追踪 (优化重启版)
# =================================================================

# 1. 配置参数
DEPLOY_DIR="$HOME/service/jaeger"
echo "🚀 开始处理 Jaeger 监控中心任务..."

# 2. 环境检查函数
check_env() {
    if ! command -v docker &> /dev/null; then
        echo "❌ 错误: 未检测到 Docker，请先安装。"
        exit 1
    fi
    # 适配新版 docker compose 和旧版 docker-compose
    if docker compose version &> /dev/null; then
        DOCKER_CMD="docker compose"
    else
        DOCKER_CMD="docker-compose"
    fi
}

# 3. 创建目录
setup_dir() {
    if [ ! -d "$DEPLOY_DIR" ]; then
        mkdir -p "$DEPLOY_DIR"
        echo "📁 创建部署目录: $DEPLOY_DIR"
    fi
    cd "$DEPLOY_DIR" || exit
}

# 5. 执行重启/启动逻辑
deploy_service() {
    echo "🔄 正在执行服务重启逻辑..."
    # 停止并移除旧容器、网络（确保干净的重启环境）
    $DOCKER_CMD down --remove-orphans

    # 启动服务
    echo "⏳ 正在拉取镜像并启动容器..."
    $DOCKER_CMD up -d

    # 等待几秒让服务就绪
    sleep 3
}

# 6. 验证与反馈
verify() {
    echo "-------------------------------------------------------"
    if [ "$(docker ps -q -f name=agentx-jaeger)" ]; then
        # 获取本机 IP
        # 5. 精准获取 IPv4 地址
        echo "🔎 正在检索服务器 IPv4 地址..."
        # 逻辑：强制使用 -4 参数，如果失败则尝试截取 ip addr 中的第一个内网 IPv4
        IPV4_ADDR=$(curl -s -4 --connect-timeout 5 ifconfig.me || ip route get 1.1.1.1 | grep -oP 'src \K\S+')=$(curl -s -4 --connect-timeout 5 ifconfig.me || ip route get 1.1.1.1 | grep -oP 'src \K\S+')
        echo "✅ Jaeger 重启成功且已就绪！"
        echo "🌐 监控大屏地址: http://${IPV4_ADDR}:16686"
        echo "📥 数据接收端口 (gRPC): 4317"
        echo "📂 部署路径: $DEPLOY_DIR"
        echo "💡 提示: 如果无法访问，请检查云服务器安全组 16686 和 4317 端口是否放行。"
    else
        echo "❌ 重启失败，尝试运行 'docker logs agentx-jaeger' 查看原因。"
    fi
    echo "-------------------------------------------------------"
}

# --- 执行流程 ---
check_env
setup_dir
deploy_service
verify
EOF
