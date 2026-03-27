# 向量数据库设计文档

## 概述

本文档描述了为 OpenClaw 智能体系统集成向量数据库的设计方案，用于增强智能体的记忆和知识检索能力。

## 架构设计

### 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                      智能体层                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ CEO      │  │ Backend  │  │ Security │  ... (20 agents) │
│  │ Agent    │  │ Dev Agent│  │ Agent    │                  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                  │
└───────┼────────────┼─────────────┼─────────────────────────┘
        │            │             │
        └────────────┴─────────────┘
                     │
┌────────────────────┼─────────────────────────────────────────┐
│              向量记忆服务层 (Vector Memory Service)           │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Memory Manager                                        │  │
│  │  - store_memory()      存储记忆                        │  │
│  │  - search_memory()     语义搜索                        │  │
│  │  - update_memory()     更新记忆                        │  │
│  │  - delete_memory()     删除记忆                        │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────┼─────────────────────────────────────┐
│                  向量数据库层                                 │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │  ChromaDB  │  │  Milvus    │  │  Qdrant    │            │
│  │  (轻量级)   │  │  (大规模)   │  │  (平衡)    │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│                                                              │
│  选择标准：                                                   │
│  - ChromaDB: < 1M 向量，本地开发                            │
│  - Qdrant: 1M-10M 向量，生产环境推荐                        │
│  - Milvus: > 10M 向量，大规模部署                           │
└─────────────────────────────────────────────────────────────┘
```

## 技术选型

### 推荐方案：Qdrant

**优势**:
- 高性能：支持 HNSW 索引，查询速度快
- 易部署：单二进制文件，Docker 支持完善
- 功能完整：支持过滤、多租户、负载均衡
- 内存友好：支持磁盘存储和内存映射
- API 友好：RESTful 和 gRPC 接口
- 开源免费：Apache 2.0 许可证

**配置建议**:
```yaml
qdrant:
  version: "1.7.0"
  storage:
    path: "/opt/openclaw/data/qdrant"
    performance:
      max_segment_size_kb: 200000
      memmap_threshold_kb: 100000
  service:
    host: "localhost"
    port: 6333
    grpc_port: 6334
  resources:
    memory_limit: "4GB"
    cpu_limit: "2"
```

### 备选方案

#### 1. ChromaDB
**适用场景**: 小规模部署、开发测试
```yaml
chromadb:
  version: "0.4.22"
  persist_directory: "/opt/openclaw/data/chromadb"
  anonymized_telemetry: false
```

#### 2. Milvus
**适用场景**: 大规模部署、企业级应用
```yaml
milvus:
  version: "2.3.0"
  storage:
    minio_endpoint: "localhost:9000"
    etcd_endpoint: "localhost:2379"
```

## 向量嵌入模型

### 推荐模型

#### 1. 中文场景（推荐）
- **模型**: `BAAI/bge-large-zh-v1.5`
- **维度**: 1024
- **优势**: 中文语义理解能力强
- **性能**: 速度快，资源占用少

#### 2. 多语言场景
- **模型**: `sentence-transformers/paraphrase-multilingual-mpnet-base-v2`
- **维度**: 768
- **优势**: 支持 50+ 语言

#### 3. OpenAI Embeddings（云端）
- **模型**: `text-embedding-3-large`
- **维度**: 3072 (可调)
- **优势**: 质量最高，但需要 API 密钥

## 数据模型

### 记忆文档结构

```python
class MemoryDocument:
    """记忆文档数据结构"""

    id: str                      # 唯一标识
    agent_id: str                # 所属智能体ID
    content: str                 # 记忆内容
    embedding: List[float]       # 向量嵌入
    metadata: dict = {
        "type": str,             # 类型：experience, knowledge, decision
        "category": str,         # 分类：technical, business, personal
        "importance": float,     # 重要性: 0.0-1.0
        "timestamp": datetime,   # 创建时间
        "source": str,           # 来源：user_input, self_generated, learned
        "tags": List[str],       # 标签列表
        "context": str,          # 上下文信息
        "related_agents": List[str],  # 相关智能体
        "access_count": int,     # 访问次数
        "last_accessed": datetime,    # 最后访问时间
        "confidence": float,     # 置信度
        "status": str,           # 状态：active, archived, deprecated
    }
```

### 集合（Collection）设计

每个智能体有独立的集合：

```
collections/
├── agent_ceo_001_memory        # CEO 智能体记忆
├── agent_be_dev_001_memory     # 后端开发智能体记忆
├── agent_sec_001_memory        # 安全专家智能体记忆
├── shared_knowledge            # 共享知识库
└── agent_interactions          # 智能体交互历史
```

## API 设计

### 记忆服务 API

```python
class VectorMemoryService:
    """向量记忆服务"""

    def store_memory(
        self,
        agent_id: str,
        content: str,
        metadata: dict,
        importance: float = 0.5
    ) -> str:
        """
        存储记忆

        Args:
            agent_id: 智能体ID
            content: 记忆内容
            metadata: 元数据
            importance: 重要性评分

        Returns:
            memory_id: 记忆ID
        """
        pass

    def search_memory(
        self,
        agent_id: str,
        query: str,
        top_k: int = 5,
        filters: dict = None,
        min_score: float = 0.7
    ) -> List[MemoryDocument]:
        """
        语义搜索记忆

        Args:
            agent_id: 智能体ID
            query: 查询文本
            top_k: 返回结果数量
            filters: 过滤条件
            min_score: 最小相似度分数

        Returns:
            memories: 记忆列表（按相关性排序）
        """
        pass

    def get_recent_memories(
        self,
        agent_id: str,
        hours: int = 24,
        limit: int = 10
    ) -> List[MemoryDocument]:
        """获取最近记忆"""
        pass

    def get_important_memories(
        self,
        agent_id: str,
        min_importance: float = 0.8,
        limit: int = 10
    ) -> List[MemoryDocument]:
        """获取重要记忆"""
        pass

    def update_memory(
        self,
        memory_id: str,
        content: str = None,
        metadata: dict = None
    ) -> bool:
        """更新记忆"""
        pass

    def delete_memory(
        self,
        memory_id: str
    ) -> bool:
        """删除记忆"""
        pass

    def consolidate_memories(
        self,
        agent_id: str,
        time_window: int = 24
    ) -> int:
        """
        记忆整合：合并相似记忆，提取关键信息

        Returns:
            consolidated_count: 整合的记忆数量
        """
        pass
```

## 部署配置

### Docker Compose 配置

```yaml
version: '3.8'

services:
  qdrant:
    image: qdrant/qdrant:v1.7.0
    container_name: openclaw-qdrant
    ports:
      - "6333:6333"    # HTTP API
      - "6334:6334"    # gRPC API
    volumes:
      - /opt/openclaw/data/qdrant:/qdrant/storage
    environment:
      - QDRANT__SERVICE__GRPC_PORT=6334
      - QDRANT__SERVICE__HTTP_PORT=6333
    restart: unless-stopped
    networks:
      - openclaw-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6333/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2'

  # 嵌入模型服务（可选，用于本地嵌入）
  embedding-service:
    image: huggingface/text-embeddings-inference:latest
    container_name: openclaw-embedding
    ports:
      - "8081:80"
    environment:
      - MODEL_ID=BAAI/bge-large-zh-v1.5
      - MAX_BATCH_SIZE=32
      - MAX_CONCURRENT_REQUESTS=128
    volumes:
      - /opt/openclaw/models:/data
    restart: unless-stopped
    networks:
      - openclaw-network
    deploy:
      resources:
        limits:
          memory: 8G
          cpus: '4'

networks:
  openclaw-network:
    driver: bridge

volumes:
  qdrant-storage:
  model-cache:
```

### 原生部署（无 Docker）

```bash
# 安装 Qdrant
cd /opt/openclaw
wget https://github.com/qdrant/qdrant/releases/download/v1.7.0/qdrant-x86_64-unknown-linux-gnu.tar.gz
tar xzf qdrant-x86_64-unknown-linux-gnu.tar.gz
mv qdrant /usr/local/bin/

# 创建配置文件
mkdir -p /opt/openclaw/config/qdrant
cat > /opt/openclaw/config/qdrant/config.yaml << 'EOF'
service:
  host: 0.0.0.0
  http_port: 6333
  grpc_port: 6334

storage:
  storage_path: /opt/openclaw/data/qdrant
  performance:
    max_segment_size_kb: 200000

telemetry_disabled: true
EOF

# 创建 systemd 服务
cat > /etc/systemd/system/qdrant.service << 'EOF'
[Unit]
Description=Qdrant Vector Database
After=network.target

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/opt/openclaw
ExecStart=/usr/local/bin/qdrant --config-path /opt/openclaw/config/qdrant/config.yaml
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable qdrant
systemctl start qdrant
```

## Python 客户端配置

### 依赖安装

```bash
pip install qdrant-client sentence-transformers
```

### 配置文件

```yaml
# /opt/openclaw/config/vector_memory.yaml
vector_database:
  provider: "qdrant"
  connection:
    host: "localhost"
    port: 6333
    grpc_port: 6334
    api_key: null  # 可选，生产环境建议设置
    https: false
    timeout: 30

  collections:
    default_config:
      vector_size: 1024
      distance: "Cosine"  # Cosine, Euclidean, Dot
      on_disk_payload: true

  embedding:
    provider: "local"  # local, openai, huggingface
    model: "BAAI/bge-large-zh-v1.5"
    batch_size: 32
    device: "cpu"  # cpu, cuda

  performance:
    search_batch_size: 100
    max_retries: 3
    connection_pool_size: 10

  memory_management:
    auto_consolidate: true
    consolidate_interval: 86400  # 24小时
    max_memory_age_days: 90
    importance_decay_rate: 0.01
```

## 使用示例

### 基本使用

```python
from vector_memory_service import VectorMemoryService

# 初始化服务
memory_service = VectorMemoryService(
    config_path="/opt/openclaw/config/vector_memory.yaml"
)

# 存储记忆
memory_id = memory_service.store_memory(
    agent_id="ceo_001",
    content="我们决定采用微服务架构来重构现有系统，预计需要3个月时间",
    metadata={
        "type": "decision",
        "category": "technical",
        "importance": 0.9,
        "tags": ["architecture", "refactoring", "microservices"],
        "context": "2024年Q1技术规划会议"
    }
)

# 搜索相关记忆
memories = memory_service.search_memory(
    agent_id="ceo_001",
    query="系统架构相关的重要决策",
    top_k=5,
    filters={
        "type": "decision",
        "importance": {"gte": 0.7}
    }
)

for memory in memories:
    print(f"[{memory.metadata['importance']:.2f}] {memory.content}")
    print(f"  时间: {memory.metadata['timestamp']}")
    print(f"  标签: {', '.join(memory.metadata['tags'])}")
    print()
```

### 智能体集成

```python
class Agent:
    def __init__(self, agent_id: str):
        self.agent_id = agent_id
        self.memory = VectorMemoryService()

    def remember(self, content: str, importance: float = 0.5, **metadata):
        """存储记忆"""
        return self.memory.store_memory(
            agent_id=self.agent_id,
            content=content,
            metadata=metadata,
            importance=importance
        )

    def recall(self, query: str, limit: int = 5):
        """回忆相关记忆"""
        return self.memory.search_memory(
            agent_id=self.agent_id,
            query=query,
            top_k=limit
        )

    def process_task(self, task: str):
        # 回忆相关经验
        relevant_memories = self.recall(task)

        # 基于记忆处理任务
        context = "\n".join([m.content for m in relevant_memories])
        result = self.execute_with_context(task, context)

        # 存储新经验
        self.remember(
            content=f"处理任务 '{task}': {result}",
            importance=0.6,
            type="experience",
            tags=["task_execution"]
        )

        return result
```

## 性能优化

### 索引优化

```python
# 创建集合时的优化配置
collection_config = {
    "vectors": {
        "size": 1024,
        "distance": "Cosine"
    },
    "optimizers_config": {
        "memmap_threshold": 100000,  # 100MB
        "indexing_threshold": 20000
    },
    "hnsw_config": {
        "m": 16,              # 每个节点的连接数
        "ef_construct": 100,  # 构建时的搜索范围
        "full_scan_threshold": 10000
    }
}
```

### 缓存策略

```python
from functools import lru_cache

@lru_cache(maxsize=1000)
def get_embedding(text: str) -> List[float]:
    """缓存常用文本的嵌入向量"""
    return embedding_model.encode(text)
```

### 批量操作

```python
# 批量插入
memory_service.store_memories_batch([
    {
        "agent_id": "ceo_001",
        "content": content,
        "metadata": metadata
    }
    for content, metadata in memory_list
])

# 批量搜索
results = memory_service.search_memories_batch([
    {"agent_id": "ceo_001", "query": query1},
    {"agent_id": "cto_001", "query": query2}
])
```

## 监控和维护

### 健康检查

```bash
# 检查 Qdrant 服务状态
curl http://localhost:6333/health

# 查看集合信息
curl http://localhost:6333/collections
```

### 监控指标

```python
metrics = {
    "total_memories": 0,        # 总记忆数
    "memories_per_agent": {},   # 每个智能体的记忆数
    "avg_search_latency": 0,    # 平均搜索延迟
    "storage_size_mb": 0,       # 存储大小
    "cache_hit_rate": 0,        # 缓存命中率
}
```

### 备份和恢复

```bash
# 备份向量数据库
rsync -av /opt/openclaw/data/qdrant/ /opt/openclaw/backups/qdrant_$(date +%Y%m%d)/

# 恢复
systemctl stop qdrant
rsync -av /opt/openclaw/backups/qdrant_20240327/ /opt/openclaw/data/qdrant/
systemctl start qdrant
```

## 安全考虑

### 访问控制

```yaml
# Qdrant API 密钥认证
security:
  api_key: "${QDRANT_API_KEY}"

# Nginx 反向代理
location /vector-db/ {
    auth_request /auth;
    proxy_pass http://localhost:6333/;
}
```

### 数据加密

```yaml
# 存储加密（文件系统级别）
encryption:
  at_rest: true
  method: "LUKS"

# 传输加密
tls:
  enabled: true
  cert: "/etc/ssl/certs/qdrant.crt"
  key: "/etc/ssl/private/qdrant.key"
```

## 故障排除

### 常见问题

1. **内存不足**
   ```bash
   # 调整 Qdrant 内存限制
   # 修改 systemd 服务文件
   Environment="QDRANT__STORAGE__PERFORMANCE__MAX_MEMORY_MB=4096"
   ```

2. **搜索速度慢**
   ```python
   # 优化 HNSW 参数
   client.update_collection(
       collection_name="memories",
       hnsw_config={"ef": 128}  # 增加搜索精度
   )
   ```

3. **磁盘空间不足**
   ```bash
   # 清理旧记忆
   memory_service.cleanup_old_memories(days=90)
   ```

## 最佳实践

1. **记忆分类**: 使用明确的类型和标签
2. **重要性评分**: 合理设置记忆的重要性
3. **定期整合**: 自动合并相似记忆
4. **适度遗忘**: 删除或归档过时记忆
5. **监控性能**: 定期检查搜索延迟和存储使用
6. **备份策略**: 定期备份向量数据库

## 未来扩展

- [ ] 多模态记忆（图像、音频）
- [ ] 跨智能体记忆共享机制
- [ ] 记忆重要性自动评估
- [ ] 长期记忆压缩算法
- [ ] 联邦学习支持
- [ ] 记忆可视化界面

## 参考资源

- Qdrant 文档: https://qdrant.tech/documentation/
- Sentence Transformers: https://www.sbert.net/
- BGE 模型: https://huggingface.co/BAAI/bge-large-zh-v1.5
