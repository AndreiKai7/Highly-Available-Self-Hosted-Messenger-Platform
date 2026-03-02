# 🚀 Highly Available Self-Hosted Messenger Platform

![K3s](https://img.shields.io/badge/Orchestration-K3s-blue?style=for-the-badge&logo=k3s)
![Dendrite](https://img.shields.io/badge/Messenger-Dendrite-black?style=for-the-badge)
![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL-blue?style=for-the-badge&logo=postgresql)
![Nginx](https://img.shields.io/badge/Ingress-Nginx-green?style=for-the-badge&logo=nginx)
![Status](https://img.shields.io/badge/Status-Production%20Ready-success?style=for-the-badge)

Полностью функциональная, самохостящаяся платформа для обмена сообщениями (Matrix), развернутая на базе облегченного Kubernetes (k3s). Проект демонстрирует навыки управления контейнерами, настройки сети (Ingress/SSL), работы с базами данных (StatefulSet) и автоматизации развертывания.

---

## 🏗 Архитектура проекта

В основе проекта лежит подход **"Infrastructure as Code"**. Все компоненты, от базы данных до веб-интерфейса, описаны в манифестах Kubernetes и разворачиваются одной командой.

```
                   Internet (HTTPS)
                         |
                         v
              +-----------------------+
              |   Nginx Ingress       |
              |   (SSL Termination)   |
              +-----------+-----------+
                          |
          +---------------+---------------+------------------+
          |               |               |                  |
    +-----v-----+   +-----v-----+   +-----v-----+     +------v------+
    |  Website  |   | Dendrite  |   | Prometheus|     |  Dashboard  |
    | (Frontend)|   | (Matrix)  |   | (Monitor) |     |   (Admin)   |
    +-----------+   +-----+-----+   +-----------+     +-------------+
                          |
                  +-------v-------+
                  |  PostgreSQL   |
                  | (StatefulSet) |
                  +---------------+
```

---

## 🛠 Технологический стек

*   **Orchestration:** [K3s](https://www.k3s.io/) — облегченный дистрибутив Kubernetes (идеален для VPS 2GB RAM).
*   **Messenger:** [Dendrite](https://github.com/matrix-org/dendrite) —第二代 Matrix homeserver на Go (легче и быстрее Synapse).
*   **Database:** PostgreSQL 15 (Alpine) — надежное хранилище данных.
*   **Ingress:** Nginx Ingress Controller — маршрутизация трафика.
*   **Security:** Cert-Manager + Let's Encrypt — автоматический выпуск SSL сертификатов.
*   **Monitoring:** Prometheus — сбор метрик кластера.
*   **Automation:** Bash-скрипт для полного цикла установки.

---

## ✨ Ключевые особенности

1.  **One-Click Deploy:** Полностью автоматизированный скрипт установки `deploy.sh`. Он устанавливает K3s, настраивает Ingress, генерирует пароли и запускает сервисы.
2.  **Logical High Availability:** На ограниченных ресурсах (2GB RAM) реализованы принципы отказоустойчивости:
    *   `Liveness` и `Readiness` пробы для контроля состояния подов.
    *   `StatefulSet` для сохранения данных базы при перезапусках.
    *   Автоматический перезапуск контейнеров (Self-healing).
3.  **Безопасность:**
    *   Автоматический HTTPS (TLS) для всех доменов.
    *   Генерация уникальных паролей БД при установке.
4.  **Оптимизация ресурсов:** Использование Alpine-образов и настройка `resource limits` для запуска на слабом VPS.

---

## 🚀 Быстрый старт

### Предварительные требования
*   Сервер (VPS) с Ubuntu 20.04/22.04.
*   Минимум **2GB RAM** и 1 CPU.
*   Доменное имя (A-записи должны указывать на IP сервера).

### Установка

1.  Клонируйте репозиторий:
    ```bash
    git clone https://github.com/ВАШ_ЛОГИН/messenger-platform.git
    cd messenger-platform
    ```

2.  Запустите скрипт установки:
    ```bash
    chmod +x deploy.sh
    ./deploy.sh
    ```
    Скрипт попросит ввести ваш домен и email для SSL сертификатов.

3.  Настройте DNS у вашего регистратора:
    *   `@` -> IP сервера
    *   `chat` -> IP сервера
    *   `dash` -> IP сервера
    *   `prometheus` -> IP сервера

### Доступ к сервисам

После успешного развертывания (занимает 3-5 минут) сервисы будут доступны по адресам:

*   🌐 **Сайт-портал:** `https://web.<ВАШ_ДОМЕН>`
*   💬 **Мессенджер:** `https://chat.<ВАШ_ДОМЕН>`
*   📊 **Мониторинг:** `https://prometheus.<ВАШ_ДОМЕН>`
*   🎛️ **Админ-панель:** `https://dash.<ВАШ_ДОМЕН>`

> **Примечание:** Админ-панель может потребовать входа через токен. Для доступа используйте `kubectl proxy` или порт-форвардинг для безопасности.

---

## 📦 Структура проекта

Проект организован по принципу модульности:

```text
.
├── deploy.sh              # Скрипт автоматизации (CI/CD в шеле)
├── admin-user.yaml        # Доступ к Dashboard
└── manifests/
    ├── 00-namespaces.yaml # Изоляция ресурсов
    ├── 01-postgres.yaml   # StatefulSet БД + Secrets
    ├── 02-dendrite.yaml   # Мессенджер + ConfigMap
    ├── 03-website.yaml    # Статический сайт (Nginx)
    ├── 04-prometheus.yaml # Мониторинг
    ├── 05-ingresses.yaml  # Правила маршрутизации
    └── 06-issuer.yaml     # Let's Encrypt конфигурация
```

---

## ⚠ Решенные проблемы (Troubleshooting)

В процессе разработки были решены нетривиальные задачи, с которыми сталкиваются DevOps-инженеры:

1.  **Registry Blocking:** Реализован автоматический поиск и замена заблокированных реестров образов (`registry.k8s.io`) на зеркала (`dockerproxy`) прямо в скрипте установки.
2.  **Resource Constraints:** Оптимизированы лимиты памяти и CPU для запуска "тяжелого" стека (Matrix + Postgres) на 2GB RAM без OOM Kill.
3.  **Network Policies:** Настроен корректный Ingress для сервисов, требующих HTTPS бэкенд (Dashboard).
4.  **DNS Propagation:** Учет времени обновления DNS при заказе SSL сертификатов.

