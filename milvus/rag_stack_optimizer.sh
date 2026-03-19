#!/bin/bash

# ==============================================================================
# 脚本名称: rag_stack_optimizer.sh
# 描述: 针对 RAG 环境 (Milvus + Ollama) 的深度维护与内存优化脚本
# 版本: 2.0
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 配置区域
# ------------------------------------------------------------------------------
MILVUS_DIR="/usr/milvus"                 # Milvus docker-compose 目录
LOG_FILE="/var/log/rag_maint_full.log"   # 日志路径
OLLAMA_API="http://127.0.0.1:11434"      # Ollama 接口地址
CHAT_MODEL="qwen2.5:0.5b"                # 聊天模型
EMBED_MODEL="bge-m3"                     # 向量模型
MAX_RETRIES=15                           # Milvus 启动检查最大重试次数

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# ------------------------------------------------------------------------------
# 2. 核心日志函数
# ------------------------------------------------------------------------------
log() {
    local level=$1
    local msg=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case $level in
        "INFO")  echo -e "${GREEN}[$timestamp][INFO]${NC} $msg" | tee -a "$LOG_FILE" ;;
        "WARN")  echo -e "${YELLOW}[$timestamp][WARN]${NC} $msg" | tee -a "$LOG_FILE" ;;
        "ERROR") echo -e "${RED}[$timestamp][ERROR]${NC} $msg" | tee -a "$LOG_FILE" ;;
        "STEP")  echo -e "${BLUE}\n===> [$timestamp] $msg${NC}" | tee -a "$LOG_FILE" ;;
    esac
}

# ------------------------------------------------------------------------------
# 3. 环境检查
# ------------------------------------------------------------------------------
check_requirements() {
    log "INFO" "正在检查运行环境..."
    [[ $EUID -ne 0 ]] && { log "ERROR" "必须使用 root 权限运行此脚本 (sudo)"; exit 1; }
    
    command -v docker >/dev/null 2>&1 || { log "ERROR" "未找到 docker 命令"; exit 1; }
    command -v curl >/dev/null 2>&1 || { log "ERROR" "未找到 curl 命令"; exit 1; }
    
    if [ ! -d "$MILVUS_DIR" ]; then
        log "WARN" "Milvus 目录 $MILVUS_DIR 不存在，将跳过 Docker 相关操作"
        SKIP_DOCKER=true
    fi
}

# ------------------------------------------------------------------------------
# 4. 维护任务逻辑
# ------------------------------------------------------------------------------

# 步骤 A: 资源清理与服务停止
do_cleanup() {
    log "STEP" "阶段 1: 资源回收与服务停止"
    
    if [ "$SKIP_DOCKER" != true ]; then
        log "INFO" "停止 Milvus 容器服务..."
        cd "$MILVUS_DIR" && docker compose down >> "$LOG_FILE" 2>&1
    fi

    log "INFO" "重启 Ollama 服务以重置上下文内存..."
    systemctl restart ollama >> "$LOG_FILE" 2>&1
    
    log "WARN" "执行物理内存落盘 (sync)..."
    sync && sleep 2

    log "INFO" "释放系统内核缓存 (PageCache, Dentries, Inodes)..."
    echo 3 > /proc/sys/vm/drop_caches

    log "INFO" "清理 Docker 冗余镜像与卷数据..."
    docker system prune -f >> "$LOG_FILE" 2>&1
}

# 步骤 B: 服务恢复
do_restart() {
    log "STEP" "阶段 2: 服务启动与健康检查"
    
    if [ "$SKIP_DOCKER" != true ]; then
        log "INFO" "正在启动 Milvus 向量数据库..."
        cd "$MILVUS_DIR" && docker compose up -d >> "$LOG_FILE" 2>&1

        log "INFO" "等待 Milvus 容器就绪 (最大等待 $((MAX_RETRIES*5)) 秒)..."
        local count=0
        while [ $count -lt $MAX_RETRIES ]; do
            status=$(docker inspect --format='{{.State.Health.Status}}' milvus-standalone 2>/dev/null)
            if [ "$status" == "healthy" ]; then
                log "INFO" "✅ Milvus 状态健康！"
                return 0
            fi
            echo -n "."
            sleep 5
            ((count++))
        done
        log "ERROR" "❌ Milvus 启动超时，请检查 Docker 日志"
    fi
}

# 步骤 C: 模型预热
do_warmup() {
    log "STEP" "阶段 3: 模型预热 (Warm-up)"
    
    log "INFO" "加载模型到内存: $CHAT_MODEL ..."
    local chat_resp=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$OLLAMA_API/api/generate" \
        -d "{\"model\": \"$CHAT_MODEL\", \"prompt\": \"hi\", \"stream\": false}")
    
    if [ "$chat_resp" == "200" ]; then
        log "INFO" "✅ 聊天模型预热成功"
    else
        log "WARN" "⚠️ 聊天模型预热返回异常码: $chat_resp"
    fi

    log "INFO" "加载向量模型: $EMBED_MODEL ..."
    local embed_resp=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$OLLAMA_API/api/embeddings" \
        -d "{\"model\": \"$EMBED_MODEL\", \"prompt\": \"warmup\"}")
    
    [[ "$embed_resp" == "200" ]] && log "INFO" "✅ 向量模型预热成功" || log "WARN" "⚠️ 向量模型预热异常"
}

# ------------------------------------------------------------------------------
# 5. 主执行流程
# ------------------------------------------------------------------------------
main() {
    echo "====================================================" >> "$LOG_FILE"
    log "INFO" ">>> 开始执行全栈深度维护任务 <<<"
    
    check_requirements
    
    log "INFO" "维护前内存状态:"
    free -h | tee -a "$LOG_FILE"

    do_cleanup
    do_restart
    do_warmup

    log "INFO" "维护后资源状态:"
    free -h | tee -a "$LOG_FILE"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" | tee -a "$LOG_FILE"
    
    log "INFO" ">>> 维护任务圆满完成 <<<"
    echo "====================================================" >> "$LOG_FILE"
}

# 执行主函数
main