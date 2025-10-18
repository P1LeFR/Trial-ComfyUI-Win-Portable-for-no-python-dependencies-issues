#!/usr/bin/env bash
set -Eeuo pipefail

# ╭──────────────────────────────────────────────────────────────────────────────╮
# │ Stage 3 — Packaging ComfyUI portable (modulaire, non figé)                  │
# │ - Formats et niveaux de compression configurables                            │
# │ - Séparation optionnelle des modèles                                         │
# │ - Nommage d'archive paramétrable (auto-cu* si possible)                      │
# │ - Découpes en volumes pour GitHub                                            │
# │ - Hash SHA256 générés (si outil dispo)                                       │
# ╰──────────────────────────────────────────────────────────────────────────────╯

# ────────────────────────────────────────────────────────────────────────────────
# Paramètres (surclassables via ENV)
# ────────────────────────────────────────────────────────────────────────────────
: "${WORKDIR:="$(pwd)"}"
: "${PORTABLE_DIR:="${WORKDIR}/ComfyUI_Windows_portable"}"
: "${COMFY_DIR:="${PORTABLE_DIR}/ComfyUI"}"
: "${MODELS_DIR:="${COMFY_DIR}/models"}"
: "${SEPARATE_MODELS:=1}"                     # 1: modèles dans une archive à part
: "${OUT_DIR:="${WORKDIR}"}"                  # répertoire de sortie des archives

# 7-Zip — binaire
: "${SEVENZ_EXE:="C:/Program Files/7-Zip/7z.exe"}"  # surclassable; fallback "7z" si non trouvé

# Formats & options d’archive
: "${MAIN_FORMAT:="7z"}"                      # 7z | zip
: "${MODELS_FORMAT:="zip"}"                   # 7z | zip
: "${VOL_SIZE:="2140000000b"}"                # taille des volumes
: "${MAIN_MX:=7}"                             # niveau compression principal (3/5/7…)
: "${MAIN_FB:=64}"                            # fast bytes
: "${MAIN_DICT:="128m"}"                      # taille dictionnaire
: "${MAIN_SOLID:=on}"                         # on/off
: "${MAIN_BCJ2:=BCJ2}"                        # filtre
: "${USE_LZMA2:=1}"                           # 1: LZMA2, 0: LZMA

# Nom d’archive
: "${PKG_BASENAME:=""}"                       # si vide: auto "ComfyUI_Windows_portable_${PKG_SUFFIX}"
: "${PKG_SUFFIX:=""}"                         # si vide: tentative d’auto-détection cuXXX
: "${ADD_TIMESTAMP:=0}"                       # 1: suffixe -YYYYmmddHHMMSS

# Divers
: "${LIST_BEFORE:=1}"                         # 1: afficher tailles avant packaging
: "${LIST_AFTER:=1}"                          # 1: afficher tailles après packaging
: "${KEEP_MODELS_DIR:=0}"                     # 1: ne pas restaurer/récréer models dans ComfyUI
: "${GEN_HASH:=1}"                            # 1: générer .sha256 si possible

# ────────────────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────────────────
log(){ printf '\n\033[1;34m[stage3]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31m[error]\033[0m %s\n' "$*"; exit 1; }

have_cmd(){ command -v "$1" >/dev/null 2>&1; }

detect_7z(){
  # retourne un chemin exécutable vers 7z
  local exe="${SEVENZ_EXE}"
  if [[ -f "$exe" ]]; then printf '%s\n' "$exe"; return 0; fi
  if have_cmd 7z; then printf '7z\n'; return 0; fi
  die "7-Zip introuvable. Surclasse SEVENZ_EXE ou ajoute 7z au PATH."
}

hash_file(){
  # produit .sha256 si possible
  local f="$1"
  [[ "${GEN_HASH}" != "1" ]] && return 0
  if have_cmd sha256sum; then
    sha256sum "$f" > "${f}.sha256" || warn "sha256sum a échoué pour $f"
  elif have_cmd certutil; then
    certutil -hashfile "$f" SHA256 | tr -d '\r' > "${f}.sha256" || warn "certutil a échoué pour $f"
  else
    warn "Aucun outil de hash (sha256sum/certutil) — skip."
  fi
}

detect_pkg_suffix(){
  # Si PKG_SUFFIX vide, essaie torch.version.cuda via le Python portable
  [[ -n "${PKG_SUFFIX}" ]] && { printf '%s\n' "${PKG_SUFFIX}"; return 0; }
  local py="${PORTABLE_DIR}/python_standalone/python.exe"
  if [[ -x "$py" ]]; then
    local cu
    cu="$("$py" - <<'PY' 2>/dev/null || true
import torch, re
v = getattr(torch.version, "cuda", "") or ""
m = re.search(r"^(\d+)\.(\d+)", v)
print(f"cu{m.group(1)}{m.group(2)}" if m else "")
PY
)"
    if [[ -n "$cu" ]]; then printf '%s\n' "$cu"; return 0; fi
  fi
  printf 'cu'  # fallback générique
}

archive_name(){
  local suffix ts=""
  suffix="$(detect_pkg_suffix)"
  if [[ -z "${PKG_BASENAME}" ]]; then
    PKG_BASENAME="ComfyUI_Windows_portable_${suffix}"
  fi
  if [[ "${ADD_TIMESTAMP}" == "1" ]]; then
    ts="-$(date +%Y%m%d%H%M%S)"
  fi
  printf '%s%s' "${PKG_BASENAME}" "${ts}"
}

pack_dir(){
  # $1=dir $2=outbase $3=format (7z|zip) $4=volsize (ex: 2140000000b) $5=comment
  local dir="$1" outbase="$2" fmt="$3" vs="$4" label="$5"
  local zexe; zexe="$(detect_7z)"
  local tflag="-t${fmt}"
  local ofile="${OUT_DIR}/${outbase}.${fmt}"
  local args=( a "${tflag}" )
  if [[ "${fmt}" == "7z" ]]; then
    local m0="lzma"
    [[ "${USE_LZMA2}" == "1" ]] && m0="lzma2"
    args+=( "-m0=${m0}" "-mx=${MAIN_MX}" "-mfb=${MAIN_FB}" "-md=${MAIN_DICT}" "-ms=${MAIN_SOLID}" "-mf=${MAIN_BCJ2}" )
  fi
  [[ -n "${vs}" ]] && args+=( "-v${vs}" )
  args+=( "${ofile}" "${dir}" )
  log "Compression ${label}: ${ofile} (format=${fmt}, vol=${vs:-none}, lvl=${MAIN_MX})"
  "$zexe" "${args[@]}"
  # hash pour chaque volume/part
  for f in "${ofile}"*; do
    [[ -f "$f" ]] && hash_file "$f"
  done
}

# ────────────────────────────────────────────────────────────────────────────────
# Pré-listings (optionnels)
# ────────────────────────────────────────────────────────────────────────────────
ls -lahF
if [[ "${LIST_BEFORE}" == "1" ]]; then
  du -hd2 "${PORTABLE_DIR}" || true
  du -hd1 "${COMFY_DIR}/custom_nodes" || true
  du -h   "${MODELS_DIR}" || true
fi

# ────────────────────────────────────────────────────────────────────────────────
# Séparation des modèles (optionnelle)
# ────────────────────────────────────────────────────────────────────────────────
TMP_ROOT="${WORKDIR}/m_folder"
if [[ "${SEPARATE_MODELS}" == "1" ]]; then
  log "Séparation des modèles…"
  mkdir -p "${TMP_ROOT}/ComfyUI_Windows_portable/ComfyUI"
  if [[ -d "${MODELS_DIR}" ]]; then
    mv "${MODELS_DIR}" "${TMP_ROOT}/ComfyUI_Windows_portable/ComfyUI/models"
  else
    warn "Dossier models introuvable, rien à séparer."
  fi
  # Restaure un dossier models (vide) si souhaité
  if [[ "${KEEP_MODELS_DIR}" != "1" ]]; then
    mkdir -p "${MODELS_DIR}"
  fi
fi

# ────────────────────────────────────────────────────────────────────────────────
# Packaging
# ────────────────────────────────────────────────────────────────────────────────
BASENAME="$(archive_name)"

# Archive principale (sans modèles si séparés)
pack_dir "${PORTABLE_DIR}" "${BASENAME}" "${MAIN_FORMAT}" "${VOL_SIZE}" "principal"

# Archive des modèles (si séparés)
if [[ "${SEPARATE_MODELS}" == "1" ]]; then
  pushd "${TMP_ROOT}" >/dev/null
  pack_dir "ComfyUI_Windows_portable" "models" "${MODELS_FORMAT}" "${VOL_SIZE}" "modèles"
  # renvoie les archives à OUT_DIR
  for f in ./*."${MODELS_FORMAT}"*; do
    mv "$f" "${OUT_DIR}/"
  done
  popd >/dev/null
fi

# ────────────────────────────────────────────────────────────────────────────────
# Post-listings (optionnels)
# ────────────────────────────────────────────────────────────────────────────────
ls -lahF "${OUT_DIR}"
if [[ "${LIST_AFTER}" == "1" ]]; then
  du -h "${OUT_DIR}"/* 2>/dev/null || true
fi

log "Packaging terminé."
