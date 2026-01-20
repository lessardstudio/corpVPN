#!/bin/bash

SERVER_IP=$(curl -s ifconfig.me)

echo "=== 🔐 Доступ к Blitz Panel ==="
echo ""
echo "Blitz Web Panel запущен на: http://0.0.0.0:8000"
echo ""

# 1. Проверить .env
echo "1️⃣ Проверка учетных данных из .env:"
if [ -f .env ]; then
    echo "Найден .env файл:"
    cat .env | grep -E "ADMIN|USER|PASS" | grep -v "^#"
else
    echo "❌ .env файл не найден!"
fi

echo ""
echo "2️⃣ Способы доступа к панели:"
echo ""
echo "Вариант A (SSH туннель - БЕЗОПАСНО):"
echo "  На вашем компьютере:"
echo "    ssh -L 8000:127.0.0.1:8000 root@$SERVER_IP"
echo "  Затем откройте: http://localhost:8000"
echo ""
echo "Вариант B (Прямой доступ - для теста):"
echo "  Временно откройте порт:"
echo "    sudo ufw allow 8000/tcp"
echo "  Откройте: http://$SERVER_IP:8000"
echo "  После теста закройте:"
echo "    sudo ufw deny 8000/tcp"
echo ""
echo "Вариант C (Доступ уже открыт):"
echo "  По логам видно что панель доступна извне:"
echo "  http://$SERVER_IP:8000/blitz/login"
echo ""

# 3. Попробовать получить доступ
echo "3️⃣ Тест доступа:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000 2>/dev/null)
if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Blitz Panel доступен (HTTP $HTTP_CODE)"
else
    echo "❌ Blitz Panel недоступен (HTTP $HTTP_CODE)"
fi

echo ""
echo "4️⃣ Учетные данные по умолчанию:"
echo "  Если .env не настроен, попробуйте:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "  Или проверьте в коде Blitz:"
docker exec blitz cat /etc/hysteria/core/scripts/webpanel/config/config.py 2>/dev/null | grep -E "admin|password" || echo "Не удалось получить"

echo ""
echo "5️⃣ Найти учетные данные в базе MongoDB:"
docker exec blitz-mongo mongosh --quiet --eval "use blitz; db.users.find().pretty()" 2>/dev/null || echo "Не удалось подключиться к MongoDB"
