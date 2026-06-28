# peak-ota

PEAK 데스크탑 앱의 **OTA 아티팩트 저장소**. 앱 재설치 없이 교체되는 것들을 버전별로 보관·배포한다.

- 엔진 바이너리(ffmpeg/whisper/ollama)는 **앱에 동봉** — 여기 없음.
- 여기 올리는 건 **모델 가중치**(`models` 채널)와 **렌더러 JS 번들**(`js` 채널, 로더는 추후).

앱은 `https://raw.githubusercontent.com/rg5668/peak-ota/main/index.json` 하나만 읽어서 채널별 현재 버전을 따라간다. (`PEAK_OTA_INDEX_URL` 로 override)

> 전제: 이 repo는 **퍼블릭**, 기본 브랜치 **main**. (프라이빗이면 앱이 토큰 없이 못 받음)

---

## 릴리스 워크플로 (A → D)

### A. 모델 zip 만들기 (맥에서)

내부 구조 = `ollama/`(OLLAMA_MODELS 스토어) + `whisper/ggml-*.bin`:

```bash
mkdir -p stage/ollama stage/whisper

# ⚠️ ollama 함정: OLLAMA_MODELS 는 *서버(데몬)* 에만 적용된다. 기본 데몬이 이미 떠 있으면
#   `OLLAMA_MODELS=... ollama pull` 은 stage 가 아니라 기본 스토어(~/.ollama)로 받는다.
#   → stage 스토어를 가리키는 전용 데몬을 다른 포트로 띄워서 pull 한다.
OLLAMA_MODELS="$PWD/stage/ollama" OLLAMA_HOST=127.0.0.1:11435 ollama serve >/tmp/ota-ollama.log 2>&1 & SRV=$!
sleep 2
OLLAMA_HOST=127.0.0.1:11435 ollama pull qwen3:8b
kill "$SRV"

curl -L -o stage/whisper/ggml-medium.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin

# zip 은 버전 폴더에. 모델 blob 은 이미 압축형 → 무압축(-0)이 빠르고 크기 차이 거의 없음.
mkdir -p models/v1
( cd stage && zip -r -0 ../models/v1/peak-models-v1.zip ollama whisper )
shasum -a 256 models/v1/peak-models-v1.zip      # ← 이 해시 기억 (publish.sh 가 자동 계산도 함)

# 검증(선택): stage 스토어가 유효한지
#   OLLAMA_MODELS="$PWD/stage/ollama" OLLAMA_HOST=127.0.0.1:11435 ollama serve & sleep 2
#   OLLAMA_HOST=127.0.0.1:11435 ollama list   # qwen2.5:7b 1개만 보이면 정상
```

> 이미 기본 스토어(`~/.ollama`)에 pull 해버렸다면: 그 모델의 매니페스트
> (`~/.ollama/models/manifests/registry.ollama.ai/library/qwen2.5/7b`)와 거기 적힌
> blob digest(`config.digest`, `layers[].digest`)들을 `stage/ollama/{manifests,blobs}` 로 복사하면 된다.

### B. 배포 — 두 경로

zip 은 대용량(수 GB) → git 도 GitHub 릴리스(파일당 2GB 한도)도 안 됨. 외부 호스트(HF) + 포인터(index.json).

**① 로컬 테스트** (OTA 없이 이 맥에서 바로) — HF 업로드 전에 앱 동작 확인:
```bash
bash scripts/install-local.sh 1        # models/v1 zip 을 앱 userData/models 에 풀어넣음(다운로드 skip)
```

**② 진짜 배포** (프로덕션 OTA) — HF 업로드 + index 갱신 + push 한 방에:
```bash
hf auth login                          # 최초 1회(WRITE 토큰)
bash scripts/deploy.sh models 1        # HF 업로드 → publish.sh(sha+index) → git push
```
HF repo 기본 `kunhee2/peak-models`. 바꾸려면 `HF_REPO=...  bash scripts/deploy.sh models 1`.
다른 호스트(R2/B2/S3)면 `scripts/publish.sh <ch> <v> <URL>` 로 URL 만 갈아끼우면 됨.

### C. 앱 빌드 (peak repo)

```bash
cd /Users/kh/kh_tasks/peak/apps/desktop
bash scripts/build-whisper-static.sh    # 최초 1회 / whisper 갱신 시 (cmake 필요)
bash scripts/vendor-darwin-binaries.sh  # 정적 엔진 조립 + otool 검증
pnpm build:package                       # → dist-package/Peak-0.0.1-arm64.dmg
```

### D. 깨끗한 설치 검증

```bash
rm -rf ~/Library/Application\ Support/Peak/models   # 첫 실행 재현
open /Users/kh/kh_tasks/peak/apps/desktop/dist-package/Peak-0.0.1-arm64.dmg
# Applications 로 드래그 후:
xattr -dr com.apple.quarantine /Applications/Peak.app   # 미서명 Gatekeeper 우회
open /Applications/Peak.app
```

→ 켜지면 모델 자동 다운로드(`[models] download …%`) 후 분석까지 되는지 확인.

---

## 버전 올리기 (다음 릴리스부터)

`models` v2 예시: `bash scripts/publish.sh models 2 peak-models-v2.zip` → commit/push.
앱은 다음 실행에 `index.json` version 상승을 감지해 자동 재다운로드(OTA 교체).

---

## 구조 / 규칙

```
peak-ota/
  index.json            # 앱이 읽는 단일 포인터(채널별 현재 버전)
  models/v<N>/manifest.json
  js/v<N>/manifest.json  # 구조만 — JS OTA 로더 미구현
  scripts/publish.sh
```

- 채널-버전 폴더에는 `manifest.json`(메타)만 커밋. 큰 zip은 git 아닌 **릴리스 자산**.
- 릴리스 태그 규칙: `models-v<N>` / `js-v<N>`. 자산명: `peak-models-v<N>.zip` / `peak-js-v<N>.zip`.

`index.json`:

```json
{
  "models": { "version": 1, "zipUrl": ".../models-v1/peak-models-v1.zip", "sha256": "..." },
  "js":     { "version": 0, "zipUrl": "", "sha256": "" }
}
```
