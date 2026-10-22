#!/bin/bash
set -e

echo "========================================================"
echo "  [VERCEL DEPLOYMENT] Flutter Web Production Build"
echo "  Project: Smart Attendance System (Bui Nguyen Cong Nghiep)"
echo "========================================================"

# 1. Chuan bi file .env cho Flutter asset loader
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    echo "[INFO] Tao file .env tu .env.example..."
    cp .env.example .env
  else
    echo "[INFO] Tao file .env trong..."
    touch .env
  fi
fi

# Neu co bien moi truong BASE_URL duoc cau hinh tren Vercel Project Settings
if [ -n "$BASE_URL" ]; then
  echo "[INFO] Su dung BASE_URL tu Vercel Environment Variable: $BASE_URL"
  echo "BASE_URL=$BASE_URL" > .env
fi

# 2. Cai dat Flutter SDK (shallow clone nhanh chong tren Vercel)
if [ -d "flutter" ]; then
  echo "[INFO] Cap nhat Flutter SDK co san..."
  cd flutter && git pull && cd ..
else
  echo "[INFO] Dang clone Flutter SDK (stable channel, depth 1)..."
  git clone -b stable --depth 1 https://github.com/flutter/flutter.git
fi

# Them Flutter vao PATH
export PATH="$PATH:$(pwd)/flutter/bin"

echo "[INFO] Cau hinh Flutter Web..."
flutter config --enable-web --no-analytics

echo "[INFO] Cai dat cac thu vien dependencies..."
flutter pub get

echo "[INFO] Tien hanh build Flutter Web Release..."
if [ -n "$BASE_URL" ]; then
  flutter build web --release --dart-define=BASE_URL="$BASE_URL"
else
  flutter build web --release
fi

echo "========================================================"
echo "  [THANH CONG] Build Flutter Web hoan tat cho Vercel!"
echo "========================================================"
