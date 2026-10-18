@echo off
setlocal
cd /d "%~dp0"
set "inn_engine=%~dp0openclonk.exe"
if not exist "%inn_engine%" set "inn_engine=%ProgramFiles%\OpenClonk\openclonk.exe"
if not exist "%inn_engine%" set "inn_engine=%ProgramFiles(x86)%\OpenClonk\openclonk.exe"
if not exist "%inn_engine%" (
 echo Install OpenClonk 8.1 first, or download the full Windows package.
 start "" "https://www.openclonk.org/download/"
 pause
 exit /b 1
)
set "inn_settings=%LOCALAPPDATA%\AfterHoursInn-OpenClonk"
set "inn_userdata=%LOCALAPPDATA:\=/%/AfterHoursInn-OpenClonk/user"
if not exist "%inn_settings%\user" mkdir "%inn_settings%\user"
if not exist "%inn_settings%\config" (
 > "%inn_settings%\config" echo [General]
 >> "%inn_settings%\config" echo UserDataPath="%inn_userdata%"
 >> "%inn_settings%\config" echo Language="US - English"
 >> "%inn_settings%\config" echo [Graphics]
 >> "%inn_settings%\config" echo ResolutionX=1280
 >> "%inn_settings%\config" echo ResolutionY=720
 >> "%inn_settings%\config" echo WindowX=1280
 >> "%inn_settings%\config" echo WindowY=720
 >> "%inn_settings%\config" echo Windowed=1
 >> "%inn_settings%\config" echo MultiSampling=0
)
"%inn_engine%" --fullscreen --nonetwork "--config=%inn_settings%\config" "%~dp0AfterHours.ocs" "%~dp0Innkeeper.ocp"
