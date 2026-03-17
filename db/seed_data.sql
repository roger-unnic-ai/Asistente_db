-- ============================================
-- Seed Data for Asistente DB
-- Optional: Run this to populate database with initial data
-- ============================================

-- Note: This script can be added to the init.sql or run separately
-- Run with: docker exec -i asistente_db_dev psql -U postgres -d asistente_db < db/seed_data.sql

BEGIN;

-- ============================================
-- 1. Create default admin user
-- ============================================
INSERT INTO users (username, email, password_hash, role, is_active)
VALUES 
    ('admin', 'admin@asistente.com', 'change_this_password_hash', 'admin', TRUE),
    ('demo_user', 'demo@asistente.com', 'change_this_password_hash', 'user', TRUE)
ON CONFLICT (username) DO NOTHING;

-- ============================================
-- 2. Create default models
-- ============================================
INSERT INTO models (model_id, name, description, is_default, is_active)
VALUES 
    ('general', 'Personal', 'Asistente general para todos los usuarios', TRUE, TRUE),
    ('devs', 'Developers', 'Asistente especializado para desarrolladores', FALSE, TRUE),
    ('hr', 'Human Resources', 'Asistente para recursos humanos', FALSE, TRUE),
    ('sales', 'Sales', 'Asistente para equipo de ventas', FALSE, TRUE)
ON CONFLICT (model_id) DO NOTHING;

-- ============================================
-- 3. Grant default model access to all users
-- ============================================
-- Give all users access to the general model
INSERT INTO user_model_access (user_id, model_id, granted_by)
SELECT 
    u.id,
    m.id,
    (SELECT id FROM users WHERE role = 'admin' LIMIT 1)
FROM users u
CROSS JOIN models m
WHERE m.model_id = 'general'
  AND NOT EXISTS (
      SELECT 1 FROM user_model_access uma 
      WHERE uma.user_id = u.id AND uma.model_id = m.id
  );

-- ============================================
-- 4. Create example document references
-- ============================================
-- Note: Adjust these based on your actual SharePoint structure
INSERT INTO document_references (
    model_id, 
    reference_type, 
    name, 
    path, 
    is_folder,
    added_by
)
SELECT 
    m.id,
    'sharepoint',
    'Documentos Corporativos',
    '/sites/company/documents',
    TRUE,
    (SELECT id FROM users WHERE role = 'admin' LIMIT 1)
FROM models m
WHERE m.model_id = 'general'
ON CONFLICT DO NOTHING;

COMMIT;

-- ============================================
-- Verify seed data
-- ============================================
-- Run these queries to verify:
-- SELECT * FROM users;
-- SELECT * FROM models;
-- SELECT * FROM user_model_access;
-- SELECT * FROM document_references;
