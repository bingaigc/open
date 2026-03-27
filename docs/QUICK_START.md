# OpenClaw 快速开始指南

## 概览

本指南将帮助您在 30 分钟内快速部署 OpenClaw 和 20 个智能体系统。

## 准备工作

### 1. 创建虚拟机

在 VMware Workstation Pro 中创建新虚拟机：

1. 打开 VMware Workstation Pro
2. 选择 "创建新虚拟机"
3. 选择 "典型配置"
4. 选择 Ubuntu 24.04.03 LTS Desktop ISO
5. 配置虚拟机：
   - 名称: OpenClaw-Ubuntu
   - 位置: 选择合适的存储位置
   - 最大磁盘大小: 100GB
   - 处理器: 4 核心（或更多）
   - 内存: 16GB（或更多）
   - 网络适配器: NAT 模式
6. 完成创建并启动虚拟机

### 2. 安装 Ubuntu Desktop

1. 启动虚拟机，开始 Ubuntu 安装
2. 选择语言和键盘布局
3. 选择 "正常安装"
4. 选择 "清除整个磁盘并安装 Ubuntu"
5. 创建用户账户（记住用户名和密码）
6. 等待安装完成并重启

### 3. 初始系统设置

登录系统后，打开终端：

```bash
# 更新系统（可选，部署脚本会自动执行）
sudo apt update && sudo apt upgrade -y

# 安装 git（如果未安装）
sudo apt install -y git
```

## 快速部署

### 方法一：自动化部署（推荐）

这是最简单的方式，一条命令完成所有配置。

```bash
# 1. 克隆仓库
git clone https://github.com/bingaigc/open.git
cd open

# 2. 赋予执行权限
chmod +x scripts/deploy_openclaw.sh

# 3. 运行部署脚本（需要 sudo 权限）
./scripts/deploy_openclaw.sh
```

脚本将自动完成以下步骤：
- ✅ 系统更新和安全加固
- ✅ 安装防火墙、Fail2Ban、AppArmor 等安全工具
- ✅ 安装 Python、PostgreSQL、Redis、Nginx 等依赖
- ✅ 配置数据库和缓存
- ✅ 生成 SSL 证书
- ✅ 配置反向代理
- ✅ 创建 OpenClaw 用户和目录结构
- ✅ 初始化智能体系统
- ✅ 创建备份和监控脚本

**预计时间**: 15-30 分钟（取决于网络速度）

### 方法二：手动部署

如果您想要更多控制权，可以参考 [完整部署指南](OPENCLAW_SECURE_SETUP.md) 进行手动配置。

## 部署后配置

### 1. 查看部署总结

脚本完成后，会显示详细的部署总结，包括：
- 访问地址
- 重要文件位置
- 管理命令
- 凭据文件位置

### 2. 验证安装

```bash
# 检查服务状态
sudo systemctl status openclaw
sudo systemctl status postgresql
sudo systemctl status redis-server
sudo systemctl status nginx

# 运行健康检查
/opt/openclaw/scripts/healthcheck.sh

# 查看防火墙状态
sudo ufw status verbose
```

### 3. 访问应用

打开浏览器访问：
- **Web UI**: https://localhost
- **API 文档**: https://localhost/api/docs

**注意**: 由于使用自签名证书，浏览器会显示安全警告，选择"继续访问"即可。

### 4. 配置智能体

智能体配置文件位于 `/opt/openclaw/agents/` 目录：

```bash
# 查看智能体配置
ls -la /opt/openclaw/agents/

# 编辑智能体配置（示例：编辑 CEO 智能体）
sudo nano /opt/openclaw/agents/management/01_ceo_agent.yaml
```

详细的智能体配置请参考 [20_AI_AGENTS.md](20_AI_AGENTS.md)。

## 常用管理命令

### 服务管理

```bash
# 启动 OpenClaw
sudo systemctl start openclaw

# 停止 OpenClaw
sudo systemctl stop openclaw

# 重启 OpenClaw
sudo systemctl restart openclaw

# 查看服务状态
sudo systemctl status openclaw

# 查看实时日志
sudo journalctl -u openclaw -f

# 查看最近 50 条日志
sudo journalctl -u openclaw -n 50
```

### 数据库管理

```bash
# 连接到 PostgreSQL
sudo -u postgres psql openclaw_db

# 查看数据库状态
sudo systemctl status postgresql

# 重启数据库
sudo systemctl restart postgresql
```

### Redis 管理

```bash
# 连接到 Redis（需要密码）
redis-cli
# 然后输入: AUTH your_redis_password

# 查看 Redis 状态
sudo systemctl status redis-server

# 重启 Redis
sudo systemctl restart redis-server
```

### 备份和恢复

```bash
# 手动创建备份
/opt/openclaw/scripts/backup.sh

# 查看备份文件
ls -lh /opt/openclaw/backups/

# 恢复数据库（示例）
gunzip -c /opt/openclaw/backups/db_20260327_020000.sql.gz | sudo -u postgres psql openclaw_db
```

### 安全检查

```bash
# 查看防火墙规则
sudo ufw status numbered

# 查看 Fail2Ban 状态
sudo fail2ban-client status

# 查看被禁止的 IP
sudo fail2ban-client status openclaw

# 运行 rootkit 扫描
sudo rkhunter --check --skip-keypress

# 运行完整性检查
sudo aide --check
```

## 智能体系统启动

智能体系统随 OpenClaw 服务自动启动。要单独管理智能体：

```bash
# 查看所有智能体状态（示例命令，需要根据实际实现调整）
# curl -X GET https://localhost/api/agents/status

# 启动特定智能体
# curl -X POST https://localhost/api/agents/ceo_001/start

# 停止特定智能体
# curl -X POST https://localhost/api/agents/ceo_001/stop
```

## 监控和日志

### 查看系统资源

```bash
# 查看 CPU 和内存使用
htop

# 查看磁盘使用
df -h

# 查看网络连接
netstat -tuln

# 查看进程
ps aux | grep openclaw
```

### 查看应用日志

```bash
# 查看应用日志
tail -f /opt/openclaw/logs/openclaw.log

# 查看错误日志
tail -f /opt/openclaw/logs/openclaw-error.log

# 查看 Nginx 访问日志
sudo tail -f /var/log/nginx/access.log

# 查看 Nginx 错误日志
sudo tail -f /var/log/nginx/error.log
```

## 常见问题排查

### 问题 1: 服务无法启动

```bash
# 检查服务状态
sudo systemctl status openclaw

# 查看详细错误
sudo journalctl -u openclaw -n 100

# 检查配置文件
cat /opt/openclaw/.env

# 检查端口占用
sudo lsof -i :8080
sudo lsof -i :3000
```

### 问题 2: 数据库连接失败

```bash
# 检查 PostgreSQL 状态
sudo systemctl status postgresql

# 测试数据库连接
sudo -u postgres psql -c "SELECT 1;"

# 查看数据库日志
sudo tail -f /var/log/postgresql/postgresql-16-main.log
```

### 问题 3: 无法访问 Web 界面

```bash
# 检查 Nginx 状态
sudo systemctl status nginx

# 测试 Nginx 配置
sudo nginx -t

# 检查防火墙
sudo ufw status

# 检查 SSL 证书
sudo ls -l /etc/ssl/certs/openclaw.crt
sudo ls -l /etc/ssl/private/openclaw.key
```

### 问题 4: 内存不足

```bash
# 查看内存使用
free -h

# 查看占用内存最多的进程
ps aux --sort=-%mem | head

# 调整虚拟机内存（在 VMware 中）或减少智能体数量
```

## 安全最佳实践

### 1. 更改默认密码

```bash
# 更改数据库密码
sudo -u postgres psql
ALTER USER openclaw WITH PASSWORD 'new_secure_password';
\q

# 更新 .env 文件中的密码
sudo nano /opt/openclaw/.env
# 修改 DATABASE_URL 中的密码

# 重启服务
sudo systemctl restart openclaw
```

### 2. 配置 HTTPS 证书（生产环境）

```bash
# 安装 Certbot
sudo apt install -y certbot python3-certbot-nginx

# 获取 Let's Encrypt 证书（需要域名）
sudo certbot --nginx -d your-domain.com

# 证书会自动更新
```

### 3. 启用额外的安全功能

```bash
# 配置 SSH 密钥认证（禁用密码登录）
# 编辑 SSH 配置
sudo nano /etc/ssh/sshd_config
# 设置: PasswordAuthentication no

# 重启 SSH
sudo systemctl restart sshd
```

### 4. 定期备份

```bash
# 添加每日自动备份（脚本已配置 crontab）
crontab -l

# 手动测试备份
/opt/openclaw/scripts/backup.sh
```

## 性能优化

### 1. 数据库优化

```bash
# 调整 PostgreSQL 配置
sudo nano /etc/postgresql/16/main/postgresql.conf

# 建议配置（根据系统资源调整）:
# shared_buffers = 4GB
# effective_cache_size = 12GB
# maintenance_work_mem = 1GB
# work_mem = 64MB

# 重启数据库
sudo systemctl restart postgresql
```

### 2. Redis 优化

```bash
# 配置 Redis 内存限制
sudo nano /etc/redis/redis.conf

# 设置最大内存
# maxmemory 2gb
# maxmemory-policy allkeys-lru

# 重启 Redis
sudo systemctl restart redis-server
```

### 3. Nginx 优化

```bash
# 启用 gzip 压缩
sudo nano /etc/nginx/nginx.conf

# 在 http 块中添加:
# gzip on;
# gzip_types text/plain text/css application/json application/javascript;
# gzip_min_length 1000;

# 重启 Nginx
sudo systemctl restart nginx
```

## 下一步

1. **配置智能体**: 根据需求调整 20 个智能体的配置
2. **集成外部服务**: 配置 Slack、Email 等集成
3. **开发自定义功能**: 根据业务需求开发新功能
4. **监控设置**: 配置 Prometheus、Grafana 等监控工具
5. **负载测试**: 进行性能测试和优化

## 获取帮助

- 📖 [完整文档](OPENCLAW_SECURE_SETUP.md)
- 📖 [智能体配置](20_AI_AGENTS.md)
- 🐛 [报告问题](https://github.com/bingaigc/open/issues)
- 💬 社区支持: support@openclaw.local

## 总结

恭喜！您已成功部署 OpenClaw 和 20 个智能体系统。这个系统现在可以：

- ✅ 安全运行在隔离的虚拟环境中
- ✅ 自动处理各种业务流程
- ✅ 提供完整的企业运营支持
- ✅ 持续监控和自动备份

现在您可以开始使用这个强大的"一人公司"系统了！
