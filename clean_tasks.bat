@echo off
for /f "tokens=*" %%a in ('schtasks /query /fo LIST ^| findstr /i "Adhan_Prayer"') do (
    for /f "tokens=2 delims=\" %%b in ("%%a") do (
        schtasks /delete /tn "%%b" /f >nul 2>&1
    )
)
echo Cleaned all Adhan tasks.
