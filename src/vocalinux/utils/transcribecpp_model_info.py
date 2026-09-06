"""
transcribe.cpp model information and catalog for Vocalinux.

Provides an extensible registry for audio-LLM and speech models supported by transcribe.cpp
(such as Qwen3-ASR, Granite-ASR, SenseVoice, etc.).
"""

import json
import logging
import os
import shutil
from typing import Any, Optional

from .paths import config_dir, is_within_directory, models_dir

logger = logging.getLogger(__name__)

# Default built-in models catalog
_BUILTIN_TRANSCRIBE_MODELS: dict[str, dict[str, Any]] = {
    "qwen3-asr-0.6b-q8_0": {
        "family": "qwen3_asr",
        "size_mb": 811,
        "params": "600M",
        "desc": "Qwen3-ASR 0.6B (Q8_0) - Fast, lightweight, 30 languages auto-detect",
        "url": "https://huggingface.co/handy-computer/Qwen3-ASR-0.6B-gguf/resolve/main/Qwen3-ASR-0.6B-Q8_0.gguf",
        "filename": "Qwen3-ASR-0.6B-Q8_0.gguf",
    },
    "qwen3-asr-0.6b-q4_k_m": {
        "family": "qwen3_asr",
        "size_mb": 654,
        "params": "600M",
        "desc": "Qwen3-ASR 0.6B (Q4_K_M) - Low memory footprint, fast",
        "url": "https://huggingface.co/handy-computer/Qwen3-ASR-0.6B-gguf/resolve/main/Qwen3-ASR-0.6B-Q4_K_M.gguf",
        "filename": "Qwen3-ASR-0.6B-Q4_K_M.gguf",
    },
    "qwen3-asr-1.7b-q8_0": {
        "family": "qwen3_asr",
        "size_mb": 2084,
        "params": "1.7B",
        "desc": "Qwen3-ASR 1.7B (Q8_0) - High accuracy, Whisper Large-v3 rival",
        "url": "https://huggingface.co/handy-computer/Qwen3-ASR-1.7B-gguf/resolve/main/Qwen3-ASR-1.7B-Q8_0.gguf",
        "filename": "Qwen3-ASR-1.7B-Q8_0.gguf",
    },
    "qwen3-asr-1.7b-q4_k_m": {
        "family": "qwen3_asr",
        "size_mb": 1259,
        "params": "1.7B",
        "desc": "Qwen3-ASR 1.7B (Q4_K_M) - Quantized 1.7B model",
        "url": "https://huggingface.co/handy-computer/Qwen3-ASR-1.7B-gguf/resolve/main/Qwen3-ASR-1.7B-Q4_K_M.gguf",
        "filename": "Qwen3-ASR-1.7B-Q4_K_M.gguf",
    },
}


def get_transcribecpp_models_catalog() -> dict[str, dict[str, Any]]:
    """
    Return merged model catalog from built-ins and optional custom user config.
    Users can add custom models via ~/.config/vocalinux/transcribe_models.json
    """
    catalog = dict(_BUILTIN_TRANSCRIBE_MODELS)
    custom_json = os.path.join(config_dir(), "transcribe_models.json")
    if os.path.isfile(custom_json):
        try:
            with open(custom_json, "r", encoding="utf-8") as f:
                custom_models = json.load(f)
                if isinstance(custom_models, dict):
                    catalog.update(custom_models)
        except Exception as e:
            logger.warning("Could not read custom transcribe models from %s: %s", custom_json, e)
    return catalog


def get_transcribe_cli_path() -> Optional[str]:
    """Find the transcribe-cli executable path."""
    # 1. System PATH
    found = shutil.which("transcribe-cli")
    if found:
        return found

    # 2. Local sibling check (transcribe.cpp repository)
    candidate_paths = [
        os.path.expanduser("~/Documents/temp/transcribe.cpp/build/bin/transcribe-cli"),
        "/usr/local/bin/transcribe-cli",
        "/opt/transcribe.cpp/bin/transcribe-cli",
    ]
    for p in candidate_paths:
        if os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    return None


def get_transcribe_model_path(model_name: str) -> str:
    """Get the target filesystem path for a transcribe.cpp model."""
    transcribe_dir = os.path.join(models_dir(), "transcribe_cpp")
    os.makedirs(transcribe_dir, exist_ok=True)
    catalog = get_transcribecpp_models_catalog()
    model_info = catalog.get(model_name, {})
    filename = model_info.get("filename") or f"{model_name}.gguf"

    # Also check if user has the model in transcribe.cpp repo
    local_dev_path = os.path.expanduser(f"~/Documents/temp/transcribe.cpp/models/qwen3-asr-0.6b/{filename}")
    if not os.path.exists(os.path.join(transcribe_dir, filename)) and os.path.exists(local_dev_path):
        return local_dev_path

    return os.path.join(transcribe_dir, filename)


def is_transcribe_model_downloaded(model_name: str) -> bool:
    """Check if the model file is present locally."""
    path = get_transcribe_model_path(model_name)
    return os.path.isfile(path)


def list_downloaded_transcribe_models() -> list[str]:
    """List all available transcribe.cpp models present on disk."""
    catalog = get_transcribecpp_models_catalog()
    return [name for name in catalog if is_transcribe_model_downloaded(name)]


def delete_transcribe_model(model_name: str) -> str:
    """Delete a downloaded transcribe.cpp model file."""
    model_path = get_transcribe_model_path(model_name)
    transcribe_dir = os.path.join(models_dir(), "transcribe_cpp")
    if not is_within_directory(model_path, transcribe_dir):
        raise ValueError("Refusing to delete a path outside the transcribe_cpp models directory")
    if not os.path.isfile(model_path):
        raise FileNotFoundError(model_path)
    os.remove(model_path)
    logger.info("Deleted transcribe.cpp model %s (%s)", model_name, model_path)
    return model_path
