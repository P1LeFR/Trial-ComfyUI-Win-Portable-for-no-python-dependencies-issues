#!/bin/bash
set -eux

# Autoriser les chemins longs (important sous Windows)
git config --global core.longpaths true

ls -lahF

du -hd2 ComfyUI_Windows_portable
du -hd1 ComfyUI_Windows_portable/ComfyUI/custom_nodes
du -h ComfyUI_Windows_portable/ComfyUI/models

# Séparation des modèles pour un empaquetage plus léger
mkdir -p m_folder/ComfyUI_Windows_portable/ComfyUI
mv "ComfyUI_Windows_portable/ComfyUI/models" \
   "m_folder/ComfyUI_Windows_portable/ComfyUI/models"

# Restaure le dossier models depuis Git (pour garder l’arborescence propre)
git -C "ComfyUI_Windows_portable/ComfyUI" checkout "models"

# Nettoyage des métadonnées Git (mais on garde les caches utiles)
# find ComfyUI_Windows_portable -type d -name ".git" -prune -exec rm -rf {} +
# find ComfyUI_Windows_portable -type d -name ".github" -prune -exec rm -rf {} +
# find ComfyUI_Windows_portable -type f -name ".gitmodules" -delete

# Compression principale avec 7-Zip (LZMA2, volumes 2.14 Go)
"C:\Program Files\7-Zip\7z.exe" a -t7z \
  -m0=lzma2 -mx=7 -mfb=64 -md=128m -ms=on -mf=BCJ2 \
  -v2140000000b ComfyUI_WP_test.7z ComfyUI_Windows_portable

# En option : compression plus rapide (zip)
# "C:\Program Files\7-Zip\7z.exe" a -tzip -v2140000000b ComfyUI_WP_test.zip ComfyUI_Windows_portable

# Compression séparée du dossier models
cd m_folder
"C:\Program Files\7-Zip\7z.exe" a -tzip -v2140000000b models.zip ComfyUI_Windows_portable
mv ./*.zip* ../
cd ..


ls -lahF
################################################################################
# Notes sur la compression :
# - Utilise 2140000000 b comme taille de volume (limite GitHub).
# - LZMA2 (-mx=7 -mfb=64 -md=128m) = bon ratio/vitesse, idéal pour release.
# - Aucun cache supprimé (HuggingFace, TorchHome, Numba, etc.).
################################################################################
