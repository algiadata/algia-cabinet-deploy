#define MyAppName "ALGIA Cabinet"
#define MyAppVersion "0.1.3"
#define MyAppPublisher "ALGIA Data"
#define MyAppExeName "ALGIA-Cabinet-Setup-v0.1.3"

[Setup]
AppId={{A1CF6DFB-90F1-49D7-9D6E-A08E0F4D0101}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\ALGIA Cabinet
DefaultGroupName=ALGIA Cabinet
DisableProgramGroupPage=no
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
Source: "..\..\..\.env.example"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\docker-compose.yml"; DestDir: "{app}"; Flags: ignoreversion

Source: "..\..\..\INSTALLER-ALGIA-CABINET.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\DEMARRER-ALGIA-CABINET.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\ARRETER-ALGIA-CABINET.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\SAUVEGARDE-ALGIA-CABINET.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\METTRE-A-JOUR-ALGIA-CABINET.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\RESTAURER-ALGIA-CABINET.bat"; DestDir: "{app}"; Flags: ignoreversion

Source: "..\..\..\bootstrap\*"; DestDir: "{app}\bootstrap"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\..\manifests\*"; DestDir: "{app}\manifests"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\..\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\..\installer\windows\scripts\*"; DestDir: "{app}\installer\windows\scripts"; Flags: ignoreversion recursesubdirs createallsubdirs

[Dirs]
Name: "{app}\backups"
Name: "{app}\logs"
Name: "{app}\state"
Name: "{app}\releases"

[Icons]
Name: "{group}\ALGIA Cabinet"; Filename: "http://localhost:8080"
Name: "{group}\Installer ALGIA Cabinet"; Filename: "{app}\INSTALLER-ALGIA-CABINET.bat"; WorkingDir: "{app}"
Name: "{group}\Demarrer ALGIA Cabinet"; Filename: "{app}\DEMARRER-ALGIA-CABINET.bat"; WorkingDir: "{app}"
Name: "{group}\Arreter ALGIA Cabinet"; Filename: "{app}\ARRETER-ALGIA-CABINET.bat"; WorkingDir: "{app}"
Name: "{group}\Sauvegarder ALGIA Cabinet"; Filename: "{app}\SAUVEGARDE-ALGIA-CABINET.bat"; WorkingDir: "{app}"
Name: "{group}\Mettre a jour ALGIA Cabinet"; Filename: "{app}\METTRE-A-JOUR-ALGIA-CABINET.bat"; WorkingDir: "{app}"
Name: "{group}\Restaurer ALGIA Cabinet"; Filename: "{app}\RESTAURER-ALGIA-CABINET.bat"; WorkingDir: "{app}"

Name: "{userdesktop}\ALGIA Cabinet"; Filename: "http://localhost:8080"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Creer un raccourci ALGIA Cabinet sur le Bureau"; GroupDescription: "Raccourcis :"; Flags: unchecked

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\installer\windows\scripts\install.ps1"" -SourceDir ""{src}"""; Description: "Installer et demarrer ALGIA Cabinet"; Flags: postinstall waituntilterminated
