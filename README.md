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

#### Opción 1: Deployment Automático (Recomendado)

```bash
# 1. Clonar repositorio en el servidor
git clone https://github.com/TU_USUARIO/asistente-db.git
cd asistente-db

# 2. Ejecutar script de deployment
sudo ./deploy-prod.sh

# El script te pedirá que configures las contraseñas en docker/.env.prod
```

#### Opción 2: Deployment Manual

```bash
# 1. Clonar repositorio en el servidor
git clone https://github.com/TU_USUARIO/asistente-db.git
cd asistente-db

# 2. Crear archivo .env.prod en la carpeta docker/
cd docker
cp .env.prod.example .env.prod
nano .env.prod  # Editar y poner contraseñas seguras

# Ejemplo de contenido de .env.prod:
# POSTGRES_DB=asistente_db_prod
# POSTGRES_USER=admin_user
# POSTGRES_PASSWORD=tu_password_muy_seguro_aqui

# 3. Proteger el archivo de variables
chmod 600 .env.prod

# 4. Crear la red Docker (primera vez solamente)
docker network create asistente_network

# 5. Iniciar base de datos
docker-compose -f docker-compose.prod.yml up -d

# 6. Verificar
docker ps | grep asistente_db_prod
docker logs asistente_db_prod
```

**⚠️ Importante:** El archivo `.env.prod` debe estar en la carpeta `docker/` (mismo nivel que `docker-compose.prod.yml`)

**⚠️ Conexión desde tu Webapp:**

Si tu webapp también está en Docker en el mismo servidor:

```python
# En el .env de tu webapp:
DATABASE_URL=postgresql://admin_user:tu_password_muy_seguro@postgres:5432/asistente_db_prod
```

**Importante:** 
- El hostname es `postgres` (nombre del servicio en docker-compose)
- Ambos contenedores deben estar en la misma red Docker: `asistente_network`
- Añade a tu `docker-compose` de la webapp:

```yaml
networks:
  asistente_network:
    external: true
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
# DESARROLLO
# Crear backup
docker exec -t asistente_db_dev pg_dump -U postgres asistente_db > backup.sql

# Restaurar
docker exec -i asistente_db_dev psql -U postgres asistente_db < backup.sql

# PRODUCCIÓN
# Crear backup (usa las variables de .env.prod)
docker exec -t asistente_db_prod pg_dump -U admin_user asistente_db_prod > backup_prod_$(date +%Y%m%d_%H%M%S).sql

# Restaurar
docker exec -i asistente_db_prod psql -U admin_user asistente_db_prod < backup_prod_20260318.sql

# Backup automático en el contenedor (carpeta montada)
docker exec asistente_db_prod pg_dump -U admin_user asistente_db_prod > /backups/auto_backup_$(date +%Y%m%d).sql
```

---

## 🌐 Conexión desde tu Webapp (Producción)

### Paso 1: Asegurar la Red Docker

Tu `docker-compose.prod.yml` de la webapp debe incluir:

```yaml
services:
  webapp:
    # ... tu configuración ...
    networks:
      - asistente_network
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}

networks:
  asistente_network:
    external: true
```

### Paso 2: Iniciar en el Orden Correcto

```bash
# 1. Primero la base de datos (crea la red)
docker-compose -f docker/docker-compose.prod.yml up -d

# 2. Luego tu webapp (se conecta a la red existente)
docker-compose -f /ruta/a/tu/webapp/docker-compose.yml up -d
```

### Paso 3: Verificar Conexión

```bash
# Verificar que ambos estén en la misma red
docker network inspect asistente_network

# Debería mostrar:
# - postgres (asistente_db_prod)
# - tu_webapp_container
```

### Variables de Entorno para tu Webapp

```bash
# Opción 1: Usar la misma .env.prod
DATABASE_URL=postgresql://admin_user:tu_password_muy_seguro@postgres:5432/asistente_db_prod

# Opción 2: Variables separadas (más flexible)
POSTGRES_USER=admin_user
POSTGRES_PASSWORD=tu_password_muy_seguro
POSTGRES_HOST=postgres  # ⚠️ Importante: nombre del servicio
POSTGRES_PORT=5432
POSTGRES_DB=asistente_db_prod
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

- ✅ Puerto 5432 NO expuesto al host (solo `expose` interno)
- ✅ Conexión solo desde red interna Docker (`asistente_network`)
- ✅ Passwords seguros (mínimo 20 caracteres aleatorios)
- ✅ Archivo `.env.prod` excluido de git (.gitignore)
- ✅ `chmod 600` en archivos .env
- ✅ Backups regulares (carpeta `/backups` montada)
- ✅ Límites de recursos configurados (2GB RAM, 2 CPUs)
- ✅ Logs rotados automáticamente (diarios, max 100MB)

---

## 📝 Notas

- Los vectores FAISS se almacenan en archivos separados (.index, .npy)
- La tabla `document_chunks` solo guarda metadata de los chunks
- `allowed_models` es un array JSONB para acceso rápido
- Todos los timestamps usan timezone (TIMESTAMPTZ)
