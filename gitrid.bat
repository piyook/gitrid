@echo off
rem Runs gitrid in WSL from cmd. PowerShell uses gitrid.ps1, not this file.
rem In cmd put a pattern in double quotes, "^fix/", or cmd drops the ^.
wsl --exec /usr/local/bin/gitrid.sh %*
