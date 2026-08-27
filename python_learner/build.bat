@echo off
rem 打包为单个 exe：生成 dist\Python学习助手.exe
cd /d %~dp0
pyinstaller build.spec --noconfirm --clean
pause
