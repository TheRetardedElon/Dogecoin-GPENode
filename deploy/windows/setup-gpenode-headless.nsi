; Dogecoin GPENode / Core Pro Headless — Windows installer (NSIS)
; Wizard UI: welcome, license, components, directory, install, finish.
; Does not ship Qt GUI. Same mainnet consensus as Core Pro.

!ifndef VERSION
  !define VERSION "1.14.102"
!endif
!ifndef OUT_SETUP
  !define OUT_SETUP "dogecoin-gpenode-${VERSION}-win64-setup.exe"
!endif
!ifndef BIN_DIR
  !define BIN_DIR "bin"
!endif
!ifndef ASSETS
  !define ASSETS "C:\dogedev\share\pixmaps"
!endif

Name "Dogecoin GPENode (Core Pro Headless)"
OutFile "${OUT_SETUP}"
Unicode true
RequestExecutionLevel admin
SetCompressor /SOLID lzma
InstallDir "$PROGRAMFILES64\DogecoinGPENode"
InstallDirRegKey HKLM "Software\DogecoinGPENode" "InstallPath"
BrandingText "Dogecoin GPENode — same mainnet consensus · no Qt GUI"

!define REGKEY "Software\DogecoinGPENode"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\DogecoinGPENode"
!define SERVICE "DogecoinGPENode"
!define COMPANY "Dogecoin GPENode / Core Pro"
!define URL "https://github.com/TheRetardedElon/Dogecoin-GPENode"

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"
!include "WinMessages.nsh"

; --- Modern UI ---
!define MUI_ABORTWARNING
!define MUI_ICON "${ASSETS}\dogecoin.ico"
!define MUI_UNICON "${ASSETS}\dogecoin.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP "${ASSETS}\nsis-header.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "${ASSETS}\nsis-wizard.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "${ASSETS}\nsis-wizard.bmp"
!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_UNFINISHPAGE_NOAUTOCLOSE
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchStatus
!define MUI_FINISHPAGE_RUN_TEXT "Open GPENode status (maximized)"
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\README.txt"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "View README"
!define MUI_FINISHPAGE_LINK "GPENode on GitHub"
!define MUI_FINISHPAGE_LINK_LOCATION "${URL}"

!define MUI_WELCOMEPAGE_TITLE "Dogecoin GPENode Headless"
!define MUI_WELCOMEPAGE_TEXT "This installs a headless Dogecoin node (dogecoind) for operators.$\r$\n$\r$\n- Same mainnet consensus as Core Pro$\r$\n- No Qt desktop wallet GUI$\r$\n- Optional Windows Service$\r$\n$\r$\nClick Next to continue."

!define MUI_LICENSEPAGE_TEXT_TOP "Please review the license agreement before installing Dogecoin GPENode."
!define MUI_LICENSEPAGE_TEXT_BOTTOM "If you accept the terms, click I Agree to continue. You must accept the agreement to install."
!define MUI_LICENSEPAGE_BUTTON "I &Agree"

!define MUI_COMPONENTSPAGE_TEXT_TOP "Select optional components. Core binaries are always installed."
!define MUI_COMPONENTSPAGE_TEXT_COMPLIST "Optional features:"

!define MUI_DIRECTORYPAGE_TEXT_TOP "Setup will install Dogecoin GPENode Headless in the following folder.$\r$\n$\r$\nNode data (chainstate/wallet) defaults to ProgramData and is configured after install."

!define MUI_FINISHPAGE_TITLE "Installation complete"
!define MUI_FINISHPAGE_TEXT "Dogecoin GPENode Headless has been installed.$\r$\n$\r$\nYour unique RPC password is in the data folder:$\r$\n  RPC-CREDENTIALS.txt  and  dogecoin.conf$\r$\nRPC is bound to 127.0.0.1 by default."

Var StartMenuFolder
Var DataDir
Var RpcPassword
Var RpcUser
Var RpcAckCheckbox
Var RpcDlg
Var RpcPassEdit

; After Vars so $RpcUser / $RpcPassword resolve correctly
!include "nsis-rpc-credentials.nsh"
; Extractable during .onInit for crypto password generation
ReserveFile "gen-rpc-password.ps1"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE.txt"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
Page custom RpcCredentialsPage RpcCredentialsPageLeave
!insertmacro MUI_PAGE_STARTMENU Application $StartMenuFolder
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductName" "Dogecoin GPENode Headless"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductVersion" "${VERSION}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "CompanyName" "${COMPANY}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileDescription" "Dogecoin Core Pro headless node installer"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalCopyright" "MIT — Dogecoin Core / Core Pro contributors"
VIAddVersionKey /LANG=${LANG_ENGLISH} "Comments" "No Qt GUI. Same mainnet consensus."

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "This installer requires 64-bit Windows."
    Abort
  ${EndIf}
  SetRegView 64
  ; NSIS has no $PROGRAMDATA — resolve from environment
  ReadEnvStr $0 "ProgramData"
  ${If} $0 == ""
    StrCpy $0 "$WINDIR\..\ProgramData"
  ${EndIf}
  StrCpy $DataDir "$0\DogecoinGPENode"
  ; Unique password for THIS install (never CHANGE_ME / shared default)
  Call GenerateRpcPassword
FunctionEnd

; --- Required: binaries ---
Section "Core binaries (required)" SecCore
  SectionIn RO
  SetOutPath "$INSTDIR"
  SetOverwrite on

  File /oname=README.txt "README.txt"
  File /oname=LICENSE.txt "LICENSE.txt"
  File "install-service.ps1"
  File "uninstall-service.ps1"
  File "status-service.ps1"
  File "write-install-conf.ps1"
  File "gen-rpc-password.ps1"
  File "launch-status.cmd"
  File "launch-tui.cmd"

  SetOutPath "$INSTDIR\bin"
  File "${BIN_DIR}\dogecoind.exe"
  File "${BIN_DIR}\dogecoin-cli.exe"
  File "${BIN_DIR}\gpenode-ops.exe"
  File "${BIN_DIR}\gpenode-tray.exe"
  ; Optional TUI
  IfFileExists "${BIN_DIR}\gpenode-tui.exe" 0 skip_tui
    File "${BIN_DIR}\gpenode-tui.exe"
  skip_tui:

  SetOutPath "$INSTDIR\conf"
  File "conf\dogecoin.dump.conf.example"
  File "conf\dogecoin.settlement.conf.example"

  ; Data dir + unique credentials (never shared default password)
  CreateDirectory "$DataDir"
  CreateDirectory "$DataDir\snapshots"
  CreateDirectory "$DataDir\logs"
  ; Write conf with installer-generated password (keeps existing conf if present)
  ; UTF-8 no BOM via write-install-conf.ps1
  nsExec::ExecToLog 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\write-install-conf.ps1" -DataDir "$DataDir" -RpcUser "$RpcUser" -RpcPassword "$RpcPassword" -Profile dump -ExampleConf "$INSTDIR\conf\dogecoin.dump.conf.example"'
  Pop $1
  DetailPrint "write-install-conf.ps1 exit=$1"
  ${If} $1 != 0
    DetailPrint "WARNING: conf write failed exit=$1 - check $DataDir\logs"
    MessageBox MB_OK|MB_ICONEXCLAMATION "Could not write dogecoin.conf (exit $1).$\r$\n$\r$\nCheck logs under:$\r$\n$DataDir\logs$\r$\n$\r$\nYou can re-run write-install-conf.ps1 as Admin."
  ${EndIf}
  WriteRegStr HKLM "${REGKEY}" "RpcUser" "$RpcUser"
  ; Do NOT store password in registry - only in conf / credentials file

  WriteRegStr HKLM "${REGKEY}" "InstallPath" "$INSTDIR"
  WriteRegStr HKLM "${REGKEY}" "DataDir" "$DataDir"
  WriteRegStr HKLM "${REGKEY}" "Version" "${VERSION}"

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  WriteRegStr HKLM "${UNINSTKEY}" "DisplayName" "Dogecoin GPENode (Core Pro Headless)"
  WriteRegStr HKLM "${UNINSTKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINSTKEY}" "Publisher" "${COMPANY}"
  WriteRegStr HKLM "${UNINSTKEY}" "URLInfoAbout" "${URL}"
  WriteRegStr HKLM "${UNINSTKEY}" "DisplayIcon" "$INSTDIR\bin\dogecoind.exe"
  WriteRegStr HKLM "${UNINSTKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKLM "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "${UNINSTKEY}" "EstimatedSize" "$0"

  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
    CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
    ; Maximized launchers via .cmd (PS first, CMD/TUI fallback) - SW_SHOWMAXIMIZED
    CreateShortCut "$SMPROGRAMS\$StartMenuFolder\GPENode Status.lnk" \
      "$INSTDIR\launch-status.cmd" "" \
      "$INSTDIR\bin\dogecoind.exe" 0 SW_SHOWMAXIMIZED
    IfFileExists "$INSTDIR\bin\gpenode-tui.exe" 0 skip_tui_sm
      CreateShortCut "$SMPROGRAMS\$StartMenuFolder\GPENode TUI.lnk" \
        "$INSTDIR\launch-tui.cmd" "" \
        "$INSTDIR\bin\dogecoind.exe" 0 SW_SHOWMAXIMIZED
    skip_tui_sm:
    IfFileExists "$INSTDIR\bin\gpenode-tray.exe" 0 skip_tray_sm
      CreateShortCut "$SMPROGRAMS\$StartMenuFolder\GPENode Tray.lnk" \
        "$INSTDIR\bin\gpenode-tray.exe" "" \
        "$INSTDIR\bin\gpenode-tray.exe"
    skip_tray_sm:
    CreateShortCut "$SMPROGRAMS\$StartMenuFolder\Open data folder.lnk" "$DataDir"
    CreateShortCut "$SMPROGRAMS\$StartMenuFolder\Open install logs.lnk" "$DataDir\logs"
    CreateShortCut "$SMPROGRAMS\$StartMenuFolder\Edit dogecoin.conf.lnk" "notepad.exe" "$DataDir\dogecoin.conf"
    CreateShortCut "$SMPROGRAMS\$StartMenuFolder\RPC credentials.lnk" "notepad.exe" "$DataDir\RPC-CREDENTIALS.txt"
    CreateShortCut "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  !insertmacro MUI_STARTMENU_WRITE_END
SectionEnd

; --- Optional: Windows Service ---
Section "Install as Windows Service" SecService
  DetailPrint "Registering Windows Service via install-service.ps1..."
  ; Use the same PowerShell installer (reliable sc.exe quoting)
  nsExec::ExecToLog 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\install-service.ps1" -BinDir "$INSTDIR\bin" -DataDir "$DataDir" -ConfFile "$DataDir\dogecoin.conf" -ServiceName "${SERVICE}" -Profile dump'
  Pop $1
  DetailPrint "install-service.ps1 exit=$1"
  ${If} $1 != 0
    DetailPrint "Service install failed exit=$1 - see $DataDir\logs\install-*.log"
    MessageBox MB_OK|MB_ICONEXCLAMATION "Windows Service install failed (exit $1).$\r$\n$\r$\nDetails are in:$\r$\n$DataDir\logs$\r$\n$\r$\nFix: open elevated PowerShell and run:$\r$\n  $INSTDIR\install-service.ps1$\r$\n$\r$\nBinaries and dogecoin.conf were still installed."
    WriteRegDWORD HKLM "${REGKEY}" "ServiceInstalled" 0
  ${Else}
    WriteRegDWORD HKLM "${REGKEY}" "ServiceInstalled" 1
  ${EndIf}
SectionEnd

; --- Optional: desktop shortcut to status ---
Section "Desktop status shortcut" SecDesktop
  CreateShortCut "$DESKTOP\Dogecoin GPENode Status.lnk" \
    "$INSTDIR\launch-status.cmd" "" \
    "$INSTDIR\bin\dogecoind.exe" 0 SW_SHOWMAXIMIZED
  IfFileExists "$INSTDIR\bin\gpenode-tui.exe" 0 skip_desktop_tui
    CreateShortCut "$DESKTOP\Dogecoin GPENode TUI.lnk" \
      "$INSTDIR\launch-tui.cmd" "" \
      "$INSTDIR\bin\dogecoind.exe" 0 SW_SHOWMAXIMIZED
  skip_desktop_tui:
SectionEnd

; --- Optional: start tray with login ---
Section "Start tray icon with Windows" SecTray
  IfFileExists "$INSTDIR\bin\gpenode-tray.exe" 0 skip_tray_run
    ; Current-user Run key (session tray; does not require Admin elevation for the tray itself)
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "DogecoinGPENodeTray" '"$INSTDIR\bin\gpenode-tray.exe"'
    ; Launch once after install
    Exec '"$INSTDIR\bin\gpenode-tray.exe"'
  skip_tray_run:
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecCore} "dogecoind, dogecoin-cli, gpenode-ops (service host + CLI), conf examples, scripts."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecService} "Register gpenode-ops service-run as Windows Service (auto-start, restart on failure). RPC stays on 127.0.0.1."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "Desktop shortcuts: Status (maximized) and TUI if present."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecTray} "Launch GPENode tray icon at login (tooltip: INIT/IBD/SYNCED). Quitting tray does not stop the service."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Function LaunchStatus
  ; Maximized status via launch-status.cmd (PowerShell, else TUI/ops)
  Exec '"$INSTDIR\launch-status.cmd"'
FunctionEnd

Section "Uninstall"
  SetRegView 64
  ; Stop service if we installed it
  ReadRegDWORD $0 HKLM "${REGKEY}" "ServiceInstalled"
  ${If} $0 = 1
    nsExec::ExecToLog 'cmd /c sc stop ${SERVICE}'
    Sleep 2000
    nsExec::ExecToLog 'cmd /c sc delete ${SERVICE}'
    Sleep 1000
  ${EndIf}

  !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
  RMDir /r "$SMPROGRAMS\$StartMenuFolder"
  Delete "$DESKTOP\Dogecoin GPENode Status.lnk"
  Delete "$DESKTOP\Dogecoin GPENode TUI.lnk"
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "DogecoinGPENodeTray"

  Delete "$INSTDIR\Uninstall.exe"
  Delete "$INSTDIR\README.txt"
  Delete "$INSTDIR\LICENSE.txt"
  Delete "$INSTDIR\install-service.ps1"
  Delete "$INSTDIR\uninstall-service.ps1"
  Delete "$INSTDIR\status-service.ps1"
  Delete "$INSTDIR\write-install-conf.ps1"
  Delete "$INSTDIR\gen-rpc-password.ps1"
  Delete "$INSTDIR\launch-status.cmd"
  Delete "$INSTDIR\launch-tui.cmd"
  RMDir /r "$INSTDIR\bin"
  RMDir /r "$INSTDIR\conf"
  RMDir "$INSTDIR"

  DeleteRegKey HKLM "${UNINSTKEY}"
  DeleteRegKey HKLM "${REGKEY}"

  ReadEnvStr $0 "ProgramData"
  ${If} $0 == ""
    StrCpy $0 "$WINDIR\..\ProgramData"
  ${EndIf}
  MessageBox MB_OK|MB_ICONINFORMATION "Program files removed.$\r$\n$\r$\nNode data was kept at:$\r$\n$0\DogecoinGPENode$\r$\n$\r$\nDelete that folder manually if you want a full wipe."
SectionEnd
