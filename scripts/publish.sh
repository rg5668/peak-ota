#!/usr/bin/env bash
# OTA 버전 등록: 로컬 zip 의 sha256 계산 + index.json/manifest 를 외부 호스트 URL 로 갱신.
# zip 자체는 대용량이라 git/GitHub릴리스(2GB 한도) 아닌 외부 호스트(HF/R2/B2)에 올린다.
# 사용: bash scripts/publish.sh <models|js> <version:int> <zipUrl> [zip-path]
#   예: bash scripts/publish.sh models 1 https://huggingface.co/datasets/rg5668/peak-models/resolve/main/peak-models-v1.zip
# 요구: jq, shasum.
set -euo pipefail

CH="${1:?채널(models|js)}"; V="${2:?버전(정수)}"; URL="${3:?zip 의 퍼블릭 다운로드 URL}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP="${4:-$ROOT/$CH/v$V/peak-$CH-v$V.zip}"
[ -f "$ZIP" ] || { echo "로컬 zip 없음(sha 계산용): $ZIP"; exit 1; }

SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

# 1) 버전 폴더 manifest
mkdir -p "$ROOT/$CH/v$V"
cat > "$ROOT/$CH/v$V/manifest.json" <<EOF
{ "channel": "$CH", "version": $V, "zipUrl": "$URL", "sha256": "$SHA" }
EOF

# 2) index.json 의 해당 채널 포인터 갱신
tmp="$(mktemp)"
jq --arg ch "$CH" --argjson v "$V" --arg url "$URL" --arg sha "$SHA" \
  '.[$ch] = {version:$v, zipUrl:$url, sha256:$sha}' "$ROOT/index.json" > "$tmp" && mv "$tmp" "$ROOT/index.json"

echo "✓ $CH v$V 등록. sha=$SHA"
echo "  zip 을 이 URL 로 올렸는지 확인: $URL"
echo "  그다음: git add -A && git commit -m 'release: $CH v$V' && git push"
