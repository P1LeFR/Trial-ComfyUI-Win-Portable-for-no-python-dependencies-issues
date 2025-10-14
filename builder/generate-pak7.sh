#!/bin/bash
set -eu

echo "# Auto-generated pak7.txt (extra nodes)" > pak7.txt

# Liste des nodes “optionnels” (2ᵉ vague)
array=(
  https://github.com/akatz-ai/ComfyUI-AKatz-Nodes/raw/refs/heads/main/requirements.txt
  https://github.com/akatz-ai/ComfyUI-DepthCrafter-Nodes/raw/refs/heads/main/requirements.txt
  https://github.com/Amorano/Jovimetrix/raw/refs/heads/main/requirements.txt
  https://github.com/chflame163/ComfyUI_LayerStyle/raw/refs/heads/main/requirements.txt
  https://github.com/city96/ComfyUI-GGUF/raw/refs/heads/main/requirements.txt
  https://github.com/digitaljohn/comfyui-propost/raw/refs/heads/main/requirements.txt
  https://github.com/Jonseed/ComfyUI-Detail-Daemon/raw/refs/heads/main/requirements.txt
  https://github.com/kijai/ComfyUI-DepthAnythingV2/raw/refs/heads/main/requirements.txt
  https://github.com/kijai/ComfyUI-Florence2/raw/refs/heads/main/requirements.txt
  https://github.com/mirabarukaso/ComfyUI_Mira/raw/refs/heads/main/requirements.txt
  https://github.com/nunchaku-tech/ComfyUI-nunchaku/raw/refs/heads/main/requirements.txt
  https://github.com/neverbiasu/ComfyUI-SAM2/raw/refs/heads/main/requirements.txt
  https://github.com/pydn/ComfyUI-to-Python-Extension/raw/refs/heads/main/requirements.txt
  https://github.com/yolain/ComfyUI-Easy-Use/raw/refs/heads/main/requirements.txt
)

for line in "${array[@]}"; do
  echo "[INFO] Fetching $line"
  curl -fsSL "$line" >> pak7.txt || echo "# skipped: $line" >> pak7.txt
  echo "" >> pak7.txt
done

# Nettoyage
sed -i '/^#/d' pak7.txt
sed -i '/^$/d' pak7.txt
sed -i 's/[[:space:]]*$//' pak7.txt
sed -i 's/[><=].*$//' pak7.txt
sed -i 's/_/-/g' pak7.txt
sed -i 's/;.*$//' pak7.txt

# Trie + dédoublonnage
sort -ufo pak7.txt pak7.txt

# Supprime doublons avec pak4 et pak5
for ref in pak4.txt pak5.txt; do
  if [[ -f $ref ]]; then
    grep -Fixv -f "$ref" pak7.txt > temp.txt && mv temp.txt pak7.txt
  fi
done

# Ignore libs déjà gérées ailleurs
grep -Ev 'torch|onnx|numpy|opencv|diffusers|transformers|timm' pak7.txt > temp.txt && mv temp.txt pak7.txt

echo "[✅] <pak7.txt> generated and cleaned."
