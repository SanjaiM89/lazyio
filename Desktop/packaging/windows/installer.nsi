; Lazyio Windows installer (NSIS). Built by CI: __VERSION__ and __SRC__ are substituted.
!include "MUI2.nsh"
!include "x64.nsh"

Name "Lazyio __VERSION__"
OutFile "lazyio-__VERSION__-windows-x86_64-setup.exe"
InstallDir "$PROGRAMFILES64\Lazyio"
RequestExecutionLevel admin
SetCompressor /SOLID lzma

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Lazyio" SecMain
  SetOutPath "$INSTDIR"
  File /r "__SRC__\*.*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\Lazyio"
  CreateShortcut "$SMPROGRAMS\Lazyio\Lazyio.lnk" "$INSTDIR\bin\lazyio.exe"
  CreateShortcut "$SMPROGRAMS\Lazyio\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Lazyio" "DisplayName" "Lazyio __VERSION__"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Lazyio" "UninstallString" "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
  RMDir /r "$INSTDIR"
  Delete "$SMPROGRAMS\Lazyio\Lazyio.lnk"
  Delete "$SMPROGRAMS\Lazyio\Uninstall.lnk"
  RMDir "$SMPROGRAMS\Lazyio"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Lazyio"
SectionEnd
