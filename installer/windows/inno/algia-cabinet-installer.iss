#define MyAppName "ALGIA Cabinet"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "ALGIA Data"
#define MyAppExeName "algia-cabinet-installer-win64"

[Setup]
AppId={{A1CF6DFB-90F1-49D7-9D6E-A08E0F4D0101}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\ALGIA Cabinet
DefaultGroupName=ALGIA Cabinet
DisableProgramGroupPage=yes
OutputDir=..\..\..\releases
OutputBaseFilename={#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\INSTALLER-ALGIA-CABINET.bat

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Files]
Source: "..\..\..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\INSTALLATION_CLIENT.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\.env.example"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\docker-compose.yml"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\INSTALLER-ALGIA-CABINET.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\DEMARRER-ALGIA-CABINET.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\ARRETER-ALGIA-CABINET.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\SAUVEGARDE-ALGIA-CABINET.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\bootstrap\*"; DestDir: "{app}\bootstrap"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\..\manifests\*"; DestDir: "{app}\manifests"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\..\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\..\installer\windows\scripts\*"; DestDir: "{app}\installer\windows\scripts"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ALGIA Cabinet"; Filename: "http://localhost:8080"
Name: "{userdesktop}\ALGIA Cabinet"; Filename: "http://localhost:8080"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Creer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"; Flags: unchecked

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\installer\windows\scripts\install.ps1"" -SourceDir ""{src}"""; Description: "Installer et demarrer ALGIA Cabinet"; Flags: postinstall waituntilterminated
