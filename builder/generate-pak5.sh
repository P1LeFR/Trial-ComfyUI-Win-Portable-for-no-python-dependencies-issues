#!/bin/bash
set -eu

echo "# Auto-generated pak5.txt (ComfyUI + common nodes)" > pak5.txt

# URLs des requirements principaux (core + gros nodes)
array=(
  https://github.com/comfyanonymous/ComfyUI/raw/refs/heads/master/requirements.txt
  https://github.com/Comfy-Org/ComfyUI-Manager/raw/refs/heads/main/requirements.txt
  https://github.com/crystian/ComfyUI-Crystools/raw/refs/heads/main/requirements.txt
  https://github.com/cubiq/ComfyUI_essentials/raw/refs/heads/main/requirements.txt
  https://github.com/cubiq/ComfyUI_FaceAnalysis/raw/refs/heads/main/requirements.txt
  https://github.com/cubiq/ComfyUI_InstantID/raw/refs/heads/main/requirements.txt
  https://github.com/cubiq/PuLID_ComfyUI/raw/refs/heads/main/requirements.txt
  https://github.com/Fannovel16/comfyui_controlnet_aux/raw/refs/heads/main/requirements.txt
  https://github.com/Fannovel16/ComfyUI-Frame-Interpolation/raw/refs/heads/main/requirements-no-cupy.txt
  https://github.com/FizzleDorf/ComfyUI_FizzNodes/raw/refs/heads/main/requirements.txt
  https://github.com/Gourieff/ComfyUI-ReActor/raw/refs/heads/main/requirements.txt
  https://github.com/huchenlei/ComfyUI-layerdiffuse/raw/refs/heads/main/requirements.txt
  https://github.com/jags111/efficiency-nodes-comfyui/raw/refs/heads/main/requirements.txt
  https://github.com/kijai/ComfyUI-KJNodes/raw/refs/heads/main/requirements.txt
  https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite/raw/refs/heads/main/requirements.txt
  https://github.com/ltdrdata/ComfyUI-Impact-Pack/raw/refs/heads/Main/requirements.txt
  https://github.com/ltdrdata/ComfyUI-Impact-Subpack/raw/refs/heads/main/requirements.txt
  https://github.com/ltdrdata/ComfyUI-Inspire-Pack/raw/refs/heads/main/requirements.txt
  https://github.com/melMass/comfy_mtb/raw/refs/heads/main/requirements.txt
  https://github.com/ltdrdata/was-node-suite-comfyui/raw/refs/heads/main/requirements.txt
)

# Télécharge et concatène tous les requirements
for line in "${array[@]}"; do
  echo "[INFO] Fetching $line"
  curl -fsSL "$line" >> pak5.txt || echo "# skipped: $line" >> pak5.txt
  echo "" >> pak5.txt
done

# Nettoyage
sed -i '/^#/d' pak5.txt                    # enlève les commentaires
sed -i '/^$/d' pak5.txt                    # lignes vides
sed -i 's/[[:space:]]*$//' pak5.txt        # espaces de fin
sed -i 's/[><=].*$//' pak5.txt             # enlève les contraintes de version
sed -i 's/_/-/g' pak5.txt                  # uniformise underscores
sed -i 's/;.*$//' pak5.txt                 # supprime conditions plateforme

# Déduplique et trie proprement
sort -ufo pak5.txt pak5.txt

# Supprime les doublons avec pak4 (librairies déjà de base)
if [[ -f pak4.txt ]]; then
  grep -Fixv -f pak4.txt pak5.txt > temp.txt && mv temp.txt pak5.txt
fi

# Supprime les doublons internes ComfyUI connus
grep -Ev 'torch|torchvision|torchaudio|xformers|onnxruntime|numpy' pak5.txt > temp.txt && mv temp.txt pak5.txt

echo "[✅] <pak5.txt> generated and cleaned."
