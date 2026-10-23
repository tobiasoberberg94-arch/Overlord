; Installer für "Overlord – Herrscher von Nazarick" (Inno Setup 6)
; Bauen:  ISCC.exe installer\overlord.iss   (erwartet build\windows\OverlordNazarick.exe + .pck)
; Inno Setup statt NSIS, weil die Spieldaten größer als 2 GB sind.

#define AppName "Overlord - Herrscher von Nazarick"
#define AppVersion "2.5.0"
#define AppExe "OverlordNazarick.exe"

[Setup]
AppId={{6E0B7C2A-4E1D-4C5B-9F51-0A7A1D2B3C4D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Nazarick Fan-Projekt
DefaultDirName={autopf}\Overlord Nazarick
DefaultGroupName=Overlord Nazarick
OutputDir=..\build
OutputBaseFilename=OverlordNazarick-Setup-{#AppVersion}
SetupIconFile=overlord.ico
UninstallDisplayIcon={app}\overlord.ico
WizardImageFile=welcome.bmp
WizardSmallImageFile=header.bmp
WizardStyle=modern
Compression=lzma2/fast
SolidCompression=no
DiskSpanning=yes
DiskSliceSize=max
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "Verknüpfung auf dem Desktop anlegen"; GroupDescription: "Zusätzliche Verknüpfungen:"

[Files]
Source: "..\build\windows\OverlordNazarick.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\OverlordNazarick.pck"; DestDir: "{app}"; Flags: ignoreversion nocompression
Source: "overlord.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"; IconFilename: "{app}\overlord.ico"
Name: "{group}\Deinstallieren"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; IconFilename: "{app}\overlord.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Nazarick jetzt betreten"; Flags: nowait postinstall skipifsilent
