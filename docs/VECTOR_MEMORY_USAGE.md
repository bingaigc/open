# 向量记忆系统使用示例

## 快速开始

### 1. 安装向量数据库

```bash
# 运行安装脚本
cd /home/runner/work/open/open
chmod +x scripts/install_vector_db.sh
sudo ./scripts/install_vector_db.sh
```

### 2. 基本使用

```python
from vector_memory_service import VectorMemoryService, MemoryType, MemoryCategory

# 初始化服务
service = VectorMemoryService()

# 存储记忆
memory_id = service.store_memory(
    agent_id="ceo_001",
    content="我们决定在Q2季度推出新产品，目标是提升30%的市场份额",
    metadata={
        "type": MemoryType.DECISION.value,
        "category": MemoryCategory.STRATEGIC.value,
        "importance": 0.95,
        "tags": ["product_launch", "Q2", "market_strategy"],
        "context": "战略规划会议"
    }
)

# 语义搜索
memories = service.search_memory(
    agent_id="ceo_001",
    query="新产品发布计划",
    top_k=5,
    min_score=0.7
)

for memory in memories:
    print(f"[{memory.importance:.2f}] {memory.content}")
    print(f"  标签: {', '.join(memory.tags)}")
    print()
```

### 3. 高级功能

#### 过滤搜索

```python
# 按类型和时间过滤
memories = service.search_memory(
    agent_id="be_dev_001",
    query="数据库优化方案",
    top_k=10,
    filters={
        "type": "technical",
        "importance": {"gte": 0.7}
    }
)
```

#### 获取重要记忆

```python
# 获取最重要的记忆
important_memories = service.get_important_memories(
    agent_id="sec_001",
    min_importance=0.8,
    limit=10
)
```

#### 获取最近记忆

```python
# 获取最近24小时的记忆
recent_memories = service.get_recent_memories(
    agent_id="ceo_001",
    hours=24,
    limit=20
)
```

#### 更新记忆

```python
# 更新记忆内容和元数据
service.update_memory(
    agent_id="ceo_001",
    memory_id=memory_id,
    metadata={"importance": 0.98}
)
```

#### 清理旧记忆

```python
# 清理90天以前且重要性低的记忆
deleted_count = service.cleanup_old_memories(
    agent_id="ceo_001",
    days=90,
    min_importance=0.3
)
print(f"清理了 {deleted_count} 条旧记忆")
```

### 4. 智能体集成

```python
class IntelligentAgent:
    def __init__(self, agent_id: str):
        self.agent_id = agent_id
        self.memory = VectorMemoryService()

    def learn(self, experience: str, importance: float = 0.5):
        """学习新经验"""
        return self.memory.store_memory(
            agent_id=self.agent_id,
            content=experience,
            metadata={
                "type": "experience",
                "importance": importance
            }
        )

    def recall(self, context: str, limit: int = 5):
        """回忆相关经验"""
        return self.memory.search_memory(
            agent_id=self.agent_id,
            query=context,
            top_k=limit
        )

    def make_decision(self, problem: str):
        """基于记忆做决策"""
        # 回忆相关经验
        relevant_memories = self.recall(problem)

        # 提取知识
        knowledge = [m.content for m in relevant_memories]

        # 做出决策（这里简化处理）
        decision = f"基于 {len(knowledge)} 条经验，建议..."

        # 记录决策
        self.learn(
            f"问题: {problem}\n决策: {decision}",
            importance=0.8
        )

        return decision

# 使用示例
agent = IntelligentAgent("ceo_001")
agent.learn("微服务架构提高了系统可维护性", importance=0.8)
relevant = agent.recall("如何提升系统架构")
```

### 5. 批量操作

```python
# 批量存储记忆
memories_to_store = [
    {
        "agent_id": "be_dev_001",
        "content": "使用连接池可以显著提升数据库性能",
        "metadata": {"type": "knowledge", "importance": 0.7}
    },
    {
        "agent_id": "be_dev_001",
        "content": "Redis 缓存可以减少数据库查询压力",
        "metadata": {"type": "knowledge", "importance": 0.75}
    }
]

for memory_data in memories_to_store:
    service.store_memory(**memory_data)
```

### 6. 统计和监控

```python
# 获取统计信息
stats = service.get_statistics("ceo_001")
print(f"总记忆数: {stats['total_memories']}")
print(f"向量维度: {stats['vector_size']}")
print(f"距离度量: {stats['distance']}")
```

## 命令行工具

### 测试向量记忆服务

```bash
# 运行测试脚本
/opt/openclaw/scripts/test_vector_memory.py
```

### 备份向量数据库

```bash
# 手动备份
/opt/openclaw/scripts/backup_vector_db.sh

# 查看备份
ls -lh /opt/openclaw/backups/vector_db/
```

### 健康检查

```bash
# 检查 Qdrant 状态
curl http://localhost:6333/health

# 查看集合列表
curl http://localhost:6333/collections

# 查看特定集合信息
curl http://localhost:6333/collections/agent_ceo_001_memory
```

### 服务管理

```bash
# 启动 Qdrant
sudo systemctl start qdrant

# 停止 Qdrant
sudo systemctl stop qdrant

# 查看状态
sudo systemctl status qdrant

# 查看日志
sudo journalctl -u qdrant -f
```

## 最佳实践

### 1. 记忆分类

为不同类型的记忆设置合适的重要性：

```python
importance_map = {
    "critical_decision": 0.95,
    "strategic_planning": 0.9,
    "important_learning": 0.8,
    "routine_task": 0.5,
    "minor_detail": 0.3
}
```

### 2. 标签使用

使用描述性标签便于后续检索：

```python
tags = [
    "architecture",      # 主题
    "microservices",     # 技术
    "Q1_2024",          # 时间
    "team_decision"      # 来源
]
```

### 3. 定期维护

```python
# 每周执行一次记忆整合和清理
def weekly_maintenance(agent_id: str):
    service = VectorMemoryService()

    # 整合相似记忆
    consolidated = service.consolidate_memories(agent_id, time_window=168)

    # 清理旧记忆
    cleaned = service.cleanup_old_memories(agent_id, days=90)

    print(f"整合: {consolidated}, 清理: {cleaned}")
```

### 4. 性能优化

```python
# 使用批量操作
# 使用合适的 top_k 值（不要过大）
# 设置合理的 min_score 阈值
# 利用过滤条件减少搜索范围

memories = service.search_memory(
    agent_id="ceo_001",
    query="...",
    top_k=5,  # 适中的值
    min_score=0.7,  # 过滤低相关性结果
    filters={"type": "decision"}  # 缩小搜索范围
)
```

## 故障排除

### 问题1: Qdrant 服务无法启动

```bash
# 检查日志
sudo journalctl -u qdrant -n 50

# 检查端口占用
sudo lsof -i :6333

# 检查权限
ls -la /opt/openclaw/data/qdrant
```

### 问题2: 嵌入模型下载失败

```bash
# 手动下载模型
cd /opt/openclaw
source venv/bin/activate
python3 -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('BAAI/bge-large-zh-v1.5')"
```

### 问题3: 内存不足

```yaml
# 调整 Qdrant 配置
# /opt/openclaw/config/qdrant/config.yaml
storage:
  performance:
    max_segment_size_kb: 100000  # 减小
    memmap_threshold_kb: 50000   # 减小
```

### 问题4: 搜索速度慢

```python
# 优化搜索参数
# 1. 减少 top_k
# 2. 使用过滤条件
# 3. 调整 HNSW 参数

# 检查集合大小
stats = service.get_statistics(agent_id)
if stats['total_memories'] > 100000:
    # 考虑清理或归档旧记忆
    service.cleanup_old_memories(agent_id, days=60)
```

## 进阶应用

### 1. 多智能体协作记忆

```python
# 存储协作记忆
service.store_memory(
    agent_id="shared_knowledge",
    content="团队决定采用敏捷开发方法",
    metadata={
        "related_agents": ["ceo_001", "cto_001", "pm_001"],
        "type": "team_decision"
    }
)

# 查询团队记忆
team_memories = service.search_memory(
    agent_id="shared_knowledge",
    query="团队工作方法"
)
```

### 2. 记忆链

```python
# 创建相关记忆链
parent_memory_id = service.store_memory(
    agent_id="arch_001",
    content="决定使用微服务架构"
)

child_memory_id = service.store_memory(
    agent_id="be_dev_001",
    content="实现用户服务微服务",
    metadata={
        "parent_memory": parent_memory_id,
        "context": "基于架构决策的实现"
    }
)
```

### 3. 记忆重要性自动衰减

```python
from datetime import datetime, timedelta

def apply_time_decay(memory: MemoryDocument, decay_rate: float = 0.01):
    """应用时间衰减到记忆重要性"""
    days_old = (datetime.now() - memory.timestamp).days
    decayed_importance = memory.importance * (1 - decay_rate) ** days_old
    return max(decayed_importance, 0.1)  # 最小值 0.1
```

## 更多资源

- [Qdrant 官方文档](https://qdrant.tech/documentation/)
- [BGE 嵌入模型](https://huggingface.co/BAAI/bge-large-zh-v1.5)
- [Sentence Transformers](https://www.sbert.net/)
- [向量数据库设计文档](VECTOR_DATABASE_DESIGN.md)
