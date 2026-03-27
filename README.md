# OpenClaw 安全部署项目

## 项目概述

本项目提供在 VMware Workstation Pro 虚拟机中的 Ubuntu 24.04.03 LTS Desktop 上安全部署 OpenClaw 的完整解决方案，包括 20 个智能体系统，形成完整的"一人公司"运营闭环。

## 项目特点

- ✅ **多层安全防护**: 从虚拟化层到应用层的全方位安全加固
- ✅ **自动化部署**: 一键部署脚本，简化安装过程
- ✅ **20 个智能体系统**: 覆盖管理、执行、支持三大层级
- ✅ **生产级配置**: 包含防火墙、入侵检测、审计系统等
- ✅ **完整文档**: 详细的配置说明和最佳实践
- ✅ **桌面环境**: 原生 Ubuntu Desktop 部署，非容器化

## 目录结构

```
.
├── README.md                          # 项目说明（本文件）
├── docs/                              # 文档目录
│   ├── OPENCLAW_SECURE_SETUP.md      # OpenClaw 安全部署完整指南
│   ├── 20_AI_AGENTS.md               # 20 个智能体系统详细文档
│   └── QUICK_START.md                # 快速开始指南
├── scripts/                           # 脚本目录
│   └── deploy_openclaw.sh            # 自动化部署脚本
└── agents/                            # 智能体配置目录
    ├── management/                    # 管理层智能体
    │   └── 01_ceo_agent.yaml         # CEO 智能体配置
    ├── execution/                     # 执行层智能体
    │   ├── 07_backend_dev_agent.yaml # 后端开发智能体配置
    │   └── 11_security_agent.yaml    # 安全专家智能体配置
    └── support/                       # 支持层智能体
        └── (更多智能体配置...)
```

## 快速开始

### 前置条件

1. **硬件要求**:
   - CPU: 至少 4 核心（推荐 8 核心）
   - 内存: 至少 16GB（推荐 32GB）
   - 硬盘: 至少 100GB SSD

2. **软件要求**:
   - Windows 11 主机系统
   - VMware Workstation Pro 17.x 或更高版本
   - Ubuntu 24.04.03 LTS Desktop ISO

### 安装步骤

#### 方法一：自动化安装（推荐）

1. 创建并启动 Ubuntu 24.04 Desktop 虚拟机

2. 克隆本仓库：
```bash
git clone https://github.com/bingaigc/open.git
cd open
```

3. 运行自动化部署脚本：
```bash
chmod +x scripts/deploy_openclaw.sh
./scripts/deploy_openclaw.sh
```

4. 脚本将自动完成：
   - 系统更新和安全加固
   - 安装所有必要依赖
   - 配置防火墙和安全工具
   - 部署 OpenClaw 应用
   - 初始化智能体系统
   - 创建备份和监控脚本

5. 安装完成后，访问：
   - Web UI: https://localhost
   - API: https://localhost/api

#### 方法二：手动安装

详见 [OPENCLAW_SECURE_SETUP.md](docs/OPENCLAW_SECURE_SETUP.md) 文档。

## 20 个智能体系统

本项目包含 20 个专业智能体，形成完整的企业运营体系：

### 管理层（4 个）
1. **CEO Agent** - 战略决策和整体协调
2. **CTO Agent** - 技术战略和架构决策
3. **CFO Agent** - 财务管理和成本优化
4. **COO Agent** - 日常运营和流程优化

### 执行层（8 个）
5. **Product Manager Agent** - 产品规划和需求管理
6. **Software Architect Agent** - 系统架构设计
7. **Backend Developer Agent** - 后端服务开发
8. **Frontend Developer Agent** - 用户界面开发
9. **DevOps Engineer Agent** - 基础设施和部署
10. **QA Engineer Agent** - 质量保证和测试
11. **Security Expert Agent** - 安全审计和防护
12. **Data Scientist Agent** - 数据分析和机器学习

### 支持层（8 个）
13. **Customer Support Agent** - 客户服务和支持
14. **Marketing Agent** - 市场推广和营销
15. **Content Creator Agent** - 内容创作和管理
16. **UI/UX Designer Agent** - 用户体验和界面设计
17. **HR Agent** - 人力资源管理
18. **Legal Advisor Agent** - 法律合规和风险管理
19. **Business Analyst Agent** - 业务分析和优化
20. **Research Assistant Agent** - 技术研究和创新

详细配置请参考 [20_AI_AGENTS.md](docs/20_AI_AGENTS.md) 文档。

## 安全特性

### 系统级安全
- ✅ UFW 防火墙配置
- ✅ Fail2Ban 入侵防御
- ✅ AppArmor 强制访问控制
- ✅ Auditd 审计系统
- ✅ 自动安全更新

### 应用级安全
- ✅ SSL/TLS 加密通信
- ✅ JWT 身份验证
- ✅ 速率限制
- ✅ 安全头配置
- ✅ 输入验证和过滤

### 数据安全
- ✅ 数据库密码加密
- ✅ 环境变量隔离
- ✅ 定期自动备份
- ✅ 访问控制和审计

### 网络安全
- ✅ Nginx 反向代理
- ✅ HTTPS 强制
- ✅ 网络隔离
- ✅ DDoS 防护

## 管理和维护

### 服务管理

```bash
# 启动服务
sudo systemctl start openclaw

# 停止服务
sudo systemctl stop openclaw

# 重启服务
sudo systemctl restart openclaw

# 查看状态
sudo systemctl status openclaw

# 查看日志
sudo journalctl -u openclaw -f
```

### 健康检查

```bash
# 运行健康检查
/opt/openclaw/scripts/healthcheck.sh
```

### 备份

```bash
# 手动备份
/opt/openclaw/scripts/backup.sh

# 备份文件位置
ls -lh /opt/openclaw/backups/
```

### 安全检查

```bash
# 运行漏洞扫描
sudo rkhunter --check

# 运行完整性检查
sudo aide --check

# 查看防火墙状态
sudo ufw status verbose

# 查看 Fail2Ban 状态
sudo fail2ban-client status
```

## 文档

- 📖 [完整部署指南](docs/OPENCLAW_SECURE_SETUP.md) - 详细的安装和配置说明
- 📖 [20 个智能体系统](docs/20_AI_AGENTS.md) - 智能体详细配置和协作机制
- 📖 [快速开始](docs/QUICK_START.md) - 快速入门指南
- 📖 [故障排除](docs/OPENCLAW_SECURE_SETUP.md#故障排除) - 常见问题解决方案

## 系统架构

```
┌─────────────────────────────────────────────────────────┐
│                    用户界面层                             │
│               (HTTPS + Nginx 反向代理)                   │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                    应用层                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  Web UI      │  │  API Server  │  │  智能体系统   │ │
│  │  (Port 3000) │  │  (Port 8080) │  │  (20 Agents) │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                    数据层                                 │
│  ┌──────────────┐  ┌──────────────┐                    │
│  │  PostgreSQL  │  │  Redis       │                    │
│  └──────────────┘  └──────────────┘                    │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                    安全层                                 │
│  UFW │ Fail2Ban │ AppArmor │ Auditd │ SSL/TLS          │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                    虚拟化层                               │
│           VMware Workstation Pro (Windows 11)           │
└─────────────────────────────────────────────────────────┘
```

## 最佳实践

1. **定期更新**: 保持系统和所有软件包最新
2. **监控日志**: 定期审查系统和应用日志
3. **备份验证**: 定期测试备份恢复流程
4. **安全审计**: 定期进行安全扫描和渗透测试
5. **性能监控**: 监控系统资源使用情况
6. **文档维护**: 记录所有配置和更改

## 性能优化建议

- 根据实际负载调整智能体数量
- 使用 Redis 缓存提高响应速度
- 优化数据库查询和索引
- 启用 Nginx 缓存和压缩
- 监控资源使用并及时扩容

## 故障排除

### 常见问题

1. **服务无法启动**: 检查日志文件和配置
2. **端口冲突**: 使用 `lsof` 检查端口占用
3. **数据库连接失败**: 验证数据库状态和凭据
4. **内存不足**: 调整虚拟机内存分配或减少智能体数量

详细的故障排除指南请参考 [完整文档](docs/OPENCLAW_SECURE_SETUP.md#故障排除)。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进本项目。

## 许可证

本项目采用 MIT 许可证。

## 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 Issue: https://github.com/bingaigc/open/issues
- 电子邮件: support@openclaw.local

## 致谢

感谢所有为网络安全和开源软件做出贡献的开发者和社区。

## 版本历史

### v1.0.0 (2026-03-27)
- ✨ 初始版本发布
- ✨ 完整的安全部署文档
- ✨ 20 个智能体系统设计
- ✨ 自动化部署脚本
- ✨ 示例智能体配置文件

## 路线图

- [ ] 智能体自我学习能力
- [ ] 动态任务分配系统
- [ ] 跨智能体知识共享
- [ ] 自动性能优化
- [ ] Web 管理界面
- [ ] 监控和报警系统
- [ ] 多语言支持

---

**注意**: 本项目提供的是一个安全部署框架和最佳实践指南。实际的 OpenClaw 应用实现需要根据具体需求进行调整和开发。
