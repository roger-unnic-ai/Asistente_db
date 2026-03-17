"""
SQLAlchemy Models for Asistente DB
All database tables and relationships
"""

from sqlalchemy import (
    Column, Integer, String, Text, Boolean, ForeignKey, 
    TIMESTAMP, CheckConstraint, UniqueConstraint, Enum as SQLEnum,
    LargeBinary
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid
import enum

from db.database import Base


# ============================================
# Enums
# ============================================

class UserRole(str, enum.Enum):
    """User role enumeration"""
    USER = "user"
    ADMIN = "admin"
    RESPONSABLE = "responsable"


class MessageRole(str, enum.Enum):
    """Chat message role enumeration"""
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"


class QuestionStatus(str, enum.Enum):
    """Unresolved question status enumeration"""
    PENDING = "pending"
    RESOLVED = "resolved"
    DISMISSED = "dismissed"


# ============================================
# 1. USERS TABLE
# ============================================

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(100), unique=True, nullable=False, index=True)
    email = Column(String(255), nullable=False, index=True)
    password_hash = Column(String(255))
    role = Column(
        String(20),
        nullable=False,
        default="user"
    )
    allowed_models = Column(JSONB, default=list)
    google_id = Column(String(255), index=True)
    microsoft_id = Column(String(255), index=True)
    sharepoint_access_token = Column(Text)
    sharepoint_refresh_token = Column(Text)
    sharepoint_token_expires_at = Column(TIMESTAMP(timezone=True))
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    model_accesses = relationship("UserModelAccess", back_populates="user", foreign_keys="[UserModelAccess.user_id]")
    chat_threads = relationship("ChatThread", back_populates="user", cascade="all, delete-orphan")
    unresolved_questions = relationship("UnresolvedQuestion", back_populates="user", foreign_keys="[UnresolvedQuestion.user_id]")
    document_references_added = relationship("DocumentReference", back_populates="added_by_user")
    uploaded_documents = relationship("Document", back_populates="uploaded_by_user")
    granted_accesses = relationship("UserModelAccess", back_populates="granted_by_user", foreign_keys="[UserModelAccess.granted_by]")
    resolved_questions = relationship("UnresolvedQuestion", back_populates="resolved_by_user", foreign_keys="[UnresolvedQuestion.resolved_by]")
    
    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}', role='{self.role}')>"


# ============================================
# 2. MODELS TABLE
# ============================================

class Model(Base):
    __tablename__ = "models"
    
    id = Column(Integer, primary_key=True, index=True)
    model_id = Column(String(100), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    is_default = Column(Boolean, default=False, index=True)
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    user_accesses = relationship("UserModelAccess", back_populates="model", cascade="all, delete-orphan")
    document_references = relationship("DocumentReference", back_populates="model", cascade="all, delete-orphan")
    documents = relationship("Document", back_populates="model", cascade="all, delete-orphan")
    document_chunks = relationship("DocumentChunk", back_populates="model", cascade="all, delete-orphan")
    chat_threads = relationship("ChatThread", back_populates="model")
    
    def __repr__(self):
        return f"<Model(id={self.id}, model_id='{self.model_id}', name='{self.name}')>"


# ============================================
# 3. USER_MODEL_ACCESS TABLE (Many-to-Many)
# ============================================

class UserModelAccess(Base):
    __tablename__ = "user_model_access"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    model_id = Column(Integer, ForeignKey("models.id", ondelete="CASCADE"), nullable=False, index=True)
    granted_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    granted_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), index=True)
    
    __table_args__ = (
        UniqueConstraint('user_id', 'model_id', name='unique_user_model'),
    )
    
    # Relationships
    user = relationship("User", back_populates="model_accesses", foreign_keys=[user_id])
    model = relationship("Model", back_populates="user_accesses")
    granted_by_user = relationship("User", back_populates="granted_accesses", foreign_keys=[granted_by])
    
    def __repr__(self):
        return f"<UserModelAccess(user_id={self.user_id}, model_id={self.model_id})>"


# ============================================
# 4. DOCUMENT_REFERENCES TABLE
# ============================================

class DocumentReference(Base):
    __tablename__ = "document_references"
    
    id = Column(Integer, primary_key=True, index=True)
    reference_id = Column(UUID(as_uuid=True), default=uuid.uuid4, unique=True, nullable=False, index=True)
    model_id = Column(Integer, ForeignKey("models.id", ondelete="CASCADE"), nullable=False, index=True)
    reference_type = Column(String(50), default="sharepoint", index=True)
    name = Column(String(255), nullable=False)
    path = Column(Text)
    library_id = Column(String(255))
    folder_path = Column(Text)
    file_id = Column(String(255), index=True)
    is_folder = Column(Boolean, default=False)
    added_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), index=True)
    added_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    last_synced_at = Column(TIMESTAMP(timezone=True))
    
    # Relationships
    model = relationship("Model", back_populates="document_references")
    added_by_user = relationship("User", back_populates="document_references_added")
    chunks = relationship("DocumentChunk", back_populates="document_reference")
    
    def __repr__(self):
        return f"<DocumentReference(id={self.id}, name='{self.name}', type='{self.reference_type}')>"


# ============================================
# 5. DOCUMENTS TABLE
# ============================================

class Document(Base):
    __tablename__ = "documents"
    
    id = Column(Integer, primary_key=True, index=True)
    model_id = Column(Integer, ForeignKey("models.id", ondelete="CASCADE"), nullable=False, index=True)
    filename = Column(String(255), nullable=False, index=True)
    original_path = Column(Text)
    content = Column(LargeBinary, nullable=False)
    mime_type = Column(String(100))
    file_size = Column(Integer)
    uploaded_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), index=True)
    uploaded_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    __table_args__ = (
        UniqueConstraint('model_id', 'filename', name='unique_model_filename'),
    )
    
    # Relationships
    model = relationship("Model", back_populates="documents")
    uploaded_by_user = relationship("User", back_populates="uploaded_documents")
    
    def __repr__(self):
        return f"<Document(id={self.id}, filename='{self.filename}', size={self.file_size})>"


# ============================================
# 6. DOCUMENT_CHUNKS TABLE
# ============================================

class DocumentChunk(Base):
    __tablename__ = "document_chunks"
    
    id = Column(Integer, primary_key=True, index=True)
    model_id = Column(Integer, ForeignKey("models.id", ondelete="CASCADE"), nullable=False, index=True)
    document_reference_id = Column(Integer, ForeignKey("document_references.id", ondelete="SET NULL"), index=True)
    chunk_text = Column(Text, nullable=False)
    source_document = Column(String(500), index=True)
    chunk_index = Column(Integer, nullable=False)
    faiss_vector_index = Column(Integer, index=True)
    document_type = Column(String(100))
    chunk_metadata = Column(JSONB)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # Relationships
    model = relationship("Model", back_populates="document_chunks")
    document_reference = relationship("DocumentReference", back_populates="chunks")
    
    def __repr__(self):
        return f"<DocumentChunk(id={self.id}, source='{self.source_document}', index={self.chunk_index})>"
    
    # Note: 'chunk_metadata' is used instead of 'metadata' 
    # because 'metadata' is reserved by SQLAlchemy


# ============================================
# 7. CHAT_THREADS TABLE
# ============================================

class ChatThread(Base):
    __tablename__ = "chat_threads"
    
    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(UUID(as_uuid=True), default=uuid.uuid4, unique=True, nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title = Column(String(500))
    model_id = Column(Integer, ForeignKey("models.id", ondelete="SET NULL"), index=True)
    use_rag = Column(Boolean, default=True)
    use_deep_search = Column(Boolean, default=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), index=True)
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="chat_threads")
    model = relationship("Model", back_populates="chat_threads")
    messages = relationship("ChatMessage", back_populates="chat_thread", cascade="all, delete-orphan", order_by="ChatMessage.created_at")
    
    def __repr__(self):
        return f"<ChatThread(id={self.id}, chat_id='{self.chat_id}', title='{self.title}')>"


# ============================================
# 7. CHAT_MESSAGES TABLE
# ============================================

class ChatMessage(Base):
    __tablename__ = "chat_messages"
    
    id = Column(Integer, primary_key=True, index=True)
    chat_thread_id = Column(Integer, ForeignKey("chat_threads.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(
        String(20),
        nullable=False,
        index=True
    )
    content = Column(Text, nullable=False)
    chunks_used = Column(JSONB)
    semantic_query = Column(Text)
    keywords = Column(JSONB)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), index=True)
    
    # Relationships
    chat_thread = relationship("ChatThread", back_populates="messages")
    
    def __repr__(self):
        return f"<ChatMessage(id={self.id}, role='{self.role}', chat_thread_id={self.chat_thread_id})>"


# ============================================
# 8. UNRESOLVED_QUESTIONS TABLE
# ============================================

class UnresolvedQuestion(Base):
    __tablename__ = "unresolved_questions"
    
    id = Column(Integer, primary_key=True, index=True)
    question_id = Column(UUID(as_uuid=True), default=uuid.uuid4, unique=True, nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    question_text = Column(Text, nullable=False)
    context = Column(Text)
    chat_id = Column(UUID(as_uuid=True), index=True)
    message_index = Column(Integer)
    model_id = Column(String(100), index=True)
    status = Column(
        String(20),
        default="pending",
        index=True
    )
    resolved_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), index=True)
    resolved_at = Column(TIMESTAMP(timezone=True))
    resolution_notes = Column(Text)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), index=True)
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="unresolved_questions", foreign_keys=[user_id])
    resolved_by_user = relationship("User", back_populates="resolved_questions", foreign_keys=[resolved_by])
    
    def __repr__(self):
        return f"<UnresolvedQuestion(id={self.id}, status='{self.status}', user_id={self.user_id})>"
