#!/bin/bash
set -eux

# ---------------------------------------------------------------------------
# Chemins longs : stratégie robuste
# ---------------------------------------------------------------------------
git config --global core.autocrlf true
git config --global core.longpaths true

workdir="$(pwd)"
workdir_win="$(pwd -W 2>/dev/null || echo "")"

use_subst=0
short_root=""

# Tentative 1: SUBST vers W:
if [ -n "$workdir_win" ]; then
  cmd.exe /C subst W: "$workdir_win" || true
  if [ -d /w ]; then
    short_root="/w"
    use_subst=1
  fi
fi

# Fallback: copie vers un chemin court physique
if [ "$use_subst" -eq 0 ]; then
  run_tmp="${RUNNER_TEMP:-/d/a}"
  short_root="$run_tmp/cwp_phys"
  rm -rf "$short_root" || true
  mkdir -p "$short_root"
  cp -r "$workdir/." "$short_root/"
fi

cd "$short_root"

# Helper curl silencieux + robustesse
curl_dl () {
  # $1=url $2=dest_file (avec --create-dirs)
  curl -L --fail --retry 5 --retry-delay 2 --continue-at - -sS "$1" --create-dirs -o "$2"
}

# Copie locale depuis attachments si présent, sinon téléchargement
ATTACH="$short_root/attachments"
dl_or_copy () {
  # $1=dest_dir $2=url $3=fname
  mkdir -p "$1"
  if [ -f "$ATTACH/$3" ]; then
    echo ">> Copie locale: $3 -> $1"
    cp -f "$ATTACH/$3" "$1/$3"
  else
    echo ">> Téléchargement: $3"
    curl_dl "$2" "$1/$3"
  fi
}

gcs='git -c core.longpaths=true clone --depth=1 --no-tags --recurse-submodules --shallow-submodules'

export PYTHONPYCACHEPREFIX="$short_root/pycache2"
export PATH="$PATH:$short_root/ComfyUI_Windows_portable/python_standalone/Scripts"

ls -lahF

# Redirect caches
export HF_HUB_CACHE="$short_root/ComfyUI_Windows_portable/HuggingFaceHub"
mkdir -p "${HF_HUB_CACHE}"
export TORCH_HOME="$short_root/ComfyUI_Windows_portable/TorchHome"
mkdir -p "${TORCH_HOME}"

# Relocate python_standalone
mv "$short_root/python_standalone" "$short_root/ComfyUI_Windows_portable/python_standalone"

# MinGit
curl -sSL https://github.com/git-for-windows/git/releases/download/v2.50.1.windows.1/MinGit-2.50.1-64-bit.zip -o MinGit.zip
unzip -q MinGit.zip -d "$short_root/ComfyUI_Windows_portable/MinGit"
rm MinGit.zip

################################################################################
# ComfyUI main app
git -c core.longpaths=true clone https://github.com/comfyanonymous/ComfyUI.git \
    "$short_root/ComfyUI_Windows_portable/ComfyUI"
cd "$short_root/ComfyUI_Windows_portable/ComfyUI"
git fetch --tags --force
git reset --hard "$(git tag | grep -e '^v' | sort -V | tail -1)"
rm -vrf models
mkdir -p models

# Custom Nodes
cd "$short_root/ComfyUI_Windows_portable/ComfyUI/custom_nodes"
$gcs https://github.com/Comfy-Org/ComfyUI-Manager.git

# Workspace
$gcs https://github.com/crystian/ComfyUI-Crystools.git
$gcs https://github.com/pydn/ComfyUI-to-Python-Extension.git

# General
$gcs https://github.com/akatz-ai/ComfyUI-AKatz-Nodes.git
$gcs https://github.com/Amorano/Jovimetrix.git
$gcs https://github.com/bash-j/mikey_nodes.git
$gcs https://github.com/chrisgoringe/cg-use-everywhere.git
$gcs https://github.com/jags111/efficiency-nodes-comfyui.git
$gcs https://github.com/kijai/ComfyUI-KJNodes.git
$gcs https://github.com/mirabarukaso/ComfyUI_Mira.git
$gcs https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git
$gcs https://github.com/rgthree/rgthree-comfy.git
$gcs https://github.com/shiimizu/ComfyUI_smZNodes.git
$gcs https://github.com/ltdrdata/was-node-suite-comfyui.git
$gcs https://github.com/yolain/ComfyUI-Easy-Use.git
$gcs https://github.com/evanspearman/ComfyMath.git
$gcs https://github.com/sipherxyz/comfyui-art-venture.git
$gcs https://github.com/jamesWalker55/comfyui-various.git
$gcs https://github.com/Derfuu/Derfuu_ComfyUI_ModdedNodes.git

# Control
$gcs https://github.com/chflame163/ComfyUI_LayerStyle.git
$gcs https://github.com/Fannovel16/comfyui_controlnet_aux.git
$gcs https://codeberg.org/Gourieff/comfyui-reactor-node.git ComfyUI-ReActor
$gcs https://github.com/florestefano1975/comfyui-portrait-master.git
$gcs https://github.com/huchenlei/ComfyUI-IC-Light-Native.git
$gcs https://github.com/huchenlei/ComfyUI-layerdiffuse.git
$gcs https://github.com/Jonseed/ComfyUI-Detail-Daemon.git
$gcs https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git
$gcs https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
$gcs https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git
$gcs https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git
$gcs https://github.com/mcmonkeyprojects/sd-dynamic-thresholding.git
$gcs https://github.com/twri/sdxl_prompt_styler.git
$gcs https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git
$gcs https://github.com/storyicon/comfyui_segment_anything.git
$gcs https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git

# Video
$gcs https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git
$gcs https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git
$gcs https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
$gcs https://github.com/melMass/comfy_mtb.git

# More
$gcs https://github.com/akatz-ai/ComfyUI-DepthCrafter-Nodes.git
$gcs https://github.com/city96/ComfyUI-GGUF.git
$gcs https://github.com/digitaljohn/comfyui-propost.git
$gcs https://github.com/kijai/ComfyUI-DepthAnythingV2.git
$gcs https://github.com/kijai/ComfyUI-Florence2.git
$gcs https://github.com/neverbiasu/ComfyUI-SAM2.git
$gcs https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git
$gcs https://github.com/SLAPaper/ComfyUI-Image-Selector.git
$gcs https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git
$gcs https://github.com/nunchaku-tech/ComfyUI-nunchaku.git

# PuLID / Flux
$gcs https://github.com/balazik/ComfyUI-PuLID-Flux.git
$gcs https://github.com/lldacing/ComfyUI_PuLID_Flux_ll.git

# To be removed in future
$gcs https://github.com/cubiq/ComfyUI_essentials.git
$gcs https://github.com/cubiq/ComfyUI_InstantID.git
$gcs https://github.com/cubiq/ComfyUI_IPAdapter_plus.git
$gcs https://github.com/cubiq/PuLID_ComfyUI.git
$gcs https://github.com/cubiq/ComfyUI_FaceAnalysis.git
$gcs https://github.com/CY-CHENYUE/ComfyUI-Janus-Pro.git
$gcs https://github.com/FizzleDorf/ComfyUI_FizzNodes.git
$gcs https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git

################################################################################
# Copy attachments files (incl. start scripts)
cp -rf "$short_root/attachments/." "$short_root/ComfyUI_Windows_portable/"

du -hd2 "$short_root/ComfyUI_Windows_portable"

################################################################################
# TAESD model (preview)
cd "$short_root"
$gcs https://github.com/madebyollin/taesd.git
mkdir -p "$short_root/ComfyUI_Windows_portable/ComfyUI/models/vae_approx"
cp taesd/*_decoder.pth "$short_root/ComfyUI_Windows_portable/ComfyUI/models/vae_approx/"
rm -rf taesd

################################################################################
# MODELS OFFLINE – ReActor, PuLID/EVA-CLIP, InsightFace, GPEN, AnimateDiff
################################################################################
MODELS="$short_root/ComfyUI_Windows_portable/ComfyUI/models"

# ReActor (CodeFormer + GFPGAN déjà présents chez toi, je conserve)
cd "$MODELS"
curl_dl https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/codeformer.pth \
  "$MODELS/facerestore_models/codeformer-v0.1.0.pth"

curl_dl https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/GFPGANv1.4.pth \
  "$MODELS/facerestore_models/GFPGANv1.4.pth"

# GPEN pour Face Boost (ReActor le mentionne dans tes logs)
dl_or_copy "$MODELS/gpen" \
  "https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/GPEN-BFR-2048.onnx" \
  "GPEN-BFR-2048.onnx"

# InsightFace – inswapper + buffalo_l
dl_or_copy "$MODELS/insightface" \
  "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128_fp16.onnx" \
  "inswapper_128_fp16.onnx"

# Fournir aussi le nom non-fp16 si certains nodes l’attendent
cp -f "$MODELS/insightface/inswapper_128_fp16.onnx" "$MODELS/insightface/inswapper_128.onnx" || true

# buffalo_l (si pas déjà en attachments/buffalo_l)
if [ -d "$ATTACH/buffalo_l" ]; then
  mkdir -p "$MODELS/insightface/buffalo_l"
  cp -rf "$ATTACH/buffalo_l/." "$MODELS/insightface/buffalo_l/"
else
  TMPZIP="$short_root/buffalo_l.zip"
  curl_dl "https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip" "$TMPZIP"
  mkdir -p "$MODELS/insightface"
  unzip -o "$TMPZIP" -d "$MODELS/insightface" >/dev/null
  rm -f "$TMPZIP"
fi

# EVA-CLIP (PuLID)
dl_or_copy "$MODELS/clip" \
  "https://huggingface.co/QuanSun/EVA-CLIP/resolve/main/EVA02_CLIP_L_336_psz14_s6B.pt" \
  "EVA02_CLIP_L_336_psz14_s6B.pt"

# AnimateDiff
echo "[+] Downloading AnimateDiff motion model..."
curl_dl "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt" \
  "$MODELS/animatediff_models/mm_sd_v15_v2.ckpt"

# Impact-Pack installers
cd "$short_root/ComfyUI_Windows_portable/ComfyUI/custom_nodes/ComfyUI-Impact-Pack"
"$short_root/ComfyUI_Windows_portable/python_standalone/python.exe" -s -B install.py
cd "$short_root/ComfyUI_Windows_portable/ComfyUI/custom_nodes/ComfyUI-Impact-Subpack"
"$short_root/ComfyUI_Windows_portable/python_standalone/python.exe" -s -B install.py

echo "[Patch] Creating alias package cozy_comfy → cozy_comfyui"
alias_dir="$short_root/ComfyUI_Windows_portable/python_standalone/Lib/site-packages/cozy_comfy"
mkdir -p "$alias_dir"
cat > "$alias_dir/__init__.py" << 'PY'
import importlib, sys
m = importlib.import_module("cozy_comfyui")
sys.modules.setdefault("cozy_comfyui", m)
sys.modules.setdefault("cozy_comfy", m)
globals().update(getattr(m, "__dict__", {}))
PY

# ComfyUI-Manager en mode local (pas d’accès réseau au boot)
CFG_DIR="$short_root/ComfyUI_Windows_portable/ComfyUI/user/default/ComfyUI-Manager"
mkdir -p "$CFG_DIR"
cat > "$CFG_DIR/config.ini" << 'INI'
[general]
network_mode = local
auto_check_node_update = false
auto_check_model_update = false
auto_install = false
INI

################################################################################
# Test CI en mode offline (évite tout fallback réseau)
################################################################################
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export HF_ENDPOINT=
export HF_HUB_ENABLE_HF_XET=0

cd "$short_root/ComfyUI_Windows_portable"
./python_standalone/python.exe -s -B ComfyUI/main.py --quick-test-for-ci --cpu

################################################################################
# Clean up
rm -vf "$short_root/ComfyUI_Windows_portable/"*.log
rm -vf "$short_root/ComfyUI_Windows_portable/ComfyUI/user/"*.log
# Ne PAS supprimer la config Manager qu’on vient d’écrire

cd "$short_root/ComfyUI_Windows_portable/ComfyUI/custom_nodes"
rm -vf ./ComfyUI-Custom-Scripts/pysssss.json
rm -vf ./ComfyUI-Easy-Use/config.yaml
rm -vf ./ComfyUI-Impact-Pack/impact-pack.ini
rm -vf ./Jovimetrix/web/config.json
rm -vf ./was-node-suite-comfyui/was_suite_config.json

cd "$short_root/ComfyUI_Windows_portable/ComfyUI/custom_nodes/ComfyUI-Manager"
git reset --hard
git clean -fxd

# ---------------------------------------------------------------------------
# Fin : démontage SUBST / recopie si nécessaire
# ---------------------------------------------------------------------------
if [ "$use_subst" -eq 1 ]; then
  cmd.exe /C subst W: /D || true
  cd "$workdir"
else
  cp -rf "$short_root/ComfyUI_Windows_portable" "$workdir/"
  cd "$workdir"
  rm -rf "$short_root" || true
fi
