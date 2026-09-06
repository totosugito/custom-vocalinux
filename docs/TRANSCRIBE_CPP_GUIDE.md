# Qwen3-ASR & transcribe.cpp Support in Custom Vocalinux

This document outlines the modifications made to [Vocalinux](https://github.com/totosugito/custom-vocalinux) to support **`transcribe.cpp`** and **Qwen3-ASR** models, and provides step-by-step instructions for deploying to other computers.

---

## 🌟 Why Qwen3-ASR via transcribe.cpp?

- **100% Offline & Private:** Zero remote API calls or cloud dependencies.
- **Fast Execution:** Achieves ~6x to 8x realtime speed on standard CPUs without requiring heavy PyTorch installations.
- **High Accuracy & Multilingual:** Built-in automatic language detection supporting 30+ languages (Indonesian, English, Chinese, etc.).
- **Lightweight Models:** Quantized GGUF models (e.g., 0.6B Q8_0 at ~811 MB, Q4_K_M at ~654 MB) deliver accuracy comparable to Whisper Large while consuming significantly less memory.

---

## 🛠️ Summary of Changes Made

1. **New Model Catalog & Auto-Download:**
   - Added [`src/vocalinux/utils/transcribecpp_model_info.py`](file:///home/toto/Documents/temp/vocalinux/src/vocalinux/utils/transcribecpp_model_info.py):
     - Built-in catalog containing `qwen3-asr-0.6b-q8_0`, `qwen3-asr-0.6b-q4_k_m`, `qwen3-asr-1.7b-q8_0`, and `qwen3-asr-1.7b-q4_k_m`.
     - Support for custom user models via `~/.config/vocalinux/transcribe_models.json`.
     - Helper utilities to detect model paths and handle model deletion from the settings UI.

2. **Inference & Engine Integration:**
   - Modified [`src/vocalinux/speech_recognition/recognition_manager.py`](file:///home/toto/Documents/temp/vocalinux/src/vocalinux/speech_recognition/recognition_manager.py):
     - Added `transcribe_cpp` engine support to initialization, dynamic engine reconfiguration, and progress-tracked downloads.
     - Added `_transcribe_with_transcribecpp()` to invoke the local `transcribe-cli` binary with temporary 16 kHz WAV audio buffers.
     - Formats and extracts only clean transcription text (using `-o` output text file and regex parsing to strip CLI logs/timings).

3. **GUI Settings & Model Picker:**
   - Modified [`src/vocalinux/ui/settings_dialog.py`](file:///home/toto/Documents/temp/vocalinux/src/vocalinux/ui/settings_dialog.py):
     - Added `transcribe.cpp (Qwen3-ASR)` to the engine selection dropdown.
     - Implemented dynamic model picker with download indicators (`✓` / `↓`) and model information card displays.
     - Interactive download progress modal triggers automatically when selecting a non-downloaded model.
   - Modified [`src/vocalinux/ui/config_manager.py`](file:///home/toto/Documents/temp/vocalinux/src/vocalinux/ui/config_manager.py):
     - Persists `transcribecpp_model_size` across application restarts.

---

## 🚀 Deployment Guide for Other Computers

To set up and run this version on another Linux machine:

### Step 1: Install System Dependencies
Ensure PortAudio and GTK3 dependencies are present on the target system:
```bash
# Ubuntu / Debian
sudo apt update && sudo apt install -y portaudio19-dev python3-pip python3-venv libgirepository1.0-dev

# Fedora
sudo dnf install -y portaudio-devel python3-pip gobject-introspection-devel

# Arch Linux
sudo pacman -S --needed portaudio python-pip gobject-introspection
```

### Step 2: Install the `transcribe-cli` Binary
Vocalinux expects `transcribe-cli` to be in your `$PATH` (such as `/usr/local/bin/`):

#### Option A: Copy the Compiled Binary (Fastest)
If the target computer has the same CPU architecture (x86_64):
```bash
sudo cp /path/to/transcribe-cli /usr/local/bin/
sudo chmod +x /usr/local/bin/transcribe-cli
```

#### Option B: Build `transcribe-cli` from Source
```bash
git clone --recursive https://github.com/handy-computer/transcribe.cpp.git
cd transcribe.cpp
cmake -B build
cmake --build build --target transcribe-cli -j$(nproc)
sudo cp build/bin/transcribe-cli /usr/local/bin/
```

Verify that `transcribe-cli` is accessible:
```bash
transcribe-cli --help
```

### Step 3: Clone and Install Custom Vocalinux
```bash
git clone git@github.com:totosugito/custom-vocalinux.git
cd custom-vocalinux

# Create virtual environment or install into existing Vocalinux environment
python3 -m venv venv
source venv/bin/activate
pip install -e .
```

### Step 4: Run Vocalinux & Select Qwen3-ASR
1. Start Vocalinux:
   ```bash
   vocalinux
   ```
2. Open **Settings** (or right-click tray icon → Settings).
3. Under **Speech Engine**, set **Engine** to:
   ```
   transcribe.cpp (Qwen3-ASR)
   ```
4. Choose your desired model:
   - `qwen3-asr-0.6b-q8_0` (Default, recommended)
   - `qwen3-asr-0.6b-q4_k_m` (Lower RAM)
   - `qwen3-asr-1.7b-q8_0` (High accuracy)
5. If the model is not yet downloaded, Vocalinux will automatically show the download progress dialog and save it to `~/.local/share/vocalinux/models/transcribe_cpp/`.
