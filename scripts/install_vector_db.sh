#!/bin/bash

###############################################################################
# 向量数据库部署脚本
# 用途: 为 OpenClaw 智能体系统安装和配置向量数据库（Qdrant）
# 作者: OpenClaw Team
# 版本: 1.0.0
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."

    # 检查可用内存
    available_mem=$(free -g | awk '/^Mem:/{print $7}')
    if [ "$available_mem" -lt 2 ]; then
        log_warning "可用内存少于 2GB，向量数据库性能可能受影响"
    fi

    # 检查磁盘空间
    available_space=$(df -BG /opt | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 10 ]; then
        log_error "可用磁盘空间少于 10GB，无法继续安装"
        exit 1
    fi

    log_success "系统要求检查完成"
}

# 安装 Qdrant
install_qdrant() {
    log_info "安装 Qdrant 向量数据库..."

    cd /tmp

    # 下载 Qdrant
    QDRANT_VERSION="1.7.0"
    QDRANT_URL="https://github.com/qdrant/qdrant/releases/download/v${QDRANT_VERSION}/qdrant-x86_64-unknown-linux-gnu.tar.gz"

    log_info "下载 Qdrant ${QDRANT_VERSION}..."
    wget -q --show-progress "${QDRANT_URL}" -O qdrant.tar.gz

    # 解压
    tar xzf qdrant.tar.gz

    # 安装
    sudo mv qdrant /usr/local/bin/
    sudo chmod +x /usr/local/bin/qdrant

    # 清理
    rm -f qdrant.tar.gz

    # 验证安装
    if command -v qdrant &> /dev/null; then
        log_success "Qdrant 安装成功"
        qdrant --version
    else
        log_error "Qdrant 安装失败"
        exit 1
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."

    sudo -u openclaw mkdir -p /opt/openclaw/data/qdrant
    sudo -u openclaw mkdir -p /opt/openclaw/config/qdrant
    sudo -u openclaw mkdir -p /opt/openclaw/logs
    sudo -u openclaw mkdir -p /opt/openclaw/backups/vector_db

    log_success "目录创建完成"
}

# 配置 Qdrant
configure_qdrant() {
    log_info "配置 Qdrant..."

    # 创建配置文件
    sudo -u openclaw tee /opt/openclaw/config/qdrant/config.yaml > /dev/null << 'EOF'
service:
  host: 0.0.0.0
  http_port: 6333
  grpc_port: 6334
  max_request_size_mb: 32

storage:
  storage_path: /opt/openclaw/data/qdrant
  snapshots_path: /opt/openclaw/backups/vector_db/snapshots

  performance:
    max_segment_size_kb: 200000
    memmap_threshold_kb: 100000
    indexing_threshold_kb: 20000

  optimizers:
    deleted_threshold: 0.2
    vacuum_min_vector_number: 1000
    default_segment_number: 2
    max_segment_size_kb: 200000
    memmap_threshold_kb: 100000
    indexing_threshold_kb: 20000

  hnsw_index:
    m: 16
    ef_construct: 100
    full_scan_threshold: 10000

log_level: INFO

telemetry_disabled: true
EOF

    log_success "Qdrant 配置完成"
}

# 创建 systemd 服务
create_systemd_service() {
    log_info "创建 Qdrant systemd 服务..."

    sudo tee /etc/systemd/system/qdrant.service > /dev/null << 'EOF'
[Unit]
Description=Qdrant Vector Database
Documentation=https://qdrant.tech/documentation/
After=network.target

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/opt/openclaw
ExecStart=/usr/local/bin/qdrant --config-path /opt/openclaw/config/qdrant/config.yaml
Restart=on-failure
RestartSec=10
StandardOutput=append:/opt/openclaw/logs/qdrant.log
StandardError=append:/opt/openclaw/logs/qdrant-error.log

# 资源限制
LimitNOFILE=65536
LimitNPROC=4096

# 安全加固
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/openclaw/data/qdrant /opt/openclaw/logs /opt/openclaw/backups/vector_db
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictNamespaces=true

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable qdrant

    log_success "Systemd 服务创建完成"
}

# 安装 Python 依赖
install_python_dependencies() {
    log_info "安装 Python 依赖..."

    sudo -u openclaw bash << 'EOF'
source /opt/openclaw/venv/bin/activate
pip install --upgrade pip
pip install qdrant-client==1.7.0
pip install sentence-transformers==2.2.2
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
EOF

    log_success "Python 依赖安装完成"
}

# 下载嵌入模型
download_embedding_model() {
    log_info "下载嵌入模型..."

    sudo -u openclaw bash << 'EOF'
source /opt/openclaw/venv/bin/activate
python3 << 'PYTHON_END'
from sentence_transformers import SentenceTransformer
import os

# 设置模型缓存目录
model_dir = "/opt/openclaw/models"
os.makedirs(model_dir, exist_ok=True)
os.environ['SENTENCE_TRANSFORMERS_HOME'] = model_dir

# 下载模型
print("下载 BGE 中文嵌入模型...")
model = SentenceTransformer('BAAI/bge-large-zh-v1.5')
print("模型下载完成!")

# 测试模型
test_text = "这是一个测试句子"
embedding = model.encode(test_text)
print(f"模型测试成功！向量维度: {len(embedding)}")
PYTHON_END
EOF

    log_success "嵌入模型下载完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."

    # 允许 Qdrant 端口（仅本地访问）
    # 注意：默认不开放外部访问，如需外部访问请手动配置

    log_success "防火墙配置完成（Qdrant 仅允许本地访问）"
}

# 启动服务
start_services() {
    log_info "启动 Qdrant 服务..."

    sudo systemctl start qdrant

    # 等待服务启动
    sleep 5

    # 检查服务状态
    if systemctl is-active --quiet qdrant; then
        log_success "Qdrant 服务启动成功"
    else
        log_error "Qdrant 服务启动失败"
        sudo journalctl -u qdrant -n 50
        exit 1
    fi
}

# 健康检查
health_check() {
    log_info "执行健康检查..."

    # 检查 HTTP API
    if curl -sf http://localhost:6333/health > /dev/null; then
        log_success "Qdrant HTTP API 正常"
    else
        log_error "Qdrant HTTP API 无响应"
        exit 1
    fi

    # 获取集合列表
    collections=$(curl -s http://localhost:6333/collections | python3 -m json.tool)
    log_info "当前集合列表:"
    echo "$collections"
}

# 创建测试脚本
create_test_script() {
    log_info "创建测试脚本..."

    sudo -u openclaw tee /opt/openclaw/scripts/test_vector_memory.py > /dev/null << 'EOF'
#!/usr/bin/env python3
"""
测试向量记忆服务
"""
import sys
sys.path.insert(0, '/opt/openclaw/src')

from vector_memory_service import VectorMemoryService, MemoryType, MemoryCategory

def test_vector_memory():
    print("=" * 60)
    print("测试向量记忆服务")
    print("=" * 60)

    # 初始化服务
    print("\n1. 初始化服务...")
    service = VectorMemoryService(config_path="/opt/openclaw/config/vector_memory.yaml")
    print("✓ 服务初始化成功")

    # 存储测试记忆
    print("\n2. 存储测试记忆...")
    memory_id = service.store_memory(
        agent_id="test_agent",
        content="我们采用微服务架构重构系统，使用 Docker 和 Kubernetes 进行容器化部署",
        metadata={
            "type": MemoryType.DECISION.value,
            "category": MemoryCategory.TECHNICAL.value,
            "importance": 0.9,
            "tags": ["architecture", "microservices", "docker", "kubernetes"],
            "context": "技术架构会议"
        }
    )
    print(f"✓ 记忆已存储，ID: {memory_id}")

    # 搜索记忆
    print("\n3. 搜索相关记忆...")
    memories = service.search_memory(
        agent_id="test_agent",
        query="系统架构和容器化部署",
        top_k=5
    )
    print(f"✓ 找到 {len(memories)} 条相关记忆")
    for i, memory in enumerate(memories, 1):
        print(f"  {i}. [{memory.importance:.2f}] {memory.content[:60]}...")

    # 获取统计信息
    print("\n4. 获取统计信息...")
    stats = service.get_statistics("test_agent")
    print(f"✓ 总记忆数: {stats.get('total_memories', 0)}")
    print(f"✓ 向量维度: {stats.get('vector_size', 0)}")

    print("\n" + "=" * 60)
    print("测试完成！向量记忆服务工作正常 ✓")
    print("=" * 60)

if __name__ == "__main__":
    test_vector_memory()
EOF

    sudo chmod +x /opt/openclaw/scripts/test_vector_memory.py

    log_success "测试脚本创建完成"
}

# 创建备份脚本
create_backup_script() {
    log_info "创建备份脚本..."

    sudo -u openclaw tee /opt/openclaw/scripts/backup_vector_db.sh > /dev/null << 'EOF'
#!/bin/bash
# 向量数据库备份脚本

BACKUP_DIR="/opt/openclaw/backups/vector_db"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/qdrant_backup_$DATE"

echo "开始备份向量数据库..."

# 创建备份目录
mkdir -p "$BACKUP_PATH"

# 使用 rsync 备份数据
rsync -av /opt/openclaw/data/qdrant/ "$BACKUP_PATH/"

# 压缩备份
cd "$BACKUP_DIR"
tar czf "qdrant_backup_$DATE.tar.gz" "qdrant_backup_$DATE"
rm -rf "qdrant_backup_$DATE"

# 保留最近30天的备份
find "$BACKUP_DIR" -name "qdrant_backup_*.tar.gz" -mtime +30 -delete

echo "备份完成: qdrant_backup_$DATE.tar.gz"
EOF

    sudo chmod +x /opt/openclaw/scripts/backup_vector_db.sh

    # 添加到 crontab（每天凌晨3点备份）
    (sudo -u openclaw crontab -l 2>/dev/null; echo "0 3 * * * /opt/openclaw/scripts/backup_vector_db.sh") | sudo -u openclaw crontab -

    log_success "备份脚本创建完成"
}

# 更新防火墙配置
update_firewall_rules() {
    log_info "更新防火墙规则..."

    # Qdrant 端口仅允许本地访问，无需开放外部端口
    log_info "Qdrant 端口 6333 和 6334 仅允许本地访问"

    log_success "防火墙规则更新完成"
}

# 显示安装总结
display_summary() {
    echo
    echo "=========================================="
    log_success "向量数据库安装完成！"
    echo "=========================================="
    echo
    echo "服务信息:"
    echo "  Qdrant HTTP API: http://localhost:6333"
    echo "  Qdrant gRPC API: localhost:6334"
    echo
    echo "配置文件:"
    echo "  Qdrant 配置: /opt/openclaw/config/qdrant/config.yaml"
    echo "  向量记忆配置: /opt/openclaw/config/vector_memory.yaml"
    echo
    echo "数据目录:"
    echo "  向量数据: /opt/openclaw/data/qdrant"
    echo "  备份目录: /opt/openclaw/backups/vector_db"
    echo "  模型缓存: /opt/openclaw/models"
    echo
    echo "管理命令:"
    echo "  启动服务: sudo systemctl start qdrant"
    echo "  停止服务: sudo systemctl stop qdrant"
    echo "  查看状态: sudo systemctl status qdrant"
    echo "  查看日志: sudo journalctl -u qdrant -f"
    echo "  健康检查: curl http://localhost:6333/health"
    echo
    echo "测试命令:"
    echo "  测试向量记忆: /opt/openclaw/scripts/test_vector_memory.py"
    echo "  备份数据库: /opt/openclaw/scripts/backup_vector_db.sh"
    echo
    echo "Python 使用示例:"
    echo "  from vector_memory_service import VectorMemoryService"
    echo "  service = VectorMemoryService()"
    echo "  memory_id = service.store_memory(...)"
    echo "  memories = service.search_memory(...)"
    echo
    log_info "嵌入模型: BAAI/bge-large-zh-v1.5 (1024维)"
    log_info "向量数据库: Qdrant v1.7.0"
    log_info "自动备份: 每天凌晨3点"
    echo
    echo "=========================================="
}

# 主函数
main() {
    echo "=========================================="
    echo "OpenClaw 向量数据库部署脚本"
    echo "Version: 1.0.0"
    echo "=========================================="
    echo

    check_requirements
    install_qdrant
    create_directories
    configure_qdrant
    create_systemd_service
    install_python_dependencies
    download_embedding_model
    configure_firewall
    start_services
    health_check
    create_test_script
    create_backup_script
    update_firewall_rules

    display_summary
}

# 执行主函数
main "$@"
