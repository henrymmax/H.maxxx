@echo off
setlocal
cd /d "%~dp0"
set "LOG=%~dp0build_log.txt"
echo Log do build > "%LOG%"

rem --- localizar o Python ---
set "PY="
where py >nul 2>&1 && set "PY=py"
if not defined PY ( where python >nul 2>&1 && set "PY=python" )
if not defined PY (
  echo [ERRO] Python nao encontrado. Instale em python.org e marque "Add Python to PATH".
  goto fim
)
echo Usando: %PY%
%PY% --version

rem --- conferir arquivos necessarios ---
for %%F in (hmax_launcher.py F1_LS_3_1_0.ahk Pass64_original.exe Pass32.exe Hmaxlogo.ico Hmaxlogo.png) do (
  if not exist "%%F" (
    echo [ERRO] Arquivo ausente na pasta: %%F
    goto fim
  )
)
if not exist "UX" (
  echo [ERRO] Pasta UX ausente.
  goto fim
)

echo === Instalando PyInstaller ===
%PY% -m pip install --upgrade pyinstaller >> "%LOG%" 2>&1
if errorlevel 1 (
  echo [ERRO] Falha ao instalar o PyInstaller. Veja build_log.txt
  type "%LOG%"
  goto fim
)

echo === Gerando Hmax_Python.exe ===
%PY% -m PyInstaller --noconfirm --clean --onefile --noconsole --name Hmax --icon "Hmaxlogo.ico" --add-data "F1_LS_3_1_0.ahk;." --add-data "Pass64_original.exe;." --add-data "Pass32.exe;." --add-data "Hmaxlogo.ico;." --add-data "Hmaxlogo.png;." --add-data "UX;UX" hmax_launcher.py >> "%LOG%" 2>&1
if errorlevel 1 (
  echo [ERRO] Falha no PyInstaller. Ultimas linhas do log:
  powershell -NoProfile -Command "Get-Content -Tail 25 '%LOG%'"
  goto fim
)

if exist "dist\Hmax.exe" (
  copy /y "dist\Hmax.exe" "Hmax_Python.exe" >nul
  echo.
  echo Pronto! Executavel: %~dp0Hmax_Python.exe
) else (
  echo [ERRO] dist\Hmax.exe nao foi gerado. Veja build_log.txt
)

:fim
echo.
pause
endlocal
