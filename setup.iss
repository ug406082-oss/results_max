[Setup]
AppName=ResultMax
AppVersion=1.0.0
DefaultDirName={autopf}\ResultMax
DefaultGroupName=ResultMax
OutputDir=output
OutputBaseFilename=ResultMax_Setup
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ResultMax"; Filename: "{app}\results_max.exe"
Name: "{autodesktop}\ResultMax"; Filename: "{app}\results_max.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Run]
Filename: "{app}\results_max.exe"; Description: "Launch ResultMax"; Flags: nowait postinstall skipifsilent
