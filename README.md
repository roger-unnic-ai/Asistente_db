# Asistente DB - PostgreSQL Database

Base de datos PostgreSQL para Asistente IA con soporte RAG y gestión de documentos.

---

## 📊 Estructura de la Base de Datos

### 9 Tablas Principales:

#### 1. **users**
Gestión de usuarios con autenticación múltiple.
```sql
- id (PK)
- username (UNIQUE)
- email
- password_hash
- role (user/admin/responsable)
- allowed_models (JSONB array)
- google_id, microsoft_id
- sharepoint_access_token, sharepoint_refresh_token
- is_active
- created_at, updated_at
```

#### 2. **models**
Configuración de modelos de IA.
```sql
- id (PK)
- model_id (UNIQUE) → "general", "devs", etc.
- name, description
- is_default, is_active
- created_at, updated_at
```

#### 3. **user_model_access**
Control de acceso usuarios ↔ modelos (many-to-many).
```sql
- id (PK)
- user_id (FK → users)
- model_id (FK → models)
- granted_by (FK → users)
- granted_at
```

#### 4. **document_references**
Referencias a documentos externos (SharePoint, etc).
```sql
- id (PK)
- reference_id (UUID)
- model_id (FK → models)
- reference_type, name, path
- library_id, folder_path, file_id
- is_folder
- added_by (FK → users)
- added_at, last_synced_at
```

#### 5. **documents**
Almacenamiento de archivos en binario.
```sql
- id (PK)
- model_id (FK → models)
- filename (UNIQUE por model)
- content (BYTEA)
- mime_type, file_size
- uploaded_by (FK → users)
- uploaded_at
```

#### 6. **document_chunks**
Metadata de chunks para RAG (vectores en FAISS).
```sql
- id (PK)
- model_id (FK → models)
- document_reference_id (FK → document_references)
- chunk_text, source_document
- chunk_index, faiss_vector_index
- document_type
- chunk_metadata (JSONB)
- created_at
```

#### 7. **chat_threads**
Conversaciones de chat.
```sql
- id (PK)
- chat_id (UUID)
- user_id (FK → users)
- title
- model_id (FK → models)
- use_rag, use_deep_search
- created_at, updated_at
```

#### 8. **chat_messages**
Mensajes individuales en chats.
```sql
- id (PK)
- chat_thread_id (FK → chat_threads)
- role (user/assistant/system)
- content
- chunks_used (JSONB)
- semantic_query
- keywords (JSONB)
- created_at
```

#### 9. **unresolved_questions**
Preguntas pendientes de resolver.
```sql
- id (PK)
- question_id (UUID)
- user_id (FK → users)
- question_text, context
- chat_id (UUID), message_index
- model_id
- status (pending/resolved/dismissed)
- resolved_by (FK → users)
- resolved_at, resolution_notes
- created_at, updated_at
```

---

## 🚀 Deployment

### Desarrollo

```bash
# 1. Configurar variables de entorno
cat > .env.dev << EOF
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=asistente_db
EOF

# 2. Iniciar base de datos
docker-compose -f docker/docker-compose.dev.yml up -d

# 3. Verificar
docker ps | grep asistente_db
```

### Producción

```bash
# 1. Configurar variables seguras
cat > .env.prod << EOF
POSTGRES_USER=admin_user
POSTGRES_PASSWORD=tu_password_muy_seguro
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=asistente_db_prod
EOF

chmod 600 .env.prod

# 2. Cargar variables e iniciar
export $(cat .env.prod | xargs)
docker-compose -f docker/docker-compose.prod.yml up -d
```

---

## 🔧 Comandos Básicos

### Docker

```bash
# Ver estado
docker-compose -f docker/docker-compose.dev.yml ps

# Ver logs
docker logs -f asistente_db_dev

# Detener
docker-compose -f docker/docker-compose.dev.yml down

# Reiniciar desde cero (⚠️ elimina datos)
docker-compose -f docker/docker-compose.dev.yml down -v
docker-compose -f docker/docker-compose.dev.yml up -d --build
```

### PostgreSQL

```bash
# Conectar a la base de datos
docker exec -it asistente_db_dev psql -U postgres -d asistente_db

# Comandos útiles en psql:
\dt                    # Listar tablas
\d users              # Ver estructura de tabla
\q                    # Salir
```

### Backup y Restore

```bash
# Crear backup
docker exec -t asistente_db_dev pg_dump -U postgres asistente_db > backup.sql

# Restaurar
docker exec -i asistente_db_dev psql -U postgres asistente_db < backup.sql
```

---

## 🐍 Uso desde Python

### Instalación

```bash
pip install sqlalchemy psycopg2-binary python-dotenv
```

### Ejemplo Básico

```python
from db import get_db, User, Model, ChatThread

# Obtener sesión
db = next(get_db())

# Crear usuario
user = User(
    username="john",
    email="john@example.com",
    role="user",
    allowed_models=["general"]
)
db.add(user)
db.commit()

# Consultar
users = db.query(User).filter(User.is_active == True).all()

db.close()
```

---

## 📁 Estructura del Proyecto

```
Asistente DB/
├── docker/
│   ├── docker-compose.dev.yml
│   ├── docker-compose.prod.yml
│   └── postgres/
│       ├── Dockerfile
│       └── init.sql
├── db/
│   ├── __init__.py
│   ├── database.py
│   └── models.py
├── .env.dev
├── .env.prod
├── .gitignore
├── requirements.txt
├── recreate_db.sh
└── README.md
```

---

## ⚙️ Configuración

- **PostgreSQL**: 16-alpine
- **Encoding**: UTF-8
- **Timezone**: UTC
- **Connection Pool**: 10 conexiones (configurable)
- **Índices**: 40+ para búsquedas optimizadas

---

## 🔒 Seguridad (Producción)

- No exponer puerto 5432 al host
- Usar passwords seguros (mínimo 20 caracteres)
- Guardar .env.prod fuera de git
- Conexión solo desde red interna Docker
- Backups regulares automáticos

---

## 📝 Notas

- Los vectores FAISS se almacenan en archivos separados (.index, .npy)
- La tabla `document_chunks` solo guarda metadata de los chunks
- `allowed_models` es un array JSONB para acceso rápido
- Todos los timestamps usan timezone (TIMESTAMPTZ)
