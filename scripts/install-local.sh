#!/usr/bin/env bash
# 로컬 테스트: 모델 zip 을 앱 userData/models 에 풀어넣어 OTA 다운로드 없이 바로 쓰게 한다.
# (.installed.json 을 써서 앱이 "최신"으로 보고 다운로드를 건너뜀)
# 사용: bash scripts/install-local.sh [version=1] [appName=Peak]
#   dev(미패키징) 앱이면 appName 을 Electron 등 실제 productName 으로.
set -euo pipefail

V="${1:-1}"
APP="${2:-Peak}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP="$ROOT/models/v$V/peak-models-v$V.zip"
DEST="$HOME/Library/Application Support/$APP/models"
[ -f "$ZIP" ] || { echo "zip 없음: $ZIP"; exit 1; }

rm -rf "$DEST"; mkdir -p "$DEST"
echo "→ 풀어넣는 중: $DEST"
unzip -o -q "$ZIP" -d "$DEST"
printf '{ "version": %s }\n' "$V" > "$DEST/.installed.json"
echo "✓ 로컬 설치(v$V) — 앱이 OTA 건너뛰고 바로 사용:"
echo "   ollama:  $(ls "$DEST/ollama/blobs" 2>/dev/null | wc -l | tr -d ' ') blobs"
echo "   whisper: $(ls "$DEST/whisper" 2>/dev/null)"
