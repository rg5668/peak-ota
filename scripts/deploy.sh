#!/usr/bin/env bash
# 진짜 배포: 모델 zip 을 HF 에 올리고 → index/manifest 갱신 → git push. (프로덕션 OTA 릴리스)
# 사용: bash scripts/deploy.sh <models|js> <version:int>
#   HF repo override: HF_REPO=kunhee2/peak-models bash scripts/deploy.sh models 1
# 요구: hf(로그인됨), jq, git(push 권한).
set -euo pipefail

CH="${1:?채널(models|js)}"; V="${2:?버전(정수)}"
HF_REPO="${HF_REPO:-kunhee2/peak-models}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP="$ROOT/$CH/v$V/peak-$CH-v$V.zip"
FILE="$(basename "$ZIP")"
[ -f "$ZIP" ] || { echo "zip 없음: $ZIP (먼저 A 단계로 zip 생성)"; exit 1; }
export PATH="$HOME/.local/bin:$PATH"

echo "→ HF 업로드: $HF_REPO ($FILE, $(du -h "$ZIP" | cut -f1))"
hf upload "$HF_REPO" "$ZIP" "$FILE" --repo-type=dataset

URL="https://huggingface.co/datasets/$HF_REPO/resolve/main/$FILE"
bash "$ROOT/scripts/publish.sh" "$CH" "$V" "$URL"

git -C "$ROOT" add -A
git -C "$ROOT" commit -m "release: $CH v$V"
git -C "$ROOT" push
echo "✓ 배포 완료 — 앱이 다음 실행에 자동 반영: $URL"
