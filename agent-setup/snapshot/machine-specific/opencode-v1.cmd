@ECHO off
SETLOCAL
SET dp0=%~dp0
"%dp0%\node_modules\opencode-ai\bin\opencode.exe" %*
