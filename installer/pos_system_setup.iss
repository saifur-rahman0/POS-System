; Inno Setup Packaging Script for Retail POS System (Windows x64)
; Bundles Flutter Client Executable, FastAPI Backend Service, and Embedded Python Environment.

#define MyAppName "Retail POS System"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Antigravity Retail Solutions"
#define MyAppExeName "pos_system_application.exe"

[Setup]
AppId={{9B7F1D2C-38A4-4A56-B102-86E47901C4A5}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\RetailPOS
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\dist
OutputBaseFilename=RetailPOS_Setup_v1.0.0_x64
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Automatically launch POS terminal on Windows startup"; GroupDescription: "System Integration:"

[Files]
; Flutter Desktop Client Binary and DLLs
Source: "..\pos_system_application\build\windows\x64\runner\Release\*"; DestDir: "{app}\client"; Flags: ignoreversion recursesubdirs createallsubdirs
; Backend Python Source & Configuration
Source: "..\backend\app\*"; DestDir: "{app}\backend\app"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\backend\alembic.ini"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "..\backend\alembic\*"; DestDir: "{app}\backend\alembic"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\backend\pyproject.toml"; DestDir: "{app}\backend"; Flags: ignoreversion
; Production Launcher Scripts
Source: "..\launcher\run_pos_desktop.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\run_pos_desktop.bat"; IconFilename: "{app}\client\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexename}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\run_pos_desktop.bat"; IconFilename: "{app}\client\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Windows Autostart Registry Hook
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "RetailPOSSystem"; ValueData: """{app}\run_pos_desktop.bat"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\run_pos_desktop.bat"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: shellexec postinstall nowait skipifsilent

