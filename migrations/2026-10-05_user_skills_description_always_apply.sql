-- Migració: afegeix description i always_apply a user_skills
-- Segura de re-executar (IF NOT EXISTS). No modifica ni esborra dades existents.

BEGIN;

ALTER TABLE user_skills
    ADD COLUMN IF NOT EXISTS description TEXT NULL;

ALTER TABLE user_skills
    ADD COLUMN IF NOT EXISTS always_apply BOOLEAN NOT NULL DEFAULT FALSE;

COMMIT;

-- Comprovació (ha de retornar 2 files):
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'user_skills' AND column_name IN ('description', 'always_apply');

-- ROLLBACK (només si cal desfer-ho; abans torna a la versió anterior del codi):
-- ALTER TABLE user_skills DROP COLUMN IF EXISTS always_apply;
-- ALTER TABLE user_skills DROP COLUMN IF EXISTS description;
