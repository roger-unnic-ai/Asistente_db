-- ============================================
-- Database Schema Initialization Script
-- PostgreSQL Database for Asistente DB
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. USERS TABLE
-- ============================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255),
    role VARCHAR(20) NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin', 'responsable')),
    allowed_models JSONB DEFAULT '[]'::jsonb,
    google_id VARCHAR(255),
    microsoft_id VARCHAR(255),
    sharepoint_access_token TEXT,
    sharepoint_refresh_token TEXT,
    sharepoint_token_expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for users table
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_google_id ON users(google_id);
CREATE INDEX idx_users_microsoft_id ON users(microsoft_id);
CREATE INDEX idx_users_is_active ON users(is_active);
CREATE INDEX idx_users_allowed_models ON users USING GIN (allowed_models);

-- ============================================
-- 2. MODELS TABLE
-- ============================================
CREATE TABLE models (
    id SERIAL PRIMARY KEY,
    model_id VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for models table
CREATE INDEX idx_models_model_id ON models(model_id);
CREATE INDEX idx_models_is_active ON models(is_active);
CREATE INDEX idx_models_is_default ON models(is_default);

-- ============================================
-- 3. USER_MODEL_ACCESS TABLE (Many-to-Many)
-- ============================================
CREATE TABLE user_model_access (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    model_id INTEGER NOT NULL REFERENCES models(id) ON DELETE CASCADE,
    granted_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    granted_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE(user_id, model_id)
);

-- Indexes for user_model_access table
CREATE INDEX idx_user_model_access_user_id ON user_model_access(user_id);
CREATE INDEX idx_user_model_access_model_id ON user_model_access(model_id);
CREATE INDEX idx_user_model_access_granted_by ON user_model_access(granted_by);

-- ============================================
-- 4. DOCUMENT_REFERENCES TABLE
-- ============================================
CREATE TABLE document_references (
    id SERIAL PRIMARY KEY,
    reference_id UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    model_id INTEGER NOT NULL REFERENCES models(id) ON DELETE CASCADE,
    reference_type VARCHAR(50) DEFAULT 'sharepoint',
    name VARCHAR(255) NOT NULL,
    path TEXT,
    library_id VARCHAR(255),
    folder_path TEXT,
    file_id VARCHAR(255),
    is_folder BOOLEAN DEFAULT FALSE,
    added_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    added_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_synced_at TIMESTAMPTZ
);

-- Indexes for document_references table
CREATE INDEX idx_document_references_reference_id ON document_references(reference_id);
CREATE INDEX idx_document_references_model_id ON document_references(model_id);
CREATE INDEX idx_document_references_reference_type ON document_references(reference_type);
CREATE INDEX idx_document_references_file_id ON document_references(file_id);
CREATE INDEX idx_document_references_added_by ON document_references(added_by);

-- ============================================
-- 5. DOCUMENTS TABLE
-- ============================================
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    model_id INTEGER NOT NULL REFERENCES models(id) ON DELETE CASCADE,
    filename VARCHAR(255) NOT NULL,
    original_path TEXT,
    content BYTEA NOT NULL,
    mime_type VARCHAR(100),
    file_size BIGINT,
    uploaded_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    uploaded_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(model_id, filename)
);

-- Indexes for documents table
CREATE INDEX idx_documents_model_id ON documents(model_id);
CREATE INDEX idx_documents_filename ON documents(filename);
CREATE INDEX idx_documents_uploaded_by ON documents(uploaded_by);

-- ============================================
-- 6. DOCUMENT_CHUNKS TABLE
-- ============================================
CREATE TABLE document_chunks (
    id SERIAL PRIMARY KEY,
    model_id INTEGER NOT NULL REFERENCES models(id) ON DELETE CASCADE,
    document_reference_id INTEGER REFERENCES document_references(id) ON DELETE SET NULL,
    chunk_text TEXT NOT NULL,
    source_document VARCHAR(500),
    chunk_index INTEGER NOT NULL,
    faiss_vector_index INTEGER,
    document_type VARCHAR(100),
    chunk_metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for document_chunks table
CREATE INDEX idx_document_chunks_model_id ON document_chunks(model_id);
CREATE INDEX idx_document_chunks_document_reference_id ON document_chunks(document_reference_id);
CREATE INDEX idx_document_chunks_source_document ON document_chunks(source_document);
CREATE INDEX idx_document_chunks_faiss_vector_index ON document_chunks(faiss_vector_index);
CREATE INDEX idx_document_chunks_chunk_metadata ON document_chunks USING GIN (chunk_metadata);

-- ============================================
-- 7. CHAT_THREADS TABLE
-- ============================================
CREATE TABLE chat_threads (
    id SERIAL PRIMARY KEY,
    chat_id UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(500),
    model_id INTEGER REFERENCES models(id) ON DELETE SET NULL,
    use_rag BOOLEAN DEFAULT TRUE,
    use_deep_search BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for chat_threads table
CREATE INDEX idx_chat_threads_chat_id ON chat_threads(chat_id);
CREATE INDEX idx_chat_threads_user_id ON chat_threads(user_id);
CREATE INDEX idx_chat_threads_model_id ON chat_threads(model_id);
CREATE INDEX idx_chat_threads_created_at ON chat_threads(created_at DESC);

-- ============================================
-- 8. CHAT_MESSAGES TABLE
-- ============================================
CREATE TABLE chat_messages (
    id SERIAL PRIMARY KEY,
    chat_thread_id INTEGER NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    chunks_used JSONB,
    semantic_query TEXT,
    keywords JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for chat_messages table
CREATE INDEX idx_chat_messages_chat_thread_id ON chat_messages(chat_thread_id);
CREATE INDEX idx_chat_messages_role ON chat_messages(role);
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at);
CREATE INDEX idx_chat_messages_chunks_used ON chat_messages USING GIN (chunks_used);

-- ============================================
-- 9. UNRESOLVED_QUESTIONS TABLE
-- ============================================
CREATE TABLE unresolved_questions (
    id SERIAL PRIMARY KEY,
    question_id UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    context TEXT,
    chat_id UUID,
    message_index INTEGER,
    model_id VARCHAR(100),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'dismissed')),
    resolved_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for unresolved_questions table
CREATE INDEX idx_unresolved_questions_question_id ON unresolved_questions(question_id);
CREATE INDEX idx_unresolved_questions_user_id ON unresolved_questions(user_id);
CREATE INDEX idx_unresolved_questions_status ON unresolved_questions(status);
CREATE INDEX idx_unresolved_questions_resolved_by ON unresolved_questions(resolved_by);
CREATE INDEX idx_unresolved_questions_created_at ON unresolved_questions(created_at DESC);
CREATE INDEX idx_unresolved_questions_chat_id ON unresolved_questions(chat_id);
CREATE INDEX idx_unresolved_questions_model_id ON unresolved_questions(model_id);

-- ============================================
-- Triggers for updated_at timestamps
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for users table
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger for models table
CREATE TRIGGER update_models_updated_at BEFORE UPDATE ON models
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger for chat_threads table
CREATE TRIGGER update_chat_threads_updated_at BEFORE UPDATE ON chat_threads
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger for unresolved_questions table
CREATE TRIGGER update_unresolved_questions_updated_at BEFORE UPDATE ON unresolved_questions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Comments for documentation
-- ============================================

COMMENT ON TABLE users IS 'Stores user accounts with authentication and SharePoint integration';
COMMENT ON TABLE models IS 'Stores AI models configuration (general, devs, etc.)';
COMMENT ON TABLE user_model_access IS 'Many-to-many relationship between users and models';
COMMENT ON TABLE document_references IS 'Stores references to SharePoint documents and folders';
COMMENT ON TABLE documents IS 'Stores uploaded documents content in binary format';
COMMENT ON TABLE document_chunks IS 'Stores document chunks metadata (vectors stored in FAISS)';
COMMENT ON TABLE chat_threads IS 'Stores chat conversation threads';
COMMENT ON TABLE chat_messages IS 'Stores individual messages within chat threads';
COMMENT ON TABLE unresolved_questions IS 'Stores questions that need admin attention';

-- ============================================
-- Grant permissions (adjust as needed)
-- ============================================

-- Note: In production, create specific users with limited permissions
-- Example: GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
