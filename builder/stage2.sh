#!/usr/bin/env bash
set -Eeuo pipefail

# ╭──────────────────────────────────────────────────────────────────────────────╮
# │ Stage 2 — Assemblage ComfyUI portable (modulaire, non figé)                  │
# │ - Toutes les versions/refs sont surclassables via ENV                         │
# │ - Catégories de custom nodes paramétrables / filtrables                        │
# │ - Téléchargements modèles optionnels, idempotents                              │
# ╰──────────────────────────────────────────────────────────────────────────────╯

# ────────────────────────────────────────────────────────────────────────────────
# Paramètres généraux (surclassables)
# ────────────────────────────────────────────────────────────────────────────────
: "${WORKDIR:="$(pwd)"}"
: "${PORTABLE_DIR:="${WORKDIR}/ComfyUI_Windows_portable"}"
: "${PY_STANDALONE_DIR:="${WORKDIR}/python_standalone"}"   # vient du stage1
: "${USE_SHORT_COPY:=1}"                                   # 1=activer copie "chemin court"
: "${RUNNER_TEMP:="${WORKDIR}/_tmp"}"                      # fallback si non défini
: "${GIT_CRLF:=true}" : "${GIT_LONGPATHS:=true}"

# ComfyUI source
: "${COMFY_REPO_URL:="https://github.com/comfyanonymous/ComfyUI.git"}"
: "${COMFY_REF:=""}"        # vide=dernier tag; sinon tag/branch/commit au choix
: "${COMFY_CLEAN_MODELS:=1}"# 1=vider models avant restauration

# MinGit (optionnel) — par défaut on garde une version connue; surclassable
: "${MINGIT_VERSION_TAG:="v2.50.1.windows.1"}"             # ex "latest" non supporté off-line
: "${MINGIT_ZIP_NAME:="MinGit-2.50.1-64-bit.zip"}"
: "${INSTALL_MINGIT:=1}"

# Caches modèles
: "${HF_HUB_CACHE:="${PORTABLE_DIR}/HuggingFaceHub"}"
: "${TORCH_HOME:="${PORTABLE_DIR}/TorchHome"}"

# Custom nodes — contrôle fin
#  - Par défaut: liste embarquée ci-dessous.
#  - Surclasser via NODES_FILE (fichier .txt avec 1 URL par ligne, commentaires # ok)
#  - Ou via NODES_INCLUDE / NODES_EXCLUDE (regex egrep).
: "${NODES_FILE:=""}"
: "${NODES_INCLUDE:=""}"    # ex: "KJNodes|Impact-Pack"
: "${NODES_EXCLUDE:=""}"    # ex: "Legacy|FizzNodes"

# Téléchargements de modèles (ON/OFF par catégorie)
: "${DL_TAESD:=1}"
: "${DL_ANIMATEDIFF:=1}"
: "${DL_REACTOR:=1}"
: "${DL_EVA_CLIP:=1}"

# AnimateDiff (modèles par défaut)
: "${AD_MODELS_CSV:="mm_sd_v14.ckpt,https://huggingface.co/guoyww/animatediff/resolve/main/models/motion_module/mm_sd_v14.ckpt;mm_sd_v15_v2.ckpt,https://huggingface.co/guoyww/animatediff/resolve/main/models/motion_module/mm_sd_v15_v2.ckpt"}"

# Test rapide CPU (optionnel)
: "${RUN_CPU_TEST:=1}"

# Divers
export GIT_ASKPASS=echo
git config --global core.autocrlf "${GIT_CRLF}" || true
git config --global core.longpaths "${GIT_LONGPATHS}" || true
export PYTHONPYCACHEPREFIX="${WORKDIR}/pycache2"
export PATH="${PATH}:${PORTABLE_DIR}/python_standalone/Scripts"
mkdir -p "${HF_HUB_CACHE}" "${TORCH_HOME}"

log(){ printf '\n\033[1;34m[stage2]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31m[error]\033[0m %s\n' "$*"; exit 1; }

gcs='git -c core.longpaths=true clone --depth=1 --no-tags --recurse-submodules --shallow-submodules'

curl_dl(){ curl -fSL --retry 4 --retry-delay 2 -o "$2" "$1"; }

maybe_copy_short(){
  # Copie vers un chemin plus court pour éviter les limites Windows
  local src="$1" ; local dstroot="$2"
  [[ "${USE_SHORT_COPY}" != "1" ]] && { echo "$src"; return 0; }
  mkdir -p "${dstroot}"
  local dst="${dstroot}/$(basename "$src")"
  rm -rf "${dst}" 2>/dev/null || true
  cp -r "${src}" "${dst}"
  echo "${dst}"
}

# ────────────────────────────────────────────────────────────────────────────────
# 1) Préparation et déplacement du Python standalone dans le package final
# ────────────────────────────────────────────────────────────────────────────────
ls -lahF
mkdir -p "${PORTABLE_DIR}"
[[ -d "${PY_STANDALONE_DIR}" ]] || die "Python standalone introuvable: ${PY_STANDALONE_DIR}"
rm -rf "${PORTABLE_DIR}/python_standalone" 2>/dev/null || true
mv "${PY_STANDALONE_DIR}" "${PORTABLE_DIR}/python_standalone"

# ────────────────────────────────────────────────────────────────────────────────
# 2) MinGit portable (optionnel)
# ────────────────────────────────────────────────────────────────────────────────
if [[ "${INSTALL_MINGIT}" == "1" ]]; then
  log "Installation MinGit portable (${MINGIT_VERSION_TAG})…"
  curl_dl "https://github.com/git-for-windows/git/releases/download/${MINGIT_VERSION_TAG}/${MINGIT_ZIP_NAME}" "${WORKDIR}/MinGit.zip"
  mkdir -p "${PORTABLE_DIR}/MinGit"
  unzip -q "${WORKDIR}/MinGit.zip" -d "${PORTABLE_DIR}/MinGit"
  rm -f "${WORKDIR}/MinGit.zip"
else
  warn "MinGit ignoré (INSTALL_MINGIT=0)."
fi

# ────────────────────────────────────────────────────────────────────────────────
# 3) Clone du cœur ComfyUI (dernier tag si COMFY_REF vide)
# ────────────────────────────────────────────────────────────────────────────────
log "Clonage ComfyUI…"
rm -rf "${PORTABLE_DIR}/ComfyUI" 2>/dev/null || true
git clone --depth=1 --no-tags "${COMFY_REPO_URL}" "${PORTABLE_DIR}/ComfyUI"
pushd "${PORTABLE_DIR}/ComfyUI" >/dev/null
git fetch --tags --force
if [[ -z "${COMFY_REF}" ]]; then
  COMFY_REF="$(git tag -l 'v*' | sort -V | tail -1 || true)"
  [[ -n "${COMFY_REF}" ]] || COMFY_REF="HEAD"
fi
git reset --hard "${COMFY_REF}"
popd >/dev/null

if [[ "${COMFY_CLEAN_MODELS}" == "1" ]]; then
  rm -rf "${PORTABLE_DIR}/ComfyUI/models" || true
  mkdir -p "${PORTABLE_DIR}/ComfyUI/models"
fi

# ────────────────────────────────────────────────────────────────────────────────
# 4) Copie vers chemin court (optionnel) pour éviter PATH_MAX
# ────────────────────────────────────────────────────────────────────────────────
SHORT_ROOT="${RUNNER_TEMP%/}/cwp_phys"
PORT_ROOT="$( maybe_copy_short "${PORTABLE_DIR}" "${SHORT_ROOT}" )"

# ────────────────────────────────────────────────────────────────────────────────
# 5) Custom Nodes — listes modulaires
# ────────────────────────────────────────────────────────────────────────────────
log "Installation des custom nodes…"
CN_DIR="${PORT_ROOT}/ComfyUI/custom_nodes"
mkdir -p "${CN_DIR}"
pushd "${CN_DIR}" >/dev/null

# Liste par défaut (catégories). Surclassable via NODES_FILE.
DEFAULT_NODES=(
  # Workspace
  "https://github.com/Comfy-Org/ComfyUI-Manager.git"
  "https://github.com/crystian/ComfyUI-Crystools.git"
  "https://github.com/pydn/ComfyUI-to-Python-Extension.git"

  # General
  "https://github.com/akatz-ai/ComfyUI-AKatz-Nodes.git"
  "https://github.com/Amorano/Jovimetrix.git"
  "https://github.com/bash-j/mikey_nodes.git"
  "https://github.com/chrisgoringe/cg-use-everywhere.git"
  "https://github.com/jags111/efficiency-nodes-comfyui.git"
  "https://github.com/kijai/ComfyUI-KJNodes.git"
  "https://github.com/mirabarukaso/ComfyUI_Mira.git"
  "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
  "https://github.com/rgthree/rgthree-comfy.git"
  "https://github.com/shiimizu/ComfyUI_smZNodes.git"
  "https://github.com/ltdrdata/was-node-suite-comfyui.git"
  "https://github.com/yolain/ComfyUI-Easy-Use.git"

  # Control
  "https://github.com/chflame163/ComfyUI_LayerStyle.git"
  "https://github.com/Fannovel16/comfyui_controlnet_aux.git"
  "https://github.com/florestefano1975/comfyui-portrait-master.git"
  "https://codeberg.org/Gourieff/comfyui-reactor-node.git"
  "https://github.com/huchenlei/ComfyUI-IC-Light-Native.git"
  "https://github.com/huchenlei/ComfyUI-layerdiffuse.git"
  "https://github.com/Jonseed/ComfyUI-Detail-Daemon.git"
  "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git"
  "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
  "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git"
  "https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git"
  "https://github.com/mcmonkeyprojects/sd-dynamic-thresholding.git"
  "https://github.com/twri/sdxl_prompt_styler.git"

  # Video
  "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git"
  "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git"
  "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
  "https://github.com/melMass/comfy_mtb.git"

  # More
  "https://github.com/akatz-ai/ComfyUI-DepthCrafter-Nodes.git"
  "https://github.com/city96/ComfyUI-GGUF.git"
  "https://github.com/digitaljohn/comfyui-propost.git"
  "https://github.com/kijai/ComfyUI-DepthAnythingV2.git"
  "https://github.com/kijai/ComfyUI-Florence2.git"
  "https://github.com/neverbiasu/ComfyUI-SAM2.git"
  "https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git"
  "https://github.com/SLAPaper/ComfyUI-Image-Selector.git"
  "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
  "https://github.com/nunchaku-tech/ComfyUI-nunchaku.git"
  "https://github.com/balazik/ComfyUI-PuLID-Flux.git"
  "https://github.com/jamesWalker55/comfyui-various.git"
  "https://github.com/evanspearman/ComfyMath.git"

  # Legacy (facultatif; à filtrer via NODES_EXCLUDE)
  "https://github.com/cubiq/ComfyUI_essentials.git"
  "https://github.com/cubiq/ComfyUI_InstantID.git"
  "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
  "https://github.com/cubiq/PuLID_ComfyUI.git"
  "https://github.com/cubiq/ComfyUI_FaceAnalysis.git"
  "https://github.com/CY-CHENYUE/ComfyUI-Janus-Pro.git"
  "https://github.com/FizzleDorf/ComfyUI_FizzNodes.git"
  "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git"
)

readarray -t NODE_URLS < <(
  if [[ -n "${NODES_FILE}" && -f "${NODES_FILE}" ]]; then
    grep -E '^[[:space:]]*https?://' "${NODES_FILE}" | sed 's/[[:space:]]*$//' 
  else
    printf '%s\n' "${DEFAULT_NODES[@]}"
  fi | { 
    if [[ -n "${NODES_INCLUDE}" ]]; then egrep -E "${NODES_INCLUDE}" || true; else cat; fi
  } | {
    if [[ -n "${NODES_EXCLUDE}" ]]; then egrep -Ev "${NODES_EXCLUDE}" || true; else cat; fi
  } | awk '!seen[$0]++'  # déduplique
)

for url in "${NODE_URLS[@]}"; do
  name="$(basename "${url%.git}")"
  if [[ -d "${name}" ]]; then
    warn "Skip (existe déjà): ${name}"
    continue
  fi
  ${gcs} "${url}" || warn "Clone échoué: ${url}"
done
popd >/dev/null

# ────────────────────────────────────────────────────────────────────────────────
# 6) Restauration vers le dossier principal (depuis chemin court si activé)
# ────────────────────────────────────────────────────────────────────────────────
rm -rf "${PORTABLE_DIR}" || true
cp -r "${PORT_ROOT}" "$(dirname "${PORTABLE_DIR}")/"
rm -rf "$(dirname "${PORT_ROOT}")" 2>/dev/null || true

# ────────────────────────────────────────────────────────────────────────────────
# 7) Copie des “attachments” (scripts de démarrage, etc.)
# ────────────────────────────────────────────────────────────────────────────────
if [[ -d "${WORKDIR}/attachments" ]]; then
  cp -rf "${WORKDIR}/attachments/." "${PORTABLE_DIR}/"
fi
du -hd2 "${PORTABLE_DIR}" || true

# ────────────────────────────────────────────────────────────────────────────────
# 8) Téléchargements de modèles (optionnels & idempotents)
# ────────────────────────────────────────────────────────────────────────────────
pushd "${WORKDIR}" >/dev/null

# TAESD
if [[ "${DL_TAESD}" == "1" ]]; then
  log "TAESD (vae_approx)…"
  rm -rf taesd 2>/dev/null || true
  ${gcs} "https://github.com/madebyollin/taesd.git" || warn "Clone taesd échoué"
  mkdir -p "${PORTABLE_DIR}/ComfyUI/models/vae_approx"
  cp taesd/*_decoder.pth "${PORTABLE_DIR}/ComfyUI/models/vae_approx/" 2>/dev/null || true
  rm -rf taesd || true
fi

# AnimateDiff (liste CSV “name,url;name,url”)
if [[ "${DL_ANIMATEDIFF}" == "1" ]]; then
  log "AnimateDiff models…"
  IFS=';' read -ra PAIRS <<< "${AD_MODELS_CSV}"
  ad_node_dir="${PORTABLE_DIR}/ComfyUI/custom_nodes/ComfyUI-AnimateDiff-Evolved/models"
  ad_global_dir="${PORTABLE_DIR}/ComfyUI/models/animatediff_models"
  mkdir -p "${ad_node_dir}" "${ad_global_dir}"
  for pair in "${PAIRS[@]}"; do
    name="${pair%%,*}" ; url="${pair#*,}"
    dest_g="${ad_global_dir}/${name}"
    [[ -f "${dest_g}" ]] || curl -L --fail --retry 3 --retry-all-errors --connect-timeout 25 -o "${dest_g}" "${url}" || warn "DL fail: ${name}"
    cp -f "${dest_g}" "${ad_node_dir}/" 2>/dev/null || true
  done
fi

# ReActor / face restore
if [[ "${DL_REACTOR}" == "1" ]]; then
  log "ReActor models…"
  cd "${PORTABLE_DIR}/ComfyUI/models"
  curl -sSL --create-dirs -o facerestore_models/codeformer-v0.1.0.pth "https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/codeformer.pth" || true
  curl -sSL --create-dirs -o facerestore_models/GFPGANv1.4.pth        "https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/GFPGANv1.4.pth" || true
  curl -sSL --create-dirs -o insightface/inswapper_128_fp16.onnx       "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128_fp16.onnx" || true
fi

# EVA CLIP
if [[ "${DL_EVA_CLIP}" == "1" ]]; then
  log "EVA CLIP models…"
  eva_dir="${PORTABLE_DIR}/ComfyUI/models/clip"
  mkdir -p "${eva_dir}"
  declare -A EVA_MODELS=(
    ["eva_clip_vit_l.pth"]="https://huggingface.co/black-forest-labs/eva_clip/resolve/main/eva_clip_vit_l.pth"
    ["EVA02_CLIP_L_336_psz14_s6B.pt"]="https://huggingface.co/kijai/ComfyUI-Florence2/resolve/main/models/EVA02_CLIP_L_336_psz14_s6B.pt"
    ["EVA02_CLIP_B_336_psz14_s4B.pt"]="https://huggingface.co/kijai/ComfyUI-Florence2/resolve/main/models/EVA02_CLIP_B_336_psz14_s4B.pt"
    ["EVA02_CLIP_L_14_s6B.pt"]="https://huggingface.co/kijai/ComfyUI-Florence2/resolve/main/models/EVA02_CLIP_L_14_s6B.pt"
  )
  for f in "${!EVA_MODELS[@]}"; do
    dest="${eva_dir}/${f}"
    [[ -f "${dest}" ]] || curl -L --fail --retry 3 --retry-all-errors --connect-timeout 25 -o "${dest}" "${EVA_MODELS[$f]}" || warn "DL fail: ${f}"
  done
  # Copie vers PuLID-Flux (si présent)
  eva_flux_dir="${PORTABLE_DIR}/ComfyUI/custom_nodes/ComfyUI-PuLID-Flux/eva_clip/checkpoints"
  mkdir -p "${eva_flux_dir}"
  cp -f "${eva_dir}"/*.pt "${eva_flux_dir}/" 2>/dev/null || true
fi

popd >/dev/null

# ────────────────────────────────────────────────────────────────────────────────
# 9) Post-install spécifiques à certains nodes (idempotents)
# ────────────────────────────────────────────────────────────────────────────────
if [[ -d "${PORTABLE_DIR}/ComfyUI/custom_nodes/ComfyUI-Impact-Pack" ]]; then
  log "Impact-Pack install.py…"
  "${PORTABLE_DIR}/python_standalone/python.exe" -s -B "${PORTABLE_DIR}/ComfyUI/custom_nodes/ComfyUI-Impact-Pack/install.py" || warn "Impact-Pack install.py fail"
fi
if [[ -d "${PORTABLE_DIR}/ComfyUI/custom_nodes/ComfyUI-Impact-Subpack" ]]; then
  log "Impact-Subpack install.py…"
  "${PORTABLE_DIR}/python_standalone/python.exe" -s -B "${PORTABLE_DIR}/ComfyUI/custom_nodes/ComfyUI-Impact-Subpack/install.py" || warn "Impact-Subpack install.py fail"
fi

# Outil utile côté modèles (optionnel, silencieux si déjà présent)
"${PORTABLE_DIR}/python_standalone/python.exe" -s -m pip install -q hf_xet || true

# ────────────────────────────────────────────────────────────────────────────────
# 10) Test CPU (optionnel)
# ────────────────────────────────────────────────────────────────────────────────
if [[ "${RUN_CPU_TEST}" == "1" ]]; then
  log "Quick test CPU…"
  pushd "${PORTABLE_DIR}" >/dev/null
  ./python_standalone/python.exe -s -B ComfyUI/main.py --quick-test-for-ci --cpu || warn "Quick test CPU non concluant"
  popd >/dev/null
fi

# ────────────────────────────────────────────────────────────────────────────────
# 11) Nettoyage léger (non destructif, idempotent)
# ────────────────────────────────────────────────────────────────────────────────
log "Nettoyage temp/logs…"
rm -f "${PORTABLE_DIR}/"*.log 2>/dev/null || true
rm -f "${PORTABLE_DIR}/ComfyUI/user/"*.log 2>/dev/null || true
rm -rf "${PORTABLE_DIR}/ComfyUI/user/default/ComfyUI-Manager" 2>/dev/null || true

pushd "${PORTABLE_DIR}/ComfyUI/custom_nodes" >/dev/null || true
rm -f ./ComfyUI-Custom-Scripts/pysssss.json 2>/dev/null || true
rm -f ./ComfyUI-Easy-Use/config.yaml 2>/dev/null || true
rm -f ./ComfyUI-Impact-Pack/impact-pack.ini 2>/dev/null || true
rm -f ./Jovimetrix/web/config.json 2>/dev/null || true
rm -f ./was-node-suite-comfyui/was_suite_config.json 2>/dev/null || true
popd >/dev/null || true

# Reset ComfyUI-Manager si présent
if [[ -d "${PORTABLE_DIR}/ComfyUI/custom_nodes/ComfyUI-Manager/.git" ]]; then
  pushd "${PORTABLE_DIR}/ComfyUI/custom_nodes/ComfyUI-Manager" >/dev/null
  git reset --hard || true
  git clean -fxd || true
  popd >/dev/null
fi

log "Stage 2 terminé."
