#!/bin/bash
set -eux

# ---------------------------------------------------------------------------
# Chemins longs : stratégie robuste
# 1) Tentative SUBST (W:) + chemin MSYS (/w)
# 2) Fallback copie vers un répertoire très court ($RUNNER_TEMP/cwp_phys)
#    puis recopie en fin d'étape
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
  # Sous Git-Bash/MSYS, W: est visible en /w
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
  # Copie l’intégralité du workspace actuel vers le chemin court
  cp -r "$workdir/." "$short_root/"
fi

# Tous les chemins suivants se basent sur $short_root (soit /w, soit $RUNNER_TEMP/cwp_phys)
cd "$short_root"

# Renforce git pour les chemins longs à chaque clone
gcs='git -c core.longpaths=true clone --depth=1 --no-tags --recurse-submodules --shallow-submodules'

export PYTHONPYCACHEPREFIX="$short_root/pycache2"
export PATH="$PATH:$short_root/ComfyUI_Windows_portable/python_standalone/Scripts"

ls -lahF

# Redirect HuggingFace-Hub model folder
export HF_HUB_CACHE="$short_root/ComfyUI_Windows_portable/HuggingFaceHub"
mkdir -p "${HF_HUB_CACHE}"
# Redirect Pytorch Hub model folder
export TORCH_HOME="$short_root/ComfyUI_Windows_portable/TorchHome"
mkdir -p "${TORCH_HOME}"

# Relocate python_standalone (déplacé dans le paquet portable)
mv "$short_root/python_standalone" "$short_root/ComfyUI_Windows_portable/python_standalone"

# Add MinGit (Portable Git)
curl -sSL https://github.com/git-for-windows/git/releases/download/v2.50.1.windows.1/MinGit-2.50.1-64-bit.zip \
    -o MinGit.zip
unzip -q MinGit.zip -d "$short_root/ComfyUI_Windows_portable/MinGit"
rm MinGit.zip

################################################################################
# ComfyUI main app
git -c core.longpaths=true clone https://github.com/comfyanonymous/ComfyUI.git \
    "$short_root/ComfyUI_Windows_portable/ComfyUI"
# Use latest stable version (has a release tag)
cd "$short_root/ComfyUI_Windows_portable/ComfyUI"
git fetch --tags --force
git reset --hard "$(git tag | grep -e '^v' | sort -V | tail -1)"
# Clear models folder (will restore in the next stage)
rm -vrf models
mkdir models

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

# >>> Ajouts manquants - General / Utilitaires
$gcs https://github.com/evanspearman/ComfyMath.git                     # ComfyMath
$gcs https://github.com/sipherxyz/comfyui-art-venture.git              # comfyui-art-venture
$gcs https://github.com/jamesWalker55/comfyui-various.git              # comfyui-various
$gcs https://github.com/Derfuu/Derfuu_ComfyUI_ModdedNodes.git          # Derfuu_ComfyUI_ModdedNodes

# Control
$gcs https://github.com/chflame163/ComfyUI_LayerStyle.git
$gcs https://github.com/Fannovel16/comfyui_controlnet_aux.git
$gcs https://codeberg.org/Gourieff/comfyui-reactor-node.git ComfyUI-ReActor   # ReActor (Codeberg) -> dossier conservé
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

# >>> Ajouts manquants - Control
$gcs https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git      # ComfyUI_LayerStyle_Advance
$gcs https://github.com/storyicon/comfyui_segment_anything.git         # comfyui_segment_anything
$gcs https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git     # comfyui-inpaint-cropandstitch

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

# >>> Ajouts manquants - PuLID / Flux
$gcs https://github.com/balazik/ComfyUI-PuLID-Flux.git                 # ComfyUI-PuLID-Flux
$gcs https://github.com/lldacing/ComfyUI_PuLID_Flux_ll.git             # ComfyUI_PuLID_Flux_ll

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
cp -rf "$short_root/attachments/." \
      "$short_root/ComfyUI_Windows_portable/"

du -hd2 "$short_root/ComfyUI_Windows_portable"

################################################################################
# TAESD model for image on-the-fly preview
cd "$short_root"
$gcs https://github.com/madebyollin/taesd.git
mkdir -p "$short_root/ComfyUI_Windows_portable/ComfyUI/models/vae_approx"
cp taesd/*_decoder.pth \
   "$short_root/ComfyUI_Windows_portable/ComfyUI/models/vae_approx/"
rm -rf taesd

# Download models for ReActor
cd "$short_root/ComfyUI_Windows_portable/ComfyUI/models"
curl -sSL https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/codeformer.pth \
    --create-dirs -o facerestore_models/codeformer-v0.1.0.pth
curl -sSL https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/GFPGANv1.4.pth \
    --create-dirs -o facerestore_models/GFPGANv1.4.pth
curl -sSL https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128_fp16.onnx \
    --create-dirs -o insightface/inswapper_128_fp16.onnx
# curl -sSL https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/config.json \
#     --create-dirs -o nsfw_detector/vit-base-nsfw-detector/config.json
# curl -sSL https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/confusion_matrix.png \
#     --create-dirs -o nsfw_detector/vit-base-nsfw-detector/confusion_matrix.png
# curl -sSL https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/model.safetensors \
#     --create-dirs -o nsfw_detector/vit-base-nsfw-detector/model.safetensors
# curl -sSL https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/preprocessor_config.json \
#     --create-dirs -o nsfw_detector/vit-base-nsfw-detector/preprocessor_config.json

# Download models for Impact-Pack & Impact-Subpack
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

################################################################################
# Run the test (CPU only), also let custom nodes download some models
cd "$short_root/ComfyUI_Windows_portable"
./python_standalone/python.exe -s -B ComfyUI/main.py --quick-test-for-ci --cpu

################################################################################
# Clean up
rm -vf "$short_root/ComfyUI_Windows_portable/"*.log
rm -vf "$short_root/ComfyUI_Windows_portable/ComfyUI/user/"*.log
rm -vrf "$short_root/ComfyUI_Windows_portable/ComfyUI/user/default/ComfyUI-Manager"

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
# Fin : si SUBST utilisé, démonte. Sinon, recopie depuis le chemin court.
# ---------------------------------------------------------------------------
if [ "$use_subst" -eq 1 ]; then
  cmd.exe /C subst W: /D || true
  cd "$workdir"
else
  # Copie de retour (chemin court -> workspace)
  cp -rf "$short_root/ComfyUI_Windows_portable" "$workdir/"
  cd "$workdir"
  rm -rf "$short_root" || true
fi
