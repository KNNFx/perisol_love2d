@echo off
rem Windows shim. Source of truth: Makefile (make test-love runs the same flags). lovec.exe is the console build so output and exit code are visible.
chcp 65001 >nul
"C:\Program Files\LOVE\lovec.exe" . --test
exit /b %ERRORLEVEL%
