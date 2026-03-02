#!/bin/bash

# ==========================================
# Messenger-Platform Auto-Deploy Script
# ==========================================

set -e

echo "🚀 Добро пожаловать в установщик Messenger-Platform!"

# 1. Ввод данных
read -p "🌐 Введите ваш домен: " DOMAIN
read -p "📧 Введите email для SSL сертификатов: " EMAIL

echo "⚙️  Начинаю настройку файлов..."

# 2. Замена домена и email в файлах
sed -i "s|<YOUR_DOMAIN>|$DOMAIN|g" manifests/05-ingresses.yaml
sed -i "s|<YOUR_DOMAIN>|$DOMAIN|g" manifests/config/dendrite.yaml
sed -i "s|your-email@example.com|$EMAIL|g" manifests/06-issuer.yaml

# 3. Генерация пароля (20 символов)
DB_PASS=$(openssl rand -base64 18 | head -c 20)

echo "🔑 Сгенерирован пароль для БД: $DB_PASS"
echo "⚠️  ВАЖНО: Сохраните этот пароль! Он нужен для подключения извне."
echo ""

# 4. Обновление конфига Dendrite (Вставка пароля)
echo "📝 Обновляю конфиг Dendrite..."
sed -i "s|<DB_PASSWORD>|$DB_PASS|g" manifests/config/dendrite.yaml

# 5. Установка k3s (если нет)
if ! command -v k3s &> /dev/null; then
    echo "⚙️  Устанавливаю K3s..."
    curl -sfL https://get.k3s.io | sh -s - --disable traefik --write-kubeconfig-mode 644
    sleep 30
fi

# 6. Настройка доступа kubectl
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export PATH=$PATH:/usr/local/bin

# 7. Создание Namespace (ОБЯЗАТЕЛЬНО ПЕРЕД СЕКРЕТОМ)
echo "📁 Создаю namespace messenger..."
kubectl create namespace messenger --dry-run=client -o yaml | kubectl apply -f -

# 8. Создание Kubernetes Secret
echo "🔐 Создаю секрет в Kubernetes..."
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_USER=matrix_user \
  --from-literal=POSTGRES_PASSWORD="$DB_PASS" \
  --from-literal=POSTGRES_DB=synapse \
  -n messenger --dry-run=client -o yaml | kubectl apply -f -

# 9. Установка Ingress & Cert-Manager
echo "🌐 Настраиваю Ingress и Cert-Manager..."
curl -Lo ingress-nginx.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml
sed -i 's/registry.k8s.io/k8s.dockerproxy.com/g' ingress-nginx.yaml
kubectl apply -f ingress-nginx.yaml
rm ingress-nginx.yaml
kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec": {"type": "LoadBalancer"}}' --type=merge || true

echo "⏳ Ждем готовности Nginx Ingress Controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

curl -Lo cert-manager.yaml https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
sed -i 's/registry.k8s.io/k8s.dockerproxy.com/g' cert-manager.yaml
kubectl apply -f cert-manager.yaml
rm cert-manager.yaml
echo "⏳ Ждем запуска Cert-Manager (30 сек)..."
sleep 30

# 10. Установка Dashboard
echo "📊 Устанавливаю Dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl apply -f admin-user.yaml

# 11. Применение всех манифестов приложения
echo "📦 Применяю манифесты приложений..."
kubectl apply -f manifests/

echo ""
echo "✅ Установка завершена!"
echo "🌐 Сайт: https://web.$DOMAIN"
echo "💬 Чат: https://chat.$DOMAIN"
echo "📊 Мониторинг: https://prometheus.$DOMAIN"
echo "🎛️  Админка: https://dash.$DOMAIN"