@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >NUL

set "BASE=%~dp0"
set "HF_HUB_OFFLINE=1"
set "HF_HUB_CACHE=%BASE%HuggingFaceHub"
set "TORCH_HOME=%BASE%TorchHome"
if not exist "%HF_HUB_CACHE%" mkdir "%HF_HUB_CACHE%" >NUL 2>&1
if not exist "%TORCH_HOME%" mkdir "%TORCH_HOME%" >NUL 2>&1

REM GPU optimal RTX 5090
set "EXTRA_ARGS=--use-pytorch-cross-attention --cuda-device 0"

set "AUTO_LAUNCH=1"
set "LISTEN_ALL=0"
set "COMFYUI_PORT="
set "PYTHONNOUSERSITE=1"
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
set "PYTHONPYCACHEPREFIX=%BASE%pycache"
set "PATH=%BASE%python_standalone;%BASE%python_standalone\Scripts;%BASE%MinGit\cmd;%BASE%ffmpeg;%PATH%"

REM xformers et triton activés
set "XFORMERS_FORCE_DISABLE_TRITON=0"

set "ARGS=--windows-standalone-build %EXTRA_ARGS%"
if not "%COMFYUI_PORT%"=="" set "ARGS=%ARGS% --port %COMFYUI_PORT%"
if "%AUTO_LAUNCH%"=="0" set "ARGS=%ARGS% --disable-auto-launch"
if "%LISTEN_ALL%"=="1" set "ARGS=%ARGS% --listen"

pushd "%BASE%"
echo [INFO] Launch: python ComfyUI\main.py %ARGS%
"%BASE%python_standalone\python.exe" -s ComfyUI\main.py %ARGS%
set "EC=%ERRORLEVEL%"
popd

echo.
echo ComfyUI exited (code %EC%).
pause
endlocal
