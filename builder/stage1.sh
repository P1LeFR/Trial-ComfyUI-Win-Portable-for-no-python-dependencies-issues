#!/bin/bash
set -eux

workdir=$(pwd)
pip_exe="${workdir}/python_standalone/python.exe -s -m pip"

export GIT_ASKPASS=echo
export PIP_DEFAULT_TIMEOUT=120
export PIP_NO_INPUT=1
export PYTHONPYCACHEPREFIX="${workdir}/pycache1"
export PIP_NO_WARN_SCRIPT_LOCATION=0

ls -lahF

# ⚙️ Python standalone 3.11 (plus compatible extensions)
curl -sSL \
  https://github.com/astral-sh/python-build-standalone/releases/download/20250408/cpython-3.11.9+20250408-x86_64-pc-windows-msvc-install_only.tar.gz \
  -o python.tar.gz
tar -zxf python.tar.gz
mv python python_standalone

# pip de base
$pip_exe install --upgrade pip wheel setuptools packaging --prefer-binary

# pytorch officiel CUDA 12.6 compatible RTX 5090
$pip_exe install torch==2.5.1+cu126 torchvision==0.20.1+cu126 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu126

# xformers compatible (blackwell patch)
$pip_exe install xformers==0.0.28.post3 --prefer-binary

# reste des dépendances
$pip_exe install -r "$workdir/pak4.txt" --prefer-binary
$pip_exe install -r "$workdir/pak5.txt" --prefer-binary
$pip_exe install -r "$workdir/pak6.txt" --prefer-binary
$pip_exe install -r "$workdir/pak7.txt" --prefer-binary
$pip_exe install -r "$workdir/pak8.txt" --prefer-binary

$pip_exe install --upgrade albucore albumentations --prefer-binary

# comfyui requirements (dernière version tag)
latest_tag=$(curl -s https://api.github.com/repos/comfyanonymous/ComfyUI/tags | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
$pip_exe install -r "https://github.com/comfyanonymous/ComfyUI/raw/refs/tags/${latest_tag}/requirements.txt" --prefer-binary

$pip_exe list

# Ninja
curl -sSL https://github.com/ninja-build/ninja/releases/latest/download/ninja-win.zip -o ninja-win.zip
unzip -q -o ninja-win.zip -d "$workdir/python_standalone/Scripts"
rm ninja-win.zip

# aria2
curl -sSL https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0-win-64bit-build1.zip -o aria2.zip
unzip -q aria2.zip -d "$workdir/aria2"
mv "$workdir/aria2"/*/aria2c.exe "$workdir/python_standalone/Scripts/"
rm aria2.zip

# ffmpeg
curl -sSL https://github.com/GyanD/codexffmpeg/releases/download/7.1.1/ffmpeg-7.1.1-full_build.zip -o ffmpeg.zip
unzip -q ffmpeg.zip -d "$workdir/ffmpeg"
mv "$workdir/ffmpeg"/*/bin/ffmpeg.exe "$workdir/python_standalone/Scripts/"
rm ffmpeg.zip

du -hd1
