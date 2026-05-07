# Label Studio Setup Report

**Date:** 2026-05-06  
**Environment:** Docker container, NVIDIA RTX 5090, CUDA 12.9 driver / CUDA 12.8 toolkit, PyTorch 2.7.1+cu128

---

## What Was Set Up

### 1. Label Studio (Web UI) — v1.23.0
Installed from PyPI (`pip install label-studio`). This includes pre-built frontend assets (no Node/yarn build required). SQLite is used as the database for this dev setup. Data directory: `~/.local/share/label-studio`.

### 2. Label Studio ML Backend Library — v2.0.1.dev0
Installed from source (`label-studio-ml-backend/`) via `pip install -e`. Provides the `LabelStudioMLBase` class and `label-studio-ml` / `gunicorn` server infrastructure all backends build on.

### 3. YOLO Backend — ultralytics 8.4.47
Source: `label-studio-ml-backend/label_studio_ml/examples/yolo/`  
Serves object detection, segmentation, and pose estimation via YOLO models. Starts on port **9091**.

### 4. SAM2 Image Backend — SAM-2 1.0 (Meta AI)
Source: `label-studio-ml-backend/label_studio_ml/examples/segment_anything_2_image/`  
Interactive image segmentation using Segment Anything 2.1. Checkpoint: `sam2.1_hiera_large.pt` (857 MB, downloaded to `/home/devuser/volume/sam2.1_hiera_large.pt`). Starts on port **9092**.

---

## Currently Running Services

| Service | URL (from host) | PID file | Log |
|---|---|---|---|
| Label Studio UI | http://172.17.112.2:8080 | — | `/tmp/label-studio.log` |
| YOLO backend | http://172.17.112.2:9091 | — | `/tmp/yolo-backend.log` |
| SAM2 image backend | http://172.17.112.2:9092 | — | `/tmp/sam2-backend.log` |

All three are bound to `0.0.0.0` and accessible from the host via the container IP **172.17.112.2**.

---

## How to Restart Services

```bash
# Label Studio
./start-label-studio.sh

# YOLO backend
./start-yolo-backend.sh

# SAM2 segmentation backend (requires checkpoint at /home/devuser/volume/sam2.1_hiera_large.pt)
./start-sam2-backend.sh
```

---

## Connecting ML Backends to Label Studio

1. Open Label Studio at http://172.17.112.2:8080 and create an account.
2. Create a project, then go to **Settings → Machine Learning → Add Model**.
3. Enter the backend URL:
   - YOLO: `http://172.17.112.2:9091`
   - SAM2 image: `http://172.17.112.2:9092`
4. Click **Validate and Save**. The backend status should show **Connected**.
5. For auto-annotation, enable **Use for interactive preannotations** in the ML settings.

To pass your Label Studio API key to a backend (needed for downloading images from LS):
```bash
export LABEL_STUDIO_API_KEY=<your-token>  # found in Account → Access Token
./start-yolo-backend.sh
```

---

## GPU / CUDA Compatibility (RTX 5090 / Blackwell)

- **Driver:** 575.64.03 (CUDA 12.9 capable)
- **Toolkit in venv:** CUDA 12.8
- **PyTorch:** 2.7.1+cu128 — built against CUDA 12.8, runs on 12.9 driver (forward-compatible)
- **SAM2:** runs in `bfloat16` via `torch.autocast`, with `tf32` enabled for Ampere+ (compute capability ≥ 8.0; RTX 5090 is sm_120 / Blackwell)
- **YOLO (ultralytics 8.4.47):** GPU-accelerated inference, compatible with numpy 2.2.6 (the `numpy<2` pin in the example's requirements.txt is stale)
- `TORCH_CUDA_ARCH_LIST` in the base image includes `12.0+PTX` covering Blackwell

---

## Issues Encountered and How They Were Resolved

### 1. yarn not globally installable (npm permission denied)
`npm install -g yarn` failed (non-root, no writable global prefix). **Resolution:** Not needed — `pip install label-studio` from PyPI bundles pre-built frontend assets, bypassing the yarn build entirely.

### 2. Dependency version conflicts between packages
After installing `label-studio-ml-backend` (from source), it upgraded `label-studio-sdk` to 2.0.22 and `requests` to 2.33.1, conflicting with `label-studio 1.23.0` which pins `label-studio-sdk==2.0.18` and `requests<2.33`. **Resolution:** Pinned them back: `pip install "label-studio-sdk==2.0.18" "requests>=2.32.3,<2.33"`.

### 3. YOLO `numpy<2` requirement vs label-studio `numpy>=2.2.6`
The YOLO example's `requirements.txt` pins `numpy<2`, but label-studio requires numpy 2.x. **Resolution:** Installed `ultralytics 8.4.47` (latest) which supports numpy 2; the stale pin was ignored. `lap==0.5.12` (for tracking) was installed separately and is compatible with numpy 2.

### 4. `torchmetrics` version conflict
YOLO requires `torchmetrics<1.8.0`; a newer version was already installed. **Resolution:** Downgraded to `torchmetrics==1.7.4`.

### 5. SAM2 checkpoint (no checkpoint bundled)
The SAM2 backend `model.py` defaults to `sam2.1_hiera_large.pt` in the working directory but doesn't ship it. **Resolution:** Downloaded `sam2.1_hiera_large.pt` (857 MB) from Meta's CDN to `/home/devuser/volume/`. Backend startup script exports `MODEL_CHECKPOINT` pointing to it.

### 6. `HOST=0.0.0.0` environment variable in container
The container has `HOST=0.0.0.0` set. Label Studio interprets `HOST` as the public base URL (should be `http://…`), warns and ignores it. **Resolution:** Set `LABEL_STUDIO_HOST=http://172.17.112.2:8080` in `start-label-studio.sh` so Label Studio generates correct absolute URLs.

### 7. `gunicorn` version mismatch in example requirements
SAM2 `requirements-base.txt` pins `gunicorn==22.0.0`; we installed 26.0.0. No API breakage — both expose the same WSGI interface. The newer version was kept.

---

## Cloned Repositories

| Repo | Local path |
|---|---|
| https://github.com/HumanSignal/label-studio | `./label-studio/` |
| https://github.com/HumanSignal/label-studio-ml-backend | `./label-studio-ml-backend/` |

Available GPU-ready ML backends (in `label-studio-ml-backend/label_studio_ml/examples/`):
`yolo`, `segment_anything_2_image`, `segment_anything_2_video`, `grounding_sam`, `grounding_dino`, `easyocr`, `nemo_asr`, `huggingface_llm`, `huggingface_ner`, and more.

---

## Quick-Start Cheatsheet

```bash
cd /home/devuser/projects

# Start everything
./start-label-studio.sh &          # http://172.17.112.2:8080
./start-yolo-backend.sh &          # http://172.17.112.2:9091
./start-sam2-backend.sh &          # http://172.17.112.2:9092

# Check logs
tail -f /tmp/label-studio.log
tail -f /tmp/yolo-backend.log
tail -f /tmp/sam2-backend.log

# Verify GPU is visible in PyTorch
python3 -c "import torch; print(torch.cuda.get_device_name(0))"
```
