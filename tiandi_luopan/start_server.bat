@echo off
chcp 65001 >nul
title 演象罗盘 - 本地真机调试与PWA服务
cd /d "%~dp0"
echo ============================================================
echo   演象 · 时空罗盘 - 本地调试与iPhone PWA免签服务器
echo ============================================================
echo 正在启动服务器...
python tools\serve_ios_web.py
pause
