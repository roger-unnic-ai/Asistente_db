#!/bin/bash

# ===================================
# Script de Deployment para Producción
# ===================================

set -e  # Detener si hay errores

echo "🚀 Iniciando deployment de Asistente DB"
echo "========================================"
echo ""

# Verificar que estamos en la carpeta correcta
if [ ! -f "docker/docker-compose.prod.yml" ]; then
    echo "❌ Error: No se encuentra docker/docker-compose.prod.yml"
    echo "   Ejecuta este script desde la raíz del proyecto"
    exit 1
fi

# Verificar que existe .env.prod
if [ ! -f "docker/.env.prod" ]; then
    echo "⚠️  No se encuentra docker/.env.prod"
    echo ""
    echo "Creando desde el ejemplo..."
    
    if [ ! -f "docker/.env.prod.example" ]; then
        echo "❌ Error: Tampoco existe docker/.env.prod.example"
        exit 1
    fi
    
    cp docker/.env.prod.example docker/.env.prod
    chmod 600 docker/.env.prod
    
    echo ""
    echo "✅ Archivo docker/.env.prod creado"
    echo "⚠️  IMPORTANTE: Edita docker/.env.prod y cambia las contraseñas:"
    echo ""
    echo "   nano docker/.env.prod"
    echo ""
    read -p "Presiona Enter cuando hayas configurado las contraseñas..."
fi

# Verificar que las variables no estén vacías
echo "🔍 Verificando variables de entorno..."
source docker/.env.prod

if [ -z "$POSTGRES_DB" ] || [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ]; then
    echo "❌ Error: Variables de entorno no configuradas correctamente"
    echo "   Edita docker/.env.prod y asegúrate de llenar todos los valores"
    exit 1
fi

if [ "$POSTGRES_PASSWORD" = "CAMBIA_ESTO_POR_PASSWORD_SEGURO" ]; then
    echo "❌ Error: Aún tienes la contraseña por defecto"
    echo "   Cambia POSTGRES_PASSWORD en docker/.env.prod"
    exit 1
fi

echo "✅ Variables configuradas correctamente"
echo ""

# Crear red Docker si no existe
echo "🌐 Configurando red Docker..."
if ! docker network inspect asistente_network >/dev/null 2>&1; then
    docker network create asistente_network
    echo "✅ Red asistente_network creada"
else
    echo "✅ Red asistente_network ya existe"
fi
echo ""

# Build y start
echo "🐳 Construyendo imagen Docker..."
cd docker
docker-compose -f docker-compose.prod.yml build

echo ""
echo "🚀 Iniciando contenedor..."
docker-compose -f docker-compose.prod.yml up -d

echo ""
echo "⏳ Esperando a que la base de datos esté lista..."
sleep 5

# Verificar que está corriendo
if docker ps | grep -q asistente_db_prod; then
    echo "✅ Base de datos iniciada correctamente"
    echo ""
    echo "📊 Estado del contenedor:"
    docker ps | grep asistente_db_prod
    echo ""
    echo "📋 Últimas líneas del log:"
    docker logs --tail 10 asistente_db_prod
    echo ""
    echo "=================================================="
    echo "✅ Deployment completado exitosamente!"
    echo "=================================================="
    echo ""
    echo "🔌 Información de conexión para tu webapp:"
    echo ""
    echo "   Hostname: postgres"
    echo "   Puerto: 5432"
    echo "   Database: $POSTGRES_DB"
    echo "   User: $POSTGRES_USER"
    echo ""
    echo "   URL de conexión:"
    echo "   postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@postgres:5432/$POSTGRES_DB"
    echo ""
    echo "⚠️  Recuerda: Tu webapp debe estar en la red 'asistente_network'"
    echo ""
else
    echo "❌ Error: El contenedor no está corriendo"
    echo "Ver logs con: docker logs asistente_db_prod"
    exit 1
fi
