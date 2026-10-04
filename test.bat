@echo off
chcp 65001 >nul
"C:\Program Files\LOVE\lovec.exe" . --test
exit /b %ERRORLEVEL%
