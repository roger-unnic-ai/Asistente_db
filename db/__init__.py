"""
Database package initialization
"""

from db.database import Base, engine, SessionLocal, get_db, init_db, test_connection
from db.models import (
    User, Model, UserModelAccess, DocumentReference, Document, DocumentChunk,
    ChatThread, ChatMessage, UnresolvedQuestion,
    UserRole, MessageRole, QuestionStatus
)

__all__ = [
    # Database
    "Base",
    "engine",
    "SessionLocal",
    "get_db",
    "init_db",
    "test_connection",
    # Models
    "User",
    "Model",
    "UserModelAccess",
    "DocumentReference",
    "Document",
    "DocumentChunk",
    "ChatThread",
    "ChatMessage",
    "UnresolvedQuestion",
    # Enums
    "UserRole",
    "MessageRole",
    "QuestionStatus",
]
