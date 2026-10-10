; Installer für "Overlord – Herrscher von Nazarick"
; Bauen:  makensis installer/overlord.nsi   (erwartet build/windows/OverlordNazarick.exe)
Unicode true
!include "MUI2.nsh"

!define APPNAME "Overlord - Herrscher von Nazarick"
!define APPDIR "Overlord Nazarick"
!define EXE "OverlordNazarick.exe"
!define VERSION "1.0.0"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\OverlordNazarick"

Name "${APPNAME}"
OutFile "..\build\OverlordNazarick-Setup-${VERSION}.exe"
InstallDir "$PROGRAMFILES64\${APPDIR}"
InstallDirRegKey HKLM "Software\OverlordNazarick" "InstallDir"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
BrandingText "Das Große Grab von Nazarick"

!define MUI_ICON "overlord.ico"
!define MUI_UNICON "overlord.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "welcome.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "welcome.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "header.bmp"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Willkommen im Großen Grab von Nazarick"
!define MUI_WELCOMEPAGE_TEXT "Dieser Assistent installiert ${APPNAME}.$\r$\n$\r$\nDie Wächter erwarten die Befehle ihres Herrn.$\r$\n$\r$\nKlicke auf Weiter, um fortzufahren."
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Nazarick jetzt betreten"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "German"

VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=${LANG_GERMAN} "ProductName" "${APPNAME}"
VIAddVersionKey /LANG=${LANG_GERMAN} "FileDescription" "Installer für ${APPNAME}"
VIAddVersionKey /LANG=${LANG_GERMAN} "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=${LANG_GERMAN} "ProductVersion" "${VERSION}"
VIAddVersionKey /LANG=${LANG_GERMAN} "LegalCopyright" "Fan-Projekt"

Section "Spiel" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "..\build\windows\${EXE}"
  File "overlord.ico"
  WriteUninstaller "$INSTDIR\Deinstallieren.exe"

  CreateDirectory "$SMPROGRAMS\${APPDIR}"
  CreateShortcut "$SMPROGRAMS\${APPDIR}\${APPNAME}.lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\overlord.ico"
  CreateShortcut "$SMPROGRAMS\${APPDIR}\Deinstallieren.lnk" "$INSTDIR\Deinstallieren.exe"
  CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\overlord.ico"

  WriteRegStr HKLM "Software\OverlordNazarick" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "${UNINSTKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr HKLM "${UNINSTKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINSTKEY}" "Publisher" "Nazarick Fan-Projekt"
  WriteRegStr HKLM "${UNINSTKEY}" "DisplayIcon" "$INSTDIR\overlord.ico"
  WriteRegStr HKLM "${UNINSTKEY}" "UninstallString" '"$INSTDIR\Deinstallieren.exe"'
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\${EXE}"
  Delete "$INSTDIR\overlord.ico"
  Delete "$INSTDIR\Deinstallieren.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\${APPDIR}\*.lnk"
  RMDir "$SMPROGRAMS\${APPDIR}"
  Delete "$DESKTOP\${APPNAME}.lnk"
  DeleteRegKey HKLM "${UNINSTKEY}"
  DeleteRegKey HKLM "Software\OverlordNazarick"
  ; Spielstände in %APPDATA% bleiben absichtlich erhalten.
SectionEnd
