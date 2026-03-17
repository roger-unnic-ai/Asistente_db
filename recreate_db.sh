#!/bin/bash
# Script para recrear completamente la base de datos

echo "🔄 Recreando base de datos con schema corregido..."
echo ""

cd "/home/roger/Desktop/Asistente DB"

# 1. Detener y eliminar todo
echo "1️⃣  Deteniendo y eliminando contenedor + volúmenes..."
sudo docker-compose -f docker/docker-compose.dev.yml down -v
if [ $? -eq 0 ]; then
    echo "   ✓ Eliminado"
else
    echo "   ✗ Error al eliminar"
    exit 1
fi

echo ""

# 2. Reconstruir imagen
echo "2️⃣  Reconstruyendo imagen Docker (esto puede tardar un momento)..."
sudo docker-compose -f docker/docker-compose.dev.yml build --no-cache
if [ $? -eq 0 ]; then
    echo "   ✓ Imagen reconstruida"
else
    echo "   ✗ Error al reconstruir"
    exit 1
fi

echo ""

# 3. Iniciar
echo "3️⃣  Iniciando base de datos con nuevo schema..."
sudo docker-compose -f docker/docker-compose.dev.yml up -d
if [ $? -eq 0 ]; then
    echo "   ✓ Contenedor iniciado"
else
    echo "   ✗ Error al iniciar"
    exit 1
fi

echo ""

# 4. Esperar
echo "4️⃣  Esperando a que la base de datos esté lista..."
sleep 15

# 5. Verificar
echo ""
echo "5️⃣  Verificando estado..."
sudo docker-compose -f docker/docker-compose.dev.yml ps

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Base de datos recreada correctamente"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🧪 Ahora prueba con:"
echo "   source venv/bin/activate"
echo "   python example_usage.py"
echo ""
