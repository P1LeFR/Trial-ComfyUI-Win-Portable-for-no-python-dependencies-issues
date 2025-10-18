#!/usr/bin/env bash
set -Eeuo pipefail

# ╭──────────────────────────────────────────────────────────────────────────────╮
# │ Stage 1 - Bootstrap portable ComfyUI (modulable, non figé)                  │
# ╰──────────────────────────────────────────────────────────────────────────────╯

: "${WORKDIR:="$(pwd)"}"
PYDIR="${WORKDIR}/python_standalone"
PYTHON_EXE="${PYDIR}/python.exe"

# Python standalone (paramétrable)
: "${PY_STANDALONE_URL:=""}"
: "${PY_STANDALONE_TAG:=""}"
: "${PY_STANDALONE_VERSION:="3.12.11"}"
: "${PY_STANDALONE_ARCH:="x86_64-pc-windows-msvc"}"

# pip/options
: "${PIP_DEFAULT_TIMEOUT:=120}"
: "${PIP_NO_INPUT:=1}"
: "${PIP_NO_WARN_SCRIPT_LOCATION:=0}"
: "${PIP_EXTRA_INDEX_URL:=""}"     # ex: https://download.pytorch.org/whl/cu128
: "${PIP_CONSTRAINTS:=""}"         # chemin vers un constraints.txt optionnel
: "${PIP_NO_CACHE_DIR:=1}"
: "${PIP_ONLY_BINARY_DEFAULT:=":all:"}"

# piles
: "${PAK_FILES:="pak2.txt pak3.txt pak4.txt pak5.txt pak6.txt pak7.txt pak8.txt"}"
: "${PAK_POST_FILES:="pakY.txt pakZ.txt"}"

# xformers
: "${XFORMERS_SPEC:=""}"           # "", "0.0.32.post2", "none"
: "${XFORMERS_NO_DEPS:=1}"
: "${XFORMERS_ONLY_BINARY:=1}"

# ComfyUI
: "${COMFY_REPO:=comfyanonymous/ComfyUI}"
: "${COMFY_TAG:=""}"               # vide → dernier tag
: "${COMFY_REQUIREMENTS_PATH:=requirements.txt}"

# Outils externes
: "${NINJA_VERSION:=latest}"
: "${ARIA2_VERSION:=1.37.0}"
: "${FFMPEG_VERSION:=7.1.1}"

# Réseau
: "${CURL_RETRIES:=4}"
: "${CURL_RETRY_DELAY:=2}"
: "${VERIFY_ZIP_CONTENT:=1}"

export GIT_ASKPASS=echo
export PIP_DEFAULT_TIMEOUT PIP_NO_INPUT PYTHONPYCACHEPREFIX="${WORKDIR}/pycache1" PIP_NO_WARN_SCRIPT_LOCATION PIP_NO_CACHE_DIR

pip_exe() { "${PYTHON_EXE}" -s -m pip "$@"; }
log()  { printf '\n\033[1;34m[stage1]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31m[error]\033[0m %s\n' "$*"; exit 1; }

curl_dl() { curl -fSL --retry "${CURL_RETRIES}" --retry-delay "${CURL_RETRY_DELAY}" -o "$2" "$1"; }

file_exists_or_skip() {
  local f="$1"
  [[ -f "$f" ]] || { warn "fichier manquant, on saute: $f"; return 1; }
  return 0
}

install_req_file() {
  local req="$1"
  file_exists_or_skip "$req" || return 0
  local args=(install -r "$req" --prefer-binary)
  [[ -n "${PIP_CONSTRAINTS}" && -f "${PIP_CONSTRAINTS}" ]] && args+=( -c "${PIP_CONSTRAINTS}" )
  [[ -n "${PIP_EXTRA_INDEX_URL}" ]] && args+=( --extra-index-url "${PIP_EXTRA_INDEX_URL}" )
  [[ -n "${PIP_ONLY_BINARY_DEFAULT}" ]] && args+=( --only-binary "${PIP_ONLY_BINARY_DEFAULT}" )
  pip_exe "${args[@]}"
}

# GitHub API helper (avec token si dispo)
gh_api() {
  local url="$1"
  local hdr=(-H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    hdr+=( -H "Authorization: Bearer ${GITHUB_TOKEN}" )
  fi
  curl -fsSL --retry "${CURL_RETRIES}" --retry-delay "${CURL_RETRY_DELAY}" "${hdr[@]}" "$url"
}

ls -lahF

# ────────────────────────────────────────────────────────────────────────────────
# 1) Python standalone (corrigé : pas d’imbrication de dossiers)
# ────────────────────────────────────────────────────────────────────────────────
log "Téléchargement / préparation du Python standalone…"
tmp_py="${WORKDIR}/python.tar.gz"

if [[ -z "${PY_STANDALONE_URL}" ]]; then
  if [[ -n "${PY_STANDALONE_TAG}" ]]; then
    PY_STANDALONE_URL="https://github.com/astral-sh/python-build-standalone/releases/download/${PY_STANDALONE_TAG}/cpython-${PY_STANDALONE_VERSION}+${PY_STANDALONE_TAG}-${PY_STANDALONE_ARCH}-install_only.tar.gz"
    log "URL Python construite depuis TAG: ${PY_STANDALONE_URL}"
  else
    PY_STANDALONE_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250814/cpython-3.12.11+20250814-${PY_STANDALONE_ARCH}-install_only.tar.gz"
    warn "PY_STANDALONE_URL non fourni → fallback stable utilisé."
  fi
fi

curl_dl "${PY_STANDALONE_URL}" "${tmp_py}"
tar -tzf "${tmp_py}" >/dev/null
tar -zxf "${tmp_py}" -C "${WORKDIR}"
rm -f "${tmp_py}"

# Trouve le dossier extrait contenant python.exe
EXTRACTED_DIR=""
if [[ -d "${WORKDIR}/python" && -f "${WORKDIR}/python/python.exe" ]]; then
  EXTRACTED_DIR="${WORKDIR}/python"
else
  # fallback: cherche un dossier qui contient python.exe
  cand="$(find "${WORKDIR}" -maxdepth 2 -type f -name 'python.exe' -printf '%h\n' | head -n1 || true)"
  [[ -n "$cand" ]] && EXTRACTED_DIR="$cand"
fi
[[ -n "${EXTRACTED_DIR}" ]] || die "python.exe introuvable après extraction."

# Évite l’imbrication : remplace totalement PYDIR par le dossier extrait
rm -rf "${PYDIR}" 2>/dev/null || true
mv -f "${EXTRACTED_DIR}" "${PYDIR}"

# ────────────────────────────────────────────────────────────────────────────────
# 2) Pip de base
# ────────────────────────────────────────────────────────────────────────────────
log "Mise à jour pip/setuptools/wheel…"
pip_exe install --upgrade pip wheel setuptools --prefer-binary

# ────────────────────────────────────────────────────────────────────────────────
# 3) Installation par blocs (Torch → xformers → reste)
# ────────────────────────────────────────────────────────────────────────────────
install_req_file "${WORKDIR}/pak2.txt"

if file_exists_or_skip "${WORKDIR}/pak3.txt"; then
  log "Installation pak3 (sans xformers)…"
  awk 'BEGIN{IGNORECASE=1} /^[[:space:]]*#/ {print; next} !/^[[:space:]]*xformers([[:space:]]|=|<|>|!|$)/ {print}' \
    "${WORKDIR}/pak3.txt" > "${WORKDIR}/pak3.no_xformers.txt"
  install_req_file "${WORKDIR}/pak3.no_xformers.txt"
fi

if [[ "${XFORMERS_SPEC}" != "none" ]]; then
  log "Installation xformers…"
  XF_ARGS=(install --prefer-binary)
  [[ -n "${PIP_EXTRA_INDEX_URL}" ]] && XF_ARGS+=( --extra-index-url "${PIP_EXTRA_INDEX_URL}" )
  [[ -n "${PIP_CONSTRAINTS}" && -f "${PIP_CONSTRAINTS}" ]] && XF_ARGS+=( -c "${PIP_CONSTRAINTS}" )
  [[ "${XFORMERS_ONLY_BINARY}" == "1" ]] && XF_ARGS+=( --only-binary ":all:" )
  [[ "${XFORMERS_NO_DEPS}" == "1" ]] && XF_ARGS+=( --no-deps )
  if [[ -n "${XFORMERS_SPEC}" ]]; then XF_ARGS+=( "xformers==${XFORMERS_SPEC}" ); else XF_ARGS+=( xformers ); fi
  pip_exe "${XF_ARGS[@]}"
else
  warn "xformers ignoré (XFORMERS_SPEC=none)."
fi

for f in ${PAK_FILES}; do
  [[ "${f}" == "pak3.txt" ]] && continue
  install_req_file "${WORKDIR}/${f}" || true
done

# ────────────────────────────────────────────────────────────────────────────────
# 4) ComfyUI requirements (dernier tag via API, avec GITHUB_TOKEN si dispo)
# ────────────────────────────────────────────────────────────────────────────────
log "Installation requirements ComfyUI…"
if [[ -z "${COMFY_TAG}" ]]; then
  if command -v jq >/dev/null 2>&1; then
    COMFY_TAG="$(gh_api "https://api.github.com/repos/${COMFY_REPO}/tags?per_page=50" | jq -r '.[].name' | head -n1 || true)"
  else
    COMFY_TAG="$(gh_api "https://api.github.com/repos/${COMFY_REPO}/tags?per_page=50" | sed -n 's/.*\"name\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p' | head -n1 || true)"
  fi
  [[ -n "${COMFY_TAG}" ]] || die "Impossible de déterminer le tag ComfyUI (exporte GITHUB_TOKEN si besoin)."
fi
log "Tag ComfyUI sélectionné: ${COMFY_TAG}"

COMFY_REQ_URL="https://raw.githubusercontent.com/${COMFY_REPO}/refs/tags/${COMFY_TAG}/${COMFY_REQUIREMENTS_PATH}"
pip_exe install -r "${COMFY_REQ_URL}" --prefer-binary

for f in ${PAK_POST_FILES}; do
  install_req_file "${WORKDIR}/${f}" || true
done

# (Pas de hotfix NumPy ici — pakZ/constraints décident)

# ────────────────────────────────────────────────────────────────────────────────
# 5) Sanity check
# ────────────────────────────────────────────────────────────────────────────────
log "Sanity check versions clés…"
"${PYTHON_EXE}" - <<'PY'
import importlib, sys
mods = ("torch","torchvision","torchaudio","xformers","numpy")
for m in mods:
    try:
        mod = importlib.import_module(m)
        print(f"{m:10s} {getattr(mod,'__version__','?')}")
    except Exception as e:
        print(f"{m:10s} IMPORT FAIL -> {e}", file=sys.stderr)
        sys.exit(1)
PY

pip_exe list

# ────────────────────────────────────────────────────────────────────────────────
# 6) Outils externes
# ────────────────────────────────────────────────────────────────────────────────
BIN_SCRIPTS="${PYDIR}/Scripts"
mkdir -p "${BIN_SCRIPTS}"

log "Récupération Ninja (${NINJA_VERSION})…"
if [[ "${NINJA_VERSION}" == "latest" ]]; then
  curl_dl "https://github.com/ninja-build/ninja/releases/latest/download/ninja-win.zip" "${WORKDIR}/ninja.zip"
else
  curl_dl "https://github.com/ninja-build/ninja/releases/download/${NINJA_VERSION}/ninja-win.zip" "${WORKDIR}/ninja.zip"
fi
unzip -q -o "${WORKDIR}/ninja.zip" -d "${BIN_SCRIPTS}"
rm -f "${WORKDIR}/ninja.zip"

log "Récupération aria2 (${ARIA2_VERSION})…"
curl_dl "https://github.com/aria2/aria2/releases/download/release-${ARIA2_VERSION}/aria2-${ARIA2_VERSION}-win-64bit-build1.zip" "${WORKDIR}/aria2.zip"
unzip -q -o "${WORKDIR}/aria2.zip" -d "${WORKDIR}/aria2"
if [[ "${VERIFY_ZIP_CONTENT}" == "1" && ! -f "${WORKDIR}/aria2"/*/aria2c.exe ]]; then die "aria2c.exe introuvable dans l'archive."; fi
mv "${WORKDIR}/aria2"/*/aria2c.exe "${BIN_SCRIPTS}/" 2>/dev/null || true
rm -rf "${WORKDIR}/aria2" "${WORKDIR}/aria2.zip"

log "Récupération FFmpeg (${FFMPEG_VERSION})…"
curl_dl "https://github.com/GyanD/codexffmpeg/releases/download/${FFMPEG_VERSION}/ffmpeg-${FFMPEG_VERSION}-full_build.zip" "${WORKDIR}/ffmpeg.zip"
unzip -q -o "${WORKDIR}/ffmpeg.zip" -d "${WORKDIR}/ffmpeg"
if [[ "${VERIFY_ZIP_CONTENT}" == "1" && ! -f "${WORKDIR}/ffmpeg"/*/bin/ffmpeg.exe ]]; then die "ffmpeg.exe introuvable dans l'archive."; fi
mv "${WORKDIR}/ffmpeg"/*/bin/ffmpeg.exe "${BIN_SCRIPTS}/" 2>/dev/null || true
rm -rf "${WORKDIR}/ffmpeg" "${WORKDIR}/ffmpeg.zip"

du -hd1 "${WORKDIR}" || true
log "Stage1 terminé."
