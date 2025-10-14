#!/bin/bash
set -eux

# ──────────────────────────────────────────────────────────────────────────────
# 1️⃣ Vérifications initiales
# ──────────────────────────────────────────────────────────────────────────────
echo "===== Vérification du contenu avant compression ====="
ls -lahF
du -hd2 ComfyUI_Windows_portable || true
du -hd1 ComfyUI_Windows_portable/ComfyUI/custom_nodes || true
du -h ComfyUI_Windows_portable/ComfyUI/models || true

# ──────────────────────────────────────────────────────────────────────────────
# 2️⃣ Séparation des modèles (pour archive séparée)
# ──────────────────────────────────────────────────────────────────────────────
echo "===== Préparation du dossier modèles ====="
mkdir -p m_folder/ComfyUI_Windows_portable/ComfyUI
mv "ComfyUI_Windows_portable/ComfyUI/models" "m_folder/ComfyUI_Windows_portable/ComfyUI/models"

# Restaurer le dossier vide pour compatibilité Git
git -C "ComfyUI_Windows_portable/ComfyUI" checkout "models" || true

# ──────────────────────────────────────────────────────────────────────────────
# 3️⃣ Compression principale (ComfyUI sans models)
# ──────────────────────────────────────────────────────────────────────────────
echo "===== Compression de la build principale ====="

# Mode par défaut : 7z avec LZMA2 (équilibre vitesse/ratio)
# Si tu veux aller plus vite, ajuste -mx=5
"C:\Program Files\7-Zip\7z.exe" a ^
  -t7z -m0=lzma2 -mx=7 -mfb=64 -md=64m -ms=on -mf=BCJ2 ^
  -v2140000000b ComfyUI_Windows_portable_cu126.7z ^
  ComfyUI_Windows_portable

# ──────────────────────────────────────────────────────────────────────────────
# 4️⃣ Compression secondaire (models)
# ──────────────────────────────────────────────────────────────────────────────
echo "===== Compression des modèles ====="
cd m_folder
"C:\Program Files\7-Zip\7z.exe" a ^
  -tzip -mx=5 -v2140000000b models.zip ComfyUI_Windows_portable
mv ./*.zip* ../
cd ..

# ──────────────────────────────────────────────────────────────────────────────
# 5️⃣ Vérifications finales
# ──────────────────────────────────────────────────────────────────────────────
echo "===== Vérification des archives produites ====="
ls -lahF
du -h *.7z* || true
du -h *.zip* || true

echo
echo "===================================================="
echo "[✅] Stage 3 terminé avec succès."
echo "Archives créées :"
echo "  • ComfyUI_Windows_portable_cu126.7z.*  (application principale)"
echo "  • models.zip.*                         (modèles séparés)"
echo "===================================================="
