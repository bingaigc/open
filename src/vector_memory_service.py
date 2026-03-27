"""
向量记忆服务 - Vector Memory Service

为 OpenClaw 智能体提供基于向量数据库的记忆存储和检索能力。
支持语义搜索、记忆整合、重要性评分等功能。

安全提示: 需要 qdrant-client >= 1.9.0 以修复输入验证漏洞

Author: OpenClaw Team
License: MIT
"""

import os
import logging
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Any
from dataclasses import dataclass, field, asdict
from enum import Enum

import yaml
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance, VectorParams, PointStruct,
    Filter, FieldCondition, Range, MatchValue
)
from sentence_transformers import SentenceTransformer

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class MemoryType(Enum):
    """记忆类型"""
    EXPERIENCE = "experience"      # 经验
    KNOWLEDGE = "knowledge"        # 知识
    DECISION = "decision"          # 决策
    CONVERSATION = "conversation"  # 对话
    TASK = "task"                  # 任务
    INSIGHT = "insight"            # 洞察


class MemoryCategory(Enum):
    """记忆分类"""
    TECHNICAL = "technical"        # 技术
    BUSINESS = "business"          # 业务
    PERSONAL = "personal"          # 个人
    STRATEGIC = "strategic"        # 战略
    OPERATIONAL = "operational"    # 运营


class MemoryStatus(Enum):
    """记忆状态"""
    ACTIVE = "active"              # 活跃
    ARCHIVED = "archived"          # 归档
    DEPRECATED = "deprecated"      # 已弃用


@dataclass
class MemoryDocument:
    """记忆文档数据结构"""
    id: str
    agent_id: str
    content: str
    embedding: List[float] = field(default_factory=list)
    type: str = MemoryType.EXPERIENCE.value
    category: str = MemoryCategory.TECHNICAL.value
    importance: float = 0.5
    timestamp: datetime = field(default_factory=datetime.now)
    source: str = "user_input"
    tags: List[str] = field(default_factory=list)
    context: str = ""
    related_agents: List[str] = field(default_factory=list)
    access_count: int = 0
    last_accessed: Optional[datetime] = None
    confidence: float = 1.0
    status: str = MemoryStatus.ACTIVE.value

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        data = asdict(self)
        data['timestamp'] = self.timestamp.isoformat()
        if self.last_accessed:
            data['last_accessed'] = self.last_accessed.isoformat()
        return data

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'MemoryDocument':
        """从字典创建"""
        if 'timestamp' in data and isinstance(data['timestamp'], str):
            data['timestamp'] = datetime.fromisoformat(data['timestamp'])
        if 'last_accessed' in data and isinstance(data['last_accessed'], str):
            data['last_accessed'] = datetime.fromisoformat(data['last_accessed'])
        return cls(**data)


class VectorMemoryService:
    """向量记忆服务"""

    def __init__(self, config_path: Optional[str] = None):
        """
        初始化向量记忆服务

        Args:
            config_path: 配置文件路径
        """
        self.config = self._load_config(config_path)
        self.client = self._init_client()
        self.embedding_model = self._init_embedding_model()
        self._ensure_collections()

    def _load_config(self, config_path: Optional[str] = None) -> Dict[str, Any]:
        """加载配置"""
        if config_path is None:
            config_path = os.environ.get(
                'VECTOR_MEMORY_CONFIG',
                '/opt/openclaw/config/vector_memory.yaml'
            )

        if os.path.exists(config_path):
            with open(config_path, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)

        # 默认配置
        return {
            'vector_database': {
                'provider': 'qdrant',
                'connection': {
                    'host': 'localhost',
                    'port': 6333,
                    'grpc_port': 6334,
                    'timeout': 30
                },
                'collections': {
                    'default_config': {
                        'vector_size': 1024,
                        'distance': 'Cosine'
                    }
                },
                'embedding': {
                    'provider': 'local',
                    'model': 'BAAI/bge-large-zh-v1.5',
                    'batch_size': 32,
                    'device': 'cpu'
                }
            }
        }

    def _init_client(self) -> QdrantClient:
        """初始化 Qdrant 客户端"""
        conn_config = self.config['vector_database']['connection']

        try:
            client = QdrantClient(
                host=conn_config['host'],
                port=conn_config['port'],
                timeout=conn_config.get('timeout', 30)
            )
            logger.info(f"Connected to Qdrant at {conn_config['host']}:{conn_config['port']}")
            return client
        except Exception as e:
            logger.error(f"Failed to connect to Qdrant: {e}")
            raise

    def _init_embedding_model(self) -> SentenceTransformer:
        """初始化嵌入模型"""
        embedding_config = self.config['vector_database']['embedding']
        model_name = embedding_config['model']
        device = embedding_config.get('device', 'cpu')

        try:
            model = SentenceTransformer(model_name, device=device)
            logger.info(f"Loaded embedding model: {model_name}")
            return model
        except Exception as e:
            logger.error(f"Failed to load embedding model: {e}")
            raise

    def _ensure_collections(self):
        """确保必要的集合存在"""
        collections = self.client.get_collections().collections
        existing = {col.name for col in collections}

        # 创建共享知识库
        if 'shared_knowledge' not in existing:
            self._create_collection('shared_knowledge')

        # 创建智能体交互历史
        if 'agent_interactions' not in existing:
            self._create_collection('agent_interactions')

    def _create_collection(self, collection_name: str):
        """创建集合"""
        collection_config = self.config['vector_database']['collections']['default_config']

        try:
            self.client.create_collection(
                collection_name=collection_name,
                vectors_config=VectorParams(
                    size=collection_config['vector_size'],
                    distance=Distance.COSINE
                )
            )
            logger.info(f"Created collection: {collection_name}")
        except Exception as e:
            logger.warning(f"Collection {collection_name} may already exist: {e}")

    def _get_agent_collection_name(self, agent_id: str) -> str:
        """获取智能体的集合名称"""
        return f"agent_{agent_id}_memory"

    def _ensure_agent_collection(self, agent_id: str):
        """确保智能体集合存在"""
        collection_name = self._get_agent_collection_name(agent_id)
        collections = self.client.get_collections().collections
        existing = {col.name for col in collections}

        if collection_name not in existing:
            self._create_collection(collection_name)

    def _generate_embedding(self, text: str) -> List[float]:
        """生成文本嵌入向量"""
        try:
            embedding = self.embedding_model.encode(text, normalize_embeddings=True)
            return embedding.tolist()
        except Exception as e:
            logger.error(f"Failed to generate embedding: {e}")
            raise

    def store_memory(
        self,
        agent_id: str,
        content: str,
        metadata: Optional[Dict[str, Any]] = None,
        importance: float = 0.5
    ) -> str:
        """
        存储记忆

        Args:
            agent_id: 智能体ID
            content: 记忆内容
            metadata: 元数据
            importance: 重要性评分 (0.0-1.0)

        Returns:
            memory_id: 记忆ID
        """
        self._ensure_agent_collection(agent_id)

        # 生成嵌入向量
        embedding = self._generate_embedding(content)

        # 创建记忆文档
        memory_id = f"{agent_id}_{datetime.now().timestamp()}"
        memory_doc = MemoryDocument(
            id=memory_id,
            agent_id=agent_id,
            content=content,
            embedding=embedding,
            importance=importance,
            **(metadata or {})
        )

        # 存储到向量数据库
        collection_name = self._get_agent_collection_name(agent_id)
        payload = memory_doc.to_dict()
        payload.pop('embedding')  # 嵌入向量单独存储

        try:
            self.client.upsert(
                collection_name=collection_name,
                points=[
                    PointStruct(
                        id=memory_id,
                        vector=embedding,
                        payload=payload
                    )
                ]
            )
            logger.info(f"Stored memory {memory_id} for agent {agent_id}")
            return memory_id
        except Exception as e:
            logger.error(f"Failed to store memory: {e}")
            raise

    def search_memory(
        self,
        agent_id: str,
        query: str,
        top_k: int = 5,
        filters: Optional[Dict[str, Any]] = None,
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
        self._ensure_agent_collection(agent_id)
        collection_name = self._get_agent_collection_name(agent_id)

        # 生成查询嵌入
        query_embedding = self._generate_embedding(query)

        # 构建过滤条件
        query_filter = None
        if filters:
            conditions = []
            for key, value in filters.items():
                if isinstance(value, dict) and 'gte' in value:
                    conditions.append(
                        FieldCondition(
                            key=key,
                            range=Range(gte=value['gte'])
                        )
                    )
                else:
                    conditions.append(
                        FieldCondition(
                            key=key,
                            match=MatchValue(value=value)
                        )
                    )
            if conditions:
                query_filter = Filter(must=conditions)

        # 执行搜索
        try:
            results = self.client.search(
                collection_name=collection_name,
                query_vector=query_embedding,
                limit=top_k,
                query_filter=query_filter,
                score_threshold=min_score
            )

            memories = []
            for result in results:
                payload = result.payload
                payload['id'] = result.id
                payload['embedding'] = []  # 不返回嵌入向量
                memory = MemoryDocument.from_dict(payload)
                memories.append(memory)

                # 更新访问统计
                self._update_access_stats(agent_id, result.id)

            logger.info(f"Found {len(memories)} memories for query: {query[:50]}...")
            return memories
        except Exception as e:
            logger.error(f"Failed to search memories: {e}")
            return []

    def _update_access_stats(self, agent_id: str, memory_id: str):
        """更新记忆访问统计"""
        collection_name = self._get_agent_collection_name(agent_id)

        try:
            # 获取当前记忆
            result = self.client.retrieve(
                collection_name=collection_name,
                ids=[memory_id]
            )

            if result:
                payload = result[0].payload
                payload['access_count'] = payload.get('access_count', 0) + 1
                payload['last_accessed'] = datetime.now().isoformat()

                # 更新
                self.client.set_payload(
                    collection_name=collection_name,
                    payload=payload,
                    points=[memory_id]
                )
        except Exception as e:
            logger.warning(f"Failed to update access stats: {e}")

    def get_recent_memories(
        self,
        agent_id: str,
        hours: int = 24,
        limit: int = 10
    ) -> List[MemoryDocument]:
        """
        获取最近记忆

        Args:
            agent_id: 智能体ID
            hours: 时间范围（小时）
            limit: 返回数量

        Returns:
            memories: 记忆列表
        """
        self._ensure_agent_collection(agent_id)
        collection_name = self._get_agent_collection_name(agent_id)

        cutoff_time = datetime.now() - timedelta(hours=hours)

        try:
            # Qdrant 不直接支持时间范围查询，需要遍历或使用 scroll
            results = self.client.scroll(
                collection_name=collection_name,
                limit=limit * 2,  # 获取更多，然后过滤
                with_payload=True,
                with_vectors=False
            )[0]

            memories = []
            for point in results:
                payload = point.payload
                timestamp = datetime.fromisoformat(payload['timestamp'])

                if timestamp >= cutoff_time:
                    payload['id'] = point.id
                    payload['embedding'] = []
                    memory = MemoryDocument.from_dict(payload)
                    memories.append(memory)

            # 按时间排序
            memories.sort(key=lambda m: m.timestamp, reverse=True)
            return memories[:limit]

        except Exception as e:
            logger.error(f"Failed to get recent memories: {e}")
            return []

    def get_important_memories(
        self,
        agent_id: str,
        min_importance: float = 0.8,
        limit: int = 10
    ) -> List[MemoryDocument]:
        """
        获取重要记忆

        Args:
            agent_id: 智能体ID
            min_importance: 最小重要性
            limit: 返回数量

        Returns:
            memories: 记忆列表
        """
        self._ensure_agent_collection(agent_id)
        collection_name = self._get_agent_collection_name(agent_id)

        try:
            query_filter = Filter(
                must=[
                    FieldCondition(
                        key="importance",
                        range=Range(gte=min_importance)
                    )
                ]
            )

            results = self.client.scroll(
                collection_name=collection_name,
                scroll_filter=query_filter,
                limit=limit,
                with_payload=True,
                with_vectors=False
            )[0]

            memories = []
            for point in results:
                payload = point.payload
                payload['id'] = point.id
                payload['embedding'] = []
                memory = MemoryDocument.from_dict(payload)
                memories.append(memory)

            # 按重要性排序
            memories.sort(key=lambda m: m.importance, reverse=True)
            return memories

        except Exception as e:
            logger.error(f"Failed to get important memories: {e}")
            return []

    def update_memory(
        self,
        agent_id: str,
        memory_id: str,
        content: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        更新记忆

        Args:
            agent_id: 智能体ID
            memory_id: 记忆ID
            content: 新内容
            metadata: 新元数据

        Returns:
            success: 是否成功
        """
        collection_name = self._get_agent_collection_name(agent_id)

        try:
            # 获取现有记忆
            results = self.client.retrieve(
                collection_name=collection_name,
                ids=[memory_id]
            )

            if not results:
                logger.warning(f"Memory {memory_id} not found")
                return False

            payload = results[0].payload

            # 更新内容
            if content:
                payload['content'] = content
                # 重新生成嵌入
                new_embedding = self._generate_embedding(content)
                self.client.upsert(
                    collection_name=collection_name,
                    points=[
                        PointStruct(
                            id=memory_id,
                            vector=new_embedding,
                            payload=payload
                        )
                    ]
                )

            # 更新元数据
            if metadata:
                payload.update(metadata)
                self.client.set_payload(
                    collection_name=collection_name,
                    payload=payload,
                    points=[memory_id]
                )

            logger.info(f"Updated memory {memory_id}")
            return True

        except Exception as e:
            logger.error(f"Failed to update memory: {e}")
            return False

    def delete_memory(self, agent_id: str, memory_id: str) -> bool:
        """
        删除记忆

        Args:
            agent_id: 智能体ID
            memory_id: 记忆ID

        Returns:
            success: 是否成功
        """
        collection_name = self._get_agent_collection_name(agent_id)

        try:
            self.client.delete(
                collection_name=collection_name,
                points_selector=[memory_id]
            )
            logger.info(f"Deleted memory {memory_id}")
            return True

        except Exception as e:
            logger.error(f"Failed to delete memory: {e}")
            return False

    def consolidate_memories(
        self,
        agent_id: str,
        time_window: int = 24
    ) -> int:
        """
        记忆整合：合并相似记忆，提取关键信息

        Args:
            agent_id: 智能体ID
            time_window: 时间窗口（小时）

        Returns:
            consolidated_count: 整合的记忆数量
        """
        # 获取时间窗口内的记忆
        recent_memories = self.get_recent_memories(agent_id, time_window, limit=100)

        if len(recent_memories) < 2:
            return 0

        consolidated_count = 0
        # TODO: 实现记忆整合逻辑
        # 1. 计算记忆之间的相似度
        # 2. 合并高度相似的记忆
        # 3. 提取关键信息
        # 4. 更新或删除原记忆

        logger.info(f"Consolidated {consolidated_count} memories for agent {agent_id}")
        return consolidated_count

    def cleanup_old_memories(
        self,
        agent_id: str,
        days: int = 90,
        min_importance: float = 0.3
    ) -> int:
        """
        清理旧记忆

        Args:
            agent_id: 智能体ID
            days: 保留天数
            min_importance: 保留的最小重要性

        Returns:
            deleted_count: 删除数量
        """
        collection_name = self._get_agent_collection_name(agent_id)
        cutoff_time = datetime.now() - timedelta(days=days)

        try:
            results = self.client.scroll(
                collection_name=collection_name,
                limit=1000,
                with_payload=True,
                with_vectors=False
            )[0]

            to_delete = []
            for point in results:
                payload = point.payload
                timestamp = datetime.fromisoformat(payload['timestamp'])
                importance = payload.get('importance', 0.5)

                # 删除旧的且不重要的记忆
                if timestamp < cutoff_time and importance < min_importance:
                    to_delete.append(point.id)

            if to_delete:
                self.client.delete(
                    collection_name=collection_name,
                    points_selector=to_delete
                )

            logger.info(f"Cleaned up {len(to_delete)} old memories")
            return len(to_delete)

        except Exception as e:
            logger.error(f"Failed to cleanup memories: {e}")
            return 0

    def get_statistics(self, agent_id: str) -> Dict[str, Any]:
        """
        获取记忆统计信息

        Args:
            agent_id: 智能体ID

        Returns:
            stats: 统计信息
        """
        collection_name = self._get_agent_collection_name(agent_id)

        try:
            collection_info = self.client.get_collection(collection_name)

            stats = {
                'total_memories': collection_info.points_count,
                'vector_size': collection_info.config.params.vectors.size,
                'distance': collection_info.config.params.vectors.distance,
            }

            return stats

        except Exception as e:
            logger.error(f"Failed to get statistics: {e}")
            return {}


# 使用示例
if __name__ == "__main__":
    # 初始化服务
    service = VectorMemoryService()

    # 存储记忆
    memory_id = service.store_memory(
        agent_id="ceo_001",
        content="我们决定采用微服务架构来重构现有系统，预计需要3个月时间",
        metadata={
            "type": MemoryType.DECISION.value,
            "category": MemoryCategory.TECHNICAL.value,
            "importance": 0.9,
            "tags": ["architecture", "refactoring", "microservices"],
            "context": "2024年Q1技术规划会议"
        }
    )

    print(f"Stored memory: {memory_id}")

    # 搜索记忆
    memories = service.search_memory(
        agent_id="ceo_001",
        query="系统架构相关的重要决策",
        top_k=5
    )

    print(f"\nFound {len(memories)} memories:")
    for memory in memories:
        print(f"  [{memory.importance:.2f}] {memory.content[:50]}...")

    # 获取统计信息
    stats = service.get_statistics("ceo_001")
    print(f"\nStatistics: {stats}")
