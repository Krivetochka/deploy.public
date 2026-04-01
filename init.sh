#!/bin/sh

set -euo pipefail

REPO_URL="git@github.com:Krivetochka/.deploy.git"
TARGET_DIR="$(cd "$(dirname "$0")" && pwd)/.deploy"
KEY_FILE="./key"
SSH_KEY="$HOME/.ssh/id_ed25519"

self_destroy() {
if [ -f "$0" ]; then
    rm -f "$0"
fi
}

if ! command -v git > /dev/null 2>&1; then
    echo "Git не найден. Попытка установки..."
    if command -v apt-get > /dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y git
    elif command -v dnf > /dev/null 2>&1; then
        sudo dnf install -y git
    elif command -v yum > /dev/null 2>&1; then
        sudo yum install -y git
    elif command -v pacman > /dev/null 2>&1; then
        sudo pacman -Sy --noconfirm git
    elif command -v apk > /dev/null 2>&1; then
        sudo apk add git
    else
        echo "❌ Не удалось определить пакетный менеджер для установки git."
        self_destroy
        exit 1
    fi
fi

if [ ! -f "$KEY_FILE" ] && [ ! -f "$SSH_KEY" ]; then
    echo "❌ Файл \"key\" не найден рядом со скриптом и SSH-ключ не установлен."
    self_destroy
    exit 1
fi

if [ ! -f "$SSH_KEY" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    cp "$KEY_FILE" "$SSH_KEY"
    chmod 600 "$SSH_KEY"
    rm -f "$KEY_FILE"
else
    echo "🔑 Ключ $SSH_KEY уже существует"
fi


# --- Установка bash ---
if ! command -v bash > /dev/null 2>&1; then
    echo "❌ Bash не установлен, установлен: $SHELL"
    printf "Установить bash? [Y/n]: "
    read reply
    reply=${reply:-y}
    case "$reply" in
        [Yy]*|"")
            if command -v apt-get > /dev/null 2>&1; then sudo apt-get install -y bash
            elif command -v dnf > /dev/null 2>&1; then sudo dnf install -y bash
            elif command -v yum > /dev/null 2>&1; then sudo yum install -y bash
            elif command -v pacman > /dev/null 2>&1; then sudo pacman -Sy --noconfirm bash
            elif command -v apk > /dev/null 2>&1; then sudo apk add bash
            fi
            echo "Устанавливаем bash оболочкой по умолчанию..."
            if command -v chsh > /dev/null 2>&1; then
                chsh -s /bin/bash
            fi
            ;;
        *)
            printf "❌ Bash не установлен, точно продолжить? [y/N]: "
            read reply_continue
            reply_continue=${reply_continue:-n}
            case "$reply_continue" in
                [Yy]*)
                    : # Выполняем ничего
                    ;;
                *)
                    self_destroy
                    exit 1
                    ;;
            esac
            ;;
    esac
fi

if [ -d "$TARGET_DIR/.git" ]; then
    echo "Репозиторий уже существует в $TARGET_DIR, обновление..."
    git -C "$TARGET_DIR" pull --ff-only
elif [ -e "$TARGET_DIR" ]; then
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

if [ -f "$TARGET_DIR/deploy.sh" ]; then
    echo "Запуск $TARGET_DIR/deploy.sh..."
    chmod +x "$TARGET_DIR/deploy.sh"
    exec "$TARGET_DIR/deploy.sh"
else
    echo "❌ Скрипт deploy.sh не найден в $TARGET_DIR."
    exit 1
fi
