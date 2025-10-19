#!/bin/bash
set -eu

echo '#' > pak5.txt

array=(
# Cœur + Manager
https://github.com/comfyanonymous/ComfyUI/raw/refs/heads/master/requirements.txt
https://github.com/Comfy-Org/ComfyUI-Manager/raw/refs/heads/main/requirements.txt

# Déjà présents
https://github.com/crystian/ComfyUI-Crystools/raw/refs/heads/main/requirements.txt
https://github.com/cubiq/ComfyUI_essentials/raw/refs/heads/main/requirements.txt
https://github.com/cubiq/ComfyUI_FaceAnalysis/raw/refs/heads/main/requirements.txt
https://github.com/cubiq/ComfyUI_InstantID/raw/refs/heads/main/requirements.txt
https://github.com/cubiq/PuLID_ComfyUI/raw/refs/heads/main/requirements.txt
https://github.com/Fannovel16/comfyui_controlnet_aux/raw/refs/heads/main/requirements.txt
https://github.com/Fannovel16/ComfyUI-Frame-Interpolation/raw/refs/heads/main/requirements-no-cupy.txt
https://github.com/FizzleDorf/ComfyUI_FizzNodes/raw/refs/heads/main/requirements.txt
# ReActor → Codeberg (remplace l’ancienne URL GitHub)
https://codeberg.org/Gourieff/comfyui-reactor-node/raw/branch/main/requirements.txt
https://github.com/huchenlei/ComfyUI-layerdiffuse/raw/refs/heads/main/requirements.txt
https://github.com/jags111/efficiency-nodes-comfyui/raw/refs/heads/main/requirements.txt
https://github.com/kijai/ComfyUI-KJNodes/raw/refs/heads/main/requirements.txt
https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite/raw/refs/heads/main/requirements.txt
https://github.com/ltdrdata/ComfyUI-Impact-Pack/raw/refs/heads/Main/requirements.txt
https://github.com/ltdrdata/ComfyUI-Impact-Subpack/raw/refs/heads/main/requirements.txt
https://github.com/ltdrdata/ComfyUI-Inspire-Pack/raw/refs/heads/main/requirements.txt
https://github.com/melMass/comfy_mtb/raw/refs/heads/main/requirements.txt
https://github.com/ltdrdata/was-node-suite-comfyui/raw/refs/heads/main/requirements.txt

# --- AJOUTS MANQUANTS ---

# Easy-Use
https://github.com/yolain/ComfyUI-Easy-Use/raw/refs/heads/main/requirements.txt

# Advanced ControlNet
https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet/raw/refs/heads/main/requirements.txt

# Florence2
https://github.com/kijai/ComfyUI-Florence2/raw/refs/heads/main/requirements.txt

# DepthAnythingV2
https://github.com/kijai/ComfyUI-DepthAnythingV2/raw/refs/heads/main/requirements.txt

# SAM2
https://github.com/neverbiasu/ComfyUI-SAM2/raw/refs/heads/main/requirements.txt

# GGUF
https://github.com/city96/ComfyUI-GGUF/raw/refs/heads/main/requirements.txt

# Image Selector
https://github.com/SLAPaper/ComfyUI-Image-Selector/raw/refs/heads/main/requirements.txt

# UltimateSDUpscale
https://github.com/ssitu/ComfyUI_UltimateSDUpscale/raw/refs/heads/main/requirements.txt

# Nunchaku (plugin)
https://github.com/nunchaku-tech/ComfyUI-nunchaku/raw/refs/heads/main/requirements.txt

# ArtVenture
https://github.com/sipherxyz/comfyui-art-venture/raw/refs/heads/main/requirements.txt

# LayerStyle Advance
https://github.com/chflame163/ComfyUI_LayerStyle_Advance/raw/refs/heads/main/requirements.txt

# Derfuu Modded Nodes
https://github.com/Derfuu/Derfuu_ComfyUI_ModdedNodes/raw/refs/heads/main/requirements.txt
)

for line in "${array[@]}"; do
    curl -fsSL "${line}" >> pak5.txt || true
done

sed -i '/^#/d' pak5.txt
sed -i 's/[[:space:]]*$//' pak5.txt
sed -i 's/>=.*$//' pak5.txt
sed -i 's/_/-/g' pak5.txt

sort -ufo pak5.txt pak5.txt

# Remove duplicate items, compare to pak4.txt
grep -Fixv -f pak4.txt pak5.txt > temp.txt && mv temp.txt pak5.txt

echo "<pak5.txt> generated. Check before use."
