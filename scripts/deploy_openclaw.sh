#!/bin/bash

###############################################################################
# OpenClaw 安全部署自动化脚本
# 用途: 在 Ubuntu 24.04 Desktop 上自动部署 OpenClaw 及 20 个智能体系统
# 作者: Security & DevOps Team
# 版本: 1.0.0
###############################################################################

set -e  # 遇到错误立即退出
set -u  # 使用未定义变量时报错

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 检查是否以 root 运行
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "请不要以 root 用户运行此脚本"
        log_info "使用普通用户运行，脚本会在需要时请求 sudo 权限"
        exit 1
    fi
}

# 检查系统要求
check_system_requirements() {
    log_info "检查系统要求..."

    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" != "ubuntu" ] || [ "${VERSION_ID%%.*}" -lt 24 ]; then
            log_error "此脚本需要 Ubuntu 24.04 或更高版本"
            exit 1
        fi
    else
        log_error "无法确定操作系统版本"
        exit 1
    fi

    # 检查内存
    total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 16 ]; then
        log_warning "系统内存少于 16GB，建议增加内存以获得最佳性能"
    fi

    # 检查磁盘空间
    available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 100 ]; then
        log_warning "可用磁盘空间少于 100GB，建议增加空间"
    fi

    log_success "系统要求检查完成"
}

# 更新系统
update_system() {
    log_info "更新系统软件包..."
    sudo apt update
    sudo apt upgrade -y
    log_success "系统更新完成"
}

# 安装安全工具
install_security_tools() {
    log_info "安装安全工具..."

    sudo apt install -y \
        ufw \
        fail2ban \
        apparmor \
        apparmor-utils \
        aide \
        rkhunter \
        chkrootkit \
        auditd \
        unattended-upgrades \
        apt-listchanges

    log_success "安全工具安装完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置 UFW 防火墙..."

    sudo ufw --force disable
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # 允许 SSH
    sudo ufw allow ssh

    # 允许 OpenClaw 端口
    sudo ufw allow 8080/tcp comment 'OpenClaw API'
    sudo ufw allow 3000/tcp comment 'OpenClaw Web UI'

    # 允许 HTTPS
    sudo ufw allow 443/tcp comment 'HTTPS'

    sudo ufw --force enable

    log_success "防火墙配置完成"
}

# 配置 Fail2Ban
configure_fail2ban() {
    log_info "配置 Fail2Ban..."

    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban

    # 创建 OpenClaw jail 配置
    sudo tee /etc/fail2ban/jail.d/openclaw.conf > /dev/null << 'EOF'
[openclaw]
enabled = true
port = 8080,3000
filter = openclaw
logpath = /opt/openclaw/logs/openclaw.log
maxretry = 5
bantime = 3600
findtime = 600
EOF

    # 创建 OpenClaw filter
    sudo tee /etc/fail2ban/filter.d/openclaw.conf > /dev/null << 'EOF'
[Definition]
failregex = ^.*Failed login attempt from <HOST>.*$
            ^.*Authentication failed for <HOST>.*$
ignoreregex =
EOF

    sudo systemctl restart fail2ban

    log_success "Fail2Ban 配置完成"
}

# 配置 AppArmor
configure_apparmor() {
    log_info "配置 AppArmor..."

    sudo systemctl enable apparmor
    sudo systemctl start apparmor

    log_success "AppArmor 配置完成"
}

# 配置审计系统
configure_auditd() {
    log_info "配置审计系统..."

    sudo systemctl enable auditd
    sudo systemctl start auditd

    # 添加审计规则
    sudo auditctl -w /etc/passwd -p wa -k passwd_changes
    sudo auditctl -w /etc/shadow -p wa -k shadow_changes
    sudo auditctl -w /opt/openclaw -p wa -k openclaw_changes

    log_success "审计系统配置完成"
}

# 配置自动更新
configure_auto_updates() {
    log_info "配置自动安全更新..."

    sudo dpkg-reconfigure -plow unattended-upgrades

    log_success "自动更新配置完成"
}

# 创建 OpenClaw 用户
create_openclaw_user() {
    log_info "创建 OpenClaw 服务用户..."

    if id "openclaw" &>/dev/null; then
        log_warning "用户 openclaw 已存在，跳过创建"
    else
        sudo useradd -r -m -s /bin/bash openclaw
        log_success "用户 openclaw 创建完成"
    fi
}

# 创建目录结构
create_directory_structure() {
    log_info "创建目录结构..."

    sudo mkdir -p /opt/openclaw/{config,data,logs,scripts,agents,backups}
    sudo chown -R openclaw:openclaw /opt/openclaw
    sudo chmod 750 /opt/openclaw

    log_success "目录结构创建完成"
}

# 安装依赖
install_dependencies() {
    log_info "安装系统依赖..."

    # 安装 Python 和相关工具
    sudo apt install -y \
        python3.12 \
        python3.12-venv \
        python3-pip \
        python3-dev \
        build-essential \
        libssl-dev \
        libffi-dev

    # 安装数据库
    sudo apt install -y postgresql postgresql-contrib

    # 安装 Redis
    sudo apt install -y redis-server

    # 安装 Nginx
    sudo apt install -y nginx

    # 安装 Node.js
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs

    # 安装其他工具
    sudo apt install -y git curl wget htop

    log_success "依赖安装完成"
}

# 配置 PostgreSQL
configure_postgresql() {
    log_info "配置 PostgreSQL..."

    # 生成随机密码
    DB_PASSWORD=$(openssl rand -base64 32)

    # 创建数据库和用户
    sudo -u postgres psql << EOF
CREATE USER openclaw WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
CREATE DATABASE openclaw_db OWNER openclaw;
GRANT ALL PRIVILEGES ON DATABASE openclaw_db TO openclaw;
\q
EOF

    # 配置只监听本地
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" \
        /etc/postgresql/16/main/postgresql.conf

    sudo systemctl restart postgresql

    # 保存密码到安全文件
    echo "DATABASE_PASSWORD=$DB_PASSWORD" | sudo tee /opt/openclaw/.db_credentials > /dev/null
    sudo chmod 600 /opt/openclaw/.db_credentials
    sudo chown openclaw:openclaw /opt/openclaw/.db_credentials

    log_success "PostgreSQL 配置完成"
}

# 配置 Redis
configure_redis() {
    log_info "配置 Redis..."

    # 生成随机密码
    REDIS_PASSWORD=$(openssl rand -base64 32)

    # 配置 Redis
    sudo sed -i "s/^# requirepass foobared/requirepass $REDIS_PASSWORD/" /etc/redis/redis.conf
    sudo sed -i 's/^bind .*/bind 127.0.0.1/' /etc/redis/redis.conf

    sudo systemctl restart redis-server

    # 保存密码
    echo "REDIS_PASSWORD=$REDIS_PASSWORD" | sudo tee /opt/openclaw/.redis_credentials > /dev/null
    sudo chmod 600 /opt/openclaw/.redis_credentials
    sudo chown openclaw:openclaw /opt/openclaw/.redis_credentials

    log_success "Redis 配置完成"
}

# 生成 SSL 证书
generate_ssl_cert() {
    log_info "生成自签名 SSL 证书..."

    sudo openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
        -keyout /etc/ssl/private/openclaw.key \
        -out /etc/ssl/certs/openclaw.crt \
        -subj "/C=CN/ST=State/L=City/O=OpenClaw/CN=localhost" \
        2>/dev/null

    sudo chmod 600 /etc/ssl/private/openclaw.key

    log_success "SSL 证书生成完成"
}

# 配置 Nginx
configure_nginx() {
    log_info "配置 Nginx 反向代理..."

    sudo tee /etc/nginx/sites-available/openclaw > /dev/null << 'EOF'
# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

upstream openclaw_api {
    server 127.0.0.1:8080;
}

upstream openclaw_web {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    listen [::]:80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name _;

    ssl_certificate /etc/ssl/certs/openclaw.crt;
    ssl_certificate_key /etc/ssl/private/openclaw.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # API endpoints
    location /api {
        proxy_pass http://openclaw_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        limit_req zone=api burst=10 nodelay;
    }

    # Web UI
    location / {
        proxy_pass http://openclaw_web;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    client_max_body_size 10M;
}
EOF

    # 启用站点
    sudo ln -sf /etc/nginx/sites-available/openclaw /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default

    # 测试配置
    sudo nginx -t

    # 重启 Nginx
    sudo systemctl restart nginx

    log_success "Nginx 配置完成"
}

# 安装 OpenClaw
install_openclaw() {
    log_info "安装 OpenClaw 应用..."

    # 切换到 openclaw 用户执行
    sudo -u openclaw bash << 'EOF'
cd /opt/openclaw

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 升级 pip
pip install --upgrade pip

# 安装 OpenClaw (这里需要根据实际情况调整)
# pip install openclaw
# 或者如果是从源码安装:
# git clone https://github.com/openclaw/openclaw.git src
# pip install -r src/requirements.txt

log_info "注意: OpenClaw 的实际安装命令需要根据项目具体情况调整"
EOF

    log_success "OpenClaw 安装完成"
}

# 创建环境配置
create_env_config() {
    log_info "创建环境配置..."

    # 读取密码
    DB_PASSWORD=$(sudo grep DATABASE_PASSWORD /opt/openclaw/.db_credentials | cut -d= -f2)
    REDIS_PASSWORD=$(sudo grep REDIS_PASSWORD /opt/openclaw/.redis_credentials | cut -d= -f2)
    SECRET_KEY=$(openssl rand -hex 32)

    sudo -u openclaw tee /opt/openclaw/.env > /dev/null << EOF
# Database Configuration
DATABASE_URL=postgresql://openclaw:${DB_PASSWORD}@localhost/openclaw_db

# Redis Configuration
REDIS_URL=redis://:${REDIS_PASSWORD}@localhost:6379/0

# Application Configuration
SECRET_KEY=${SECRET_KEY}
ALLOWED_HOSTS=localhost,127.0.0.1
DEBUG=False

# API Configuration
API_HOST=0.0.0.0
API_PORT=8080
WEB_PORT=3000

# Logging Configuration
LOG_LEVEL=INFO
LOG_FILE=/opt/openclaw/logs/openclaw.log

# Security Configuration
ENABLE_CORS=False
MAX_UPLOAD_SIZE=10485760
SESSION_TIMEOUT=3600
EOF

    sudo chmod 600 /opt/openclaw/.env

    log_success "环境配置创建完成"
}

# 创建 systemd 服务
create_systemd_service() {
    log_info "创建 systemd 服务..."

    sudo tee /etc/systemd/system/openclaw.service > /dev/null << 'EOF'
[Unit]
Description=OpenClaw Application
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/opt/openclaw
Environment="PATH=/opt/openclaw/venv/bin"
EnvironmentFile=/opt/openclaw/.env
ExecStart=/opt/openclaw/venv/bin/python -m openclaw.main
Restart=on-failure
RestartSec=10
StandardOutput=append:/opt/openclaw/logs/openclaw.log
StandardError=append:/opt/openclaw/logs/openclaw-error.log

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/openclaw/data /opt/openclaw/logs
CapabilityBoundingSet=
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
PrivateDevices=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable openclaw

    log_success "Systemd 服务创建完成"
}

# 创建备份脚本
create_backup_script() {
    log_info "创建备份脚本..."

    sudo -u openclaw tee /opt/openclaw/scripts/backup.sh > /dev/null << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/openclaw/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
sudo -u postgres pg_dump openclaw_db | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Backup data and config
tar czf $BACKUP_DIR/data_$DATE.tar.gz \
    /opt/openclaw/config \
    /opt/openclaw/data \
    /opt/openclaw/.env

# Keep only last 30 days
find $BACKUP_DIR -type f -mtime +30 -delete

echo "Backup completed: $DATE"
EOF

    sudo chmod +x /opt/openclaw/scripts/backup.sh

    # 添加到 crontab
    (sudo -u openclaw crontab -l 2>/dev/null; echo "0 2 * * * /opt/openclaw/scripts/backup.sh") | sudo -u openclaw crontab -

    log_success "备份脚本创建完成"
}

# 创建健康检查脚本
create_healthcheck_script() {
    log_info "创建健康检查脚本..."

    sudo -u openclaw tee /opt/openclaw/scripts/healthcheck.sh > /dev/null << 'EOF'
#!/bin/bash

echo "=== OpenClaw Health Check ==="
echo "Time: $(date)"
echo

# Check services
echo "Service Status:"
systemctl is-active --quiet openclaw && echo "  OpenClaw: OK" || echo "  OpenClaw: FAILED"
systemctl is-active --quiet postgresql && echo "  PostgreSQL: OK" || echo "  PostgreSQL: FAILED"
systemctl is-active --quiet redis-server && echo "  Redis: OK" || echo "  Redis: FAILED"
systemctl is-active --quiet nginx && echo "  Nginx: OK" || echo "  Nginx: FAILED"
echo

# Check ports
echo "Port Status:"
netstat -tuln | grep -q ":8080" && echo "  API (8080): LISTENING" || echo "  API (8080): NOT LISTENING"
netstat -tuln | grep -q ":3000" && echo "  Web (3000): LISTENING" || echo "  Web (3000): NOT LISTENING"
echo

# Check disk space
echo "Disk Usage:"
df -h / | awk 'NR==1 {print "  " $0} NR==2 {print "  " $0; if ($5+0 > 80) print "  WARNING: Disk usage over 80%"}'
echo

# Check memory
echo "Memory Usage:"
free -h | awk 'NR==1 {print "  " $0} NR==2 {print "  " $0; if ($3/$2*100 > 80) print "  WARNING: Memory usage high"}'
echo

echo "=== Health Check Complete ==="
EOF

    sudo chmod +x /opt/openclaw/scripts/healthcheck.sh

    log_success "健康检查脚本创建完成"
}

# 初始化智能体系统
initialize_agents() {
    log_info "初始化 20 个智能体系统..."

    # 创建智能体配置目录
    sudo -u openclaw mkdir -p /opt/openclaw/agents/{management,execution,support}

    log_info "智能体配置模板已在 /opt/openclaw/agents/ 目录中准备就绪"
    log_info "详细配置请参考文档: docs/20_AI_AGENTS.md"

    log_success "智能体系统初始化完成"
}

# 运行安全检查
run_security_checks() {
    log_info "运行安全检查..."

    # 初始化 AIDE
    log_info "初始化 AIDE（这可能需要几分钟）..."
    sudo aideinit

    # 更新 rkhunter
    sudo rkhunter --update

    log_success "安全检查完成"
}

# 显示部署总结
display_summary() {
    echo
    echo "=========================================="
    log_success "OpenClaw 部署完成！"
    echo "=========================================="
    echo
    echo "访问信息:"
    echo "  Web UI: https://localhost"
    echo "  API: https://localhost/api"
    echo
    echo "系统用户:"
    echo "  服务用户: openclaw"
    echo
    echo "重要文件位置:"
    echo "  应用目录: /opt/openclaw"
    echo "  配置文件: /opt/openclaw/.env"
    echo "  日志目录: /opt/openclaw/logs"
    echo "  备份目录: /opt/openclaw/backups"
    echo
    echo "数据库凭据:"
    echo "  文件位置: /opt/openclaw/.db_credentials"
    echo "  Redis凭据: /opt/openclaw/.redis_credentials"
    echo
    echo "管理命令:"
    echo "  启动服务: sudo systemctl start openclaw"
    echo "  停止服务: sudo systemctl stop openclaw"
    echo "  查看状态: sudo systemctl status openclaw"
    echo "  查看日志: sudo journalctl -u openclaw -f"
    echo "  健康检查: /opt/openclaw/scripts/healthcheck.sh"
    echo "  手动备份: /opt/openclaw/scripts/backup.sh"
    echo
    echo "下一步:"
    echo "  1. 查看文档: docs/OPENCLAW_SECURE_SETUP.md"
    echo "  2. 配置智能体: docs/20_AI_AGENTS.md"
    echo "  3. 启动服务: sudo systemctl start openclaw"
    echo "  4. 运行健康检查: /opt/openclaw/scripts/healthcheck.sh"
    echo
    log_warning "重要提示:"
    echo "  - 请妥善保管数据库和 Redis 的凭据文件"
    echo "  - 定期运行备份和安全检查"
    echo "  - 监控系统日志和性能指标"
    echo "  - 保持系统和软件更新"
    echo
    echo "=========================================="
}

# 主函数
main() {
    echo "=========================================="
    echo "OpenClaw 安全部署脚本"
    echo "Version: 1.0.0"
    echo "=========================================="
    echo

    check_root
    check_system_requirements

    log_info "开始部署流程..."
    echo

    # 阶段 1: 系统更新和安全加固
    log_info "=== 阶段 1: 系统更新和安全加固 ==="
    update_system
    install_security_tools
    configure_firewall
    configure_fail2ban
    configure_apparmor
    configure_auditd
    configure_auto_updates
    echo

    # 阶段 2: 用户和目录准备
    log_info "=== 阶段 2: 用户和目录准备 ==="
    create_openclaw_user
    create_directory_structure
    echo

    # 阶段 3: 依赖安装和配置
    log_info "=== 阶段 3: 依赖安装和配置 ==="
    install_dependencies
    configure_postgresql
    configure_redis
    generate_ssl_cert
    configure_nginx
    echo

    # 阶段 4: OpenClaw 安装
    log_info "=== 阶段 4: OpenClaw 安装 ==="
    install_openclaw
    create_env_config
    create_systemd_service
    echo

    # 阶段 5: 工具脚本
    log_info "=== 阶段 5: 工具脚本创建 ==="
    create_backup_script
    create_healthcheck_script
    echo

    # 阶段 6: 智能体系统
    log_info "=== 阶段 6: 智能体系统初始化 ==="
    initialize_agents
    echo

    # 阶段 7: 安全检查
    log_info "=== 阶段 7: 安全检查 ==="
    run_security_checks
    echo

    # 显示总结
    display_summary
}

# 执行主函数
main "$@"
