#!/usr/bin/env bash

set -euo pipefail

REPO_URL="git@github.com:Krivetochka/.deploy.git"
TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.deploy"
KEY_FILE="./key"
SSH_KEY="$HOME/.ssh/id_ed25519"

self_destroy() {
if [[ -f "$0" ]]; then
    rm -f "$0"
fi
}

if ! command -v git &> /dev/null; then
    echo "Git не найден. Попытка установки..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y git
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y git
    elif command -v yum &> /dev/null; then
        sudo yum install -y git
    elif command -v pacman &> /dev/null; then
        sudo pacman -Sy --noconfirm git
    elif command -v apk &> /dev/null; then
        sudo apk add git
    else
        echo "❌ Не удалось определить пакетный менеджер для установки git."
        self_destroy
        exit 1
    fi
fi

if [[ ! -f "$KEY_FILE" ]] && [[ ! -f "$SSH_KEY" ]]; then
    echo "❌ Файл \"key\" не найден рядом со скриптом и SSH-ключ не установлен."
    self_destroy
    exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    cp "$KEY_FILE" "$SSH_KEY"
    chmod 600 "$SSH_KEY"
    rm -f "$KEY_FILE"
else
    echo "🔑 Ключ $SSH_KEY уже существует"
fi

if [[ -d "$TARGET_DIR/.git" ]]; then
    echo "Репозиторий уже существует в $TARGET_DIR, обновление..."
    git -C "$TARGET_DIR" pull --ff-only
elif [[ -e "$TARGET_DIR" ]]; then
    echo "❌ Путь $TARGET_DIR уже существует, но это не git-репозиторий."
    self_destroy
    exit 1
else
    echo "Клонирование $REPO_URL в $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR"
fi

echo "✅ Готово. Репозиторий .deploy в $TARGET_DIR, приватный ключ установлен."

# Удаляем сам скрипт init.sh после выполнения всех действий
self_destroy

if [[ -f "$TARGET_DIR/deploy.sh" ]]; then
    echo "Запуск $TARGET_DIR/deploy.sh..."
    chmod +x "$TARGET_DIR/deploy.sh"
    exec "$TARGET_DIR/deploy.sh"
else
    echo "❌ Скрипт deploy.sh не найден в $TARGET_DIR."
    exit 1
fi
