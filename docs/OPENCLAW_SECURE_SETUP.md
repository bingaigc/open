# OpenClaw 安全部署指南 - Ubuntu 24.04 Desktop

## 概述
本指南提供在 VMware Workstation Pro 虚拟机中的 Ubuntu 24.04.03 LTS Desktop 上安全部署 OpenClaw 的完整步骤。

## 系统要求

### 硬件要求（虚拟机配置）
- CPU: 至少 4 核心（推荐 8 核心）
- 内存: 至少 16GB（推荐 32GB）
- 硬盘: 至少 100GB SSD
- 网络: NAT 或桥接模式

### 软件要求
- Windows 11 主机系统
- VMware Workstation Pro 17.x 或更高版本
- Ubuntu 24.04.03 LTS Desktop ISO

## 安全架构设计

### 多层安全防护
1. **虚拟化隔离层**: VMware 虚拟机隔离
2. **操作系统加固层**: Ubuntu 系统安全加固
3. **网络安全层**: 防火墙、入侵检测
4. **应用安全层**: OpenClaw 应用级安全配置
5. **数据安全层**: 加密存储和传输

## 第一阶段：虚拟机安全配置

### 1.1 VMware 虚拟机创建
```bash
# 虚拟机配置建议
- 使用 UEFI 固件
- 启用安全启动
- 启用虚拟化 Intel VT-x/AMD-V
- 禁用共享文件夹（除非必要）
- 禁用拖放功能
- 启用快照功能用于备份
```

### 1.2 网络隔离配置
```bash
# 推荐使用自定义网络配置
- 创建独立的虚拟网络
- 配置严格的出站规则
- 使用 NAT 模式提供基本隔离
```

## 第二阶段：Ubuntu 系统安全加固

### 2.1 系统初始化
```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装必要的安全工具
sudo apt install -y ufw fail2ban apparmor apparmor-utils \
    aide rkhunter chkrootkit auditd \
    unattended-upgrades apt-listchanges
```

### 2.2 防火墙配置
```bash
# 配置 UFW 防火墙
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 8080/tcp  # OpenClaw API
sudo ufw allow 3000/tcp  # OpenClaw Web UI
sudo ufw enable
```

### 2.3 Fail2Ban 配置
```bash
# 配置 Fail2Ban 防止暴力破解
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 2.4 AppArmor 强制访问控制
```bash
# 启用 AppArmor
sudo systemctl enable apparmor
sudo systemctl start apparmor

# 检查 AppArmor 状态
sudo aa-status
```

### 2.5 审计系统配置
```bash
# 启用审计守护进程
sudo systemctl enable auditd
sudo systemctl start auditd

# 配置审计规则
sudo auditctl -w /etc/passwd -p wa -k passwd_changes
sudo auditctl -w /etc/shadow -p wa -k shadow_changes
```

### 2.6 自动安全更新
```bash
# 配置无人值守升级
sudo dpkg-reconfigure -plow unattended-upgrades
```

## 第三阶段：OpenClaw 安全部署

### 3.1 创建专用用户
```bash
# 创建 OpenClaw 服务用户
sudo useradd -r -m -s /bin/bash openclaw
sudo usermod -aG sudo openclaw

# 设置强密码
sudo passwd openclaw
```

### 3.2 目录结构设置
```bash
# 创建应用目录
sudo mkdir -p /opt/openclaw/{config,data,logs,scripts,agents}
sudo chown -R openclaw:openclaw /opt/openclaw
sudo chmod 750 /opt/openclaw
```

### 3.3 安装依赖
```bash
# 安装 Python 和必要依赖
sudo apt install -y python3.12 python3.12-venv python3-pip \
    postgresql postgresql-contrib redis-server \
    nginx certbot python3-certbot-nginx \
    git curl wget build-essential

# 安装 Node.js（用于前端）
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

### 3.4 数据库安全配置
```bash
# PostgreSQL 安全配置
sudo -u postgres psql << EOF
CREATE USER openclaw WITH ENCRYPTED PASSWORD 'CHANGE_THIS_PASSWORD';
CREATE DATABASE openclaw_db OWNER openclaw;
GRANT ALL PRIVILEGES ON DATABASE openclaw_db TO openclaw;
\q
EOF

# 配置 PostgreSQL 监听本地
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" \
    /etc/postgresql/16/main/postgresql.conf

sudo systemctl restart postgresql
```

### 3.5 Redis 安全配置
```bash
# 配置 Redis
sudo sed -i 's/^# requirepass foobared/requirepass CHANGE_THIS_REDIS_PASSWORD/' \
    /etc/redis/redis.conf
sudo sed -i 's/^bind 127.0.0.1/bind 127.0.0.1/' /etc/redis/redis.conf

sudo systemctl restart redis-server
```

### 3.6 OpenClaw 应用安装
```bash
# 切换到 openclaw 用户
sudo su - openclaw

# 克隆或安装 OpenClaw
cd /opt/openclaw
# 这里假设从源码安装，实际路径根据具体情况调整
# git clone https://github.com/openclaw/openclaw.git .

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install --upgrade pip
pip install openclaw  # 或从 requirements.txt 安装
```

### 3.7 环境变量安全配置
```bash
# 创建 .env 文件（不要提交到版本控制）
cat > /opt/openclaw/.env << 'EOF'
# 数据库配置
DATABASE_URL=postgresql://openclaw:CHANGE_THIS_PASSWORD@localhost/openclaw_db

# Redis 配置
REDIS_URL=redis://:CHANGE_THIS_REDIS_PASSWORD@localhost:6379/0

# 应用配置
SECRET_KEY=$(openssl rand -hex 32)
ALLOWED_HOSTS=localhost,127.0.0.1
DEBUG=False

# API 配置
API_HOST=0.0.0.0
API_PORT=8080
WEB_PORT=3000

# 日志配置
LOG_LEVEL=INFO
LOG_FILE=/opt/openclaw/logs/openclaw.log

# 安全配置
ENABLE_CORS=False
MAX_UPLOAD_SIZE=10485760
SESSION_TIMEOUT=3600
EOF

chmod 600 /opt/openclaw/.env
```

### 3.8 SSL/TLS 证书配置
```bash
# 使用自签名证书（开发环境）
sudo openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout /etc/ssl/private/openclaw.key \
    -out /etc/ssl/certs/openclaw.crt \
    -subj "/C=CN/ST=State/L=City/O=Organization/CN=localhost"

# 生产环境使用 Let's Encrypt
# sudo certbot --nginx -d yourdomain.com
```

### 3.9 Nginx 反向代理配置
```bash
# 创建 Nginx 配置
sudo tee /etc/nginx/sites-available/openclaw << 'EOF'
upstream openclaw_api {
    server 127.0.0.1:8080;
}

upstream openclaw_web {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    listen [::]:80;
    server_name localhost;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name localhost;

    ssl_certificate /etc/ssl/certs/openclaw.crt;
    ssl_certificate_key /etc/ssl/private/openclaw.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # 安全头
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';" always;

    # API 反向代理
    location /api {
        proxy_pass http://openclaw_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 速率限制
        limit_req zone=api burst=10 nodelay;
    }

    # Web UI 反向代理
    location / {
        proxy_pass http://openclaw_web;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # 文件上传大小限制
    client_max_body_size 10M;
}

# 速率限制配置
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
EOF

# 启用配置
sudo ln -s /etc/nginx/sites-available/openclaw /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 3.10 Systemd 服务配置
```bash
# 创建 systemd 服务
sudo tee /etc/systemd/system/openclaw.service << 'EOF'
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

# 安全加固
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

# 启用服务
sudo systemctl daemon-reload
sudo systemctl enable openclaw
sudo systemctl start openclaw
```

## 第四阶段：20 个智能体系统配置

详见 `20_AI_AGENTS.md` 文档。

## 第五阶段：安全监控和维护

### 5.1 日志监控
```bash
# 配置 logrotate
sudo tee /etc/logrotate.d/openclaw << 'EOF'
/opt/openclaw/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 openclaw openclaw
    sharedscripts
    postrotate
        systemctl reload openclaw > /dev/null 2>&1 || true
    endscript
}
EOF
```

### 5.2 入侵检测
```bash
# 运行 rkhunter
sudo rkhunter --update
sudo rkhunter --check --skip-keypress

# 运行 AIDE
sudo aideinit
sudo aide --check
```

### 5.3 安全审计
```bash
# 检查审计日志
sudo ausearch -k passwd_changes
sudo ausearch -k shadow_changes

# 生成审计报告
sudo aureport --summary
```

### 5.4 备份策略
```bash
# 创建备份脚本
sudo tee /opt/openclaw/scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/openclaw/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 备份数据库
sudo -u postgres pg_dump openclaw_db | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# 备份配置和数据
tar czf $BACKUP_DIR/data_$DATE.tar.gz \
    /opt/openclaw/config \
    /opt/openclaw/data \
    /opt/openclaw/.env

# 保留最近 30 天的备份
find $BACKUP_DIR -type f -mtime +30 -delete

echo "Backup completed: $DATE"
EOF

chmod +x /opt/openclaw/scripts/backup.sh

# 添加到 crontab（每天凌晨 2 点备份）
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/openclaw/scripts/backup.sh") | crontab -
```

### 5.5 健康检查
```bash
# 创建健康检查脚本
sudo tee /opt/openclaw/scripts/healthcheck.sh << 'EOF'
#!/bin/bash

# 检查服务状态
systemctl is-active --quiet openclaw || echo "OpenClaw service is down!"
systemctl is-active --quiet postgresql || echo "PostgreSQL is down!"
systemctl is-active --quiet redis-server || echo "Redis is down!"
systemctl is-active --quiet nginx || echo "Nginx is down!"

# 检查端口
netstat -tuln | grep -q ":8080" || echo "API port 8080 not listening!"
netstat -tuln | grep -q ":3000" || echo "Web port 3000 not listening!"

# 检查磁盘空间
df -h / | awk 'NR==2 {if ($5+0 > 80) print "Disk usage over 80%: " $5}'

# 检查内存使用
free -m | awk 'NR==2 {if ($3/$2*100 > 80) print "Memory usage over 80%"}'

echo "Health check completed at $(date)"
EOF

chmod +x /opt/openclaw/scripts/healthcheck.sh
```

## 第六阶段：安全加固清单

### 6.1 系统级安全
- [x] 防火墙配置
- [x] 入侵防御系统
- [x] 强制访问控制（AppArmor）
- [x] 审计系统
- [x] 自动安全更新

### 6.2 应用级安全
- [x] 专用服务用户
- [x] 最小权限原则
- [x] 环境变量隔离
- [x] SSL/TLS 加密
- [x] 安全头配置

### 6.3 数据安全
- [x] 数据库密码加密
- [x] 敏感数据加密存储
- [x] 定期备份
- [x] 访问控制

### 6.4 网络安全
- [x] 反向代理
- [x] 速率限制
- [x] HTTPS 强制
- [x] 网络隔离

## 故障排除

### 常见问题

1. **服务无法启动**
   ```bash
   sudo journalctl -u openclaw -n 50
   sudo systemctl status openclaw
   ```

2. **数据库连接失败**
   ```bash
   sudo -u postgres psql -l
   netstat -tuln | grep 5432
   ```

3. **端口冲突**
   ```bash
   sudo lsof -i :8080
   sudo lsof -i :3000
   ```

4. **权限问题**
   ```bash
   ls -la /opt/openclaw
   sudo chown -R openclaw:openclaw /opt/openclaw
   ```

## 安全最佳实践

1. **定期更新**: 保持系统和所有软件包最新
2. **强密码策略**: 使用复杂且唯一的密码
3. **最小权限原则**: 仅授予必要的权限
4. **定期备份**: 自动化备份并测试恢复
5. **监控日志**: 定期审查系统和应用日志
6. **安全审计**: 定期进行安全扫描和渗透测试
7. **文档维护**: 记录所有配置和更改
8. **隔离环境**: 使用虚拟机隔离不同的应用环境

## 参考资源

- Ubuntu Security Guide: https://ubuntu.com/security
- CIS Ubuntu Benchmark: https://www.cisecurity.org/
- OWASP Security Guidelines: https://owasp.org/
- AppArmor Documentation: https://gitlab.com/apparmor/apparmor/-/wikis/home

## 联系和支持

如有问题，请查阅项目文档或提交 Issue。
