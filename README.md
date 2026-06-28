# peak-ota

PEAK 데스크탑 앱의 **OTA 아티팩트 저장소**. 앱 재설치 없이 교체되는 것들을 버전별로 보관·배포한다.

채널 두 개:

- **models** — 기본 내장 AI 모델 묶음(ollama + whisper). 첫 실행 시 자동 다운로드.
- **js** — 렌더러 JS 번들(얇은 일렉트론: 로직은 렌더러에 있고 번들만 OTA 교체).

## 앱이 바라보는 단일 포인터 — `index.json`

앱은 `https://raw.githubusercontent.com/rg5668/peak-ota/main/index.json` 하나만 읽는다.
채널별 현재 버전 + zip URL + sha256 을 가리킨다. **버전 올리기 = 이 파일의 version 을 올리고 릴리스 추가.**

```json
{
  "models": { "version": 1, "zipUrl": ".../models-v1/peak-models-v1.zip", "sha256": "..." },
  "js":     { "version": 0, "zipUrl": "", "sha256": "" }
}
```

앱은 로컬 설치 버전 < index 버전이면 zip 을 받아 검증(sha256)하고 교체한다.

## 버전 폴더 + 태깅 규칙

- 채널별 버전 폴더에 그 버전의 `manifest.json`(메타)만 커밋한다: `models/v1/`, `js/v1/`, …
- 실제 zip(큰 파일)은 git 에 넣지 않고 **GitHub 릴리스 자산**으로 올린다.
- 릴리스 태그 규칙: **`models-v<N>`**, **`js-v<N>`** (채널-버전). 자산 = `peak-models-v<N>.zip` / `peak-js-v<N>.zip`.
- 릴리스 후 `index.json` 의 해당 채널 version/zipUrl/sha256 을 갱신·커밋 → 앱이 다음 실행에 자동 반영.

## 새 버전 배포

```bash
# 예: models v2
bash scripts/publish.sh models 2 /path/to/peak-models-v2.zip
# → models/v2/manifest.json 생성, 릴리스 models-v2 만들어 zip 첨부, index.json 갱신
```

## 모델 zip 만드는 법(models 채널)

내부 구조 = `ollama/`(OLLAMA_MODELS 스토어) + `whisper/ggml-*.bin`:

```bash
mkdir -p stage/ollama stage/whisper
OLLAMA_MODELS="$PWD/stage/ollama" ollama pull qwen2.5:7b
curl -L -o stage/whisper/ggml-medium.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin
( cd stage && zip -r ../peak-models-v1.zip ollama whisper )
```
# peak-ota
