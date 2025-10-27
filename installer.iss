; installer.iss — Kkomi Learn (Flutter Windows)
#define AppName "Kkomi Learn"
#define AppVersion "1.0.0"
#define Publisher "Luke"
#define ExeName "kkomi_learn.exe"
#define BuildDir "build\\windows\\x64\\runner\\Release"

[Setup]
AppId={{9B1E9F5C-6B1C-4F9A-9A73-55E2E6D6F2B9}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#Publisher}
DefaultDirName={pf}\{#AppName}
DefaultGroupName={#AppName}
OutputBaseFilename={#AppName}_Setup_{#AppVersion}
OutputDir=dist
Compression=lzma2/max
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern
SetupIconFile=assets\installer.ico
UninstallDisplayIcon={app}\{#ExeName}
DisableDirPage=no
DisableProgramGroupPage=no
PrivilegesRequired=admin

[Languages]
Name: "korean";  MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; 앱 본체 (Release)
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

; VC++ 런타임 인스톨러
Source: "redist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
; VC++ 런타임 자동 설치
Filename: "{tmp}\vc_redist.x64.exe"; \
    Parameters: "/install /quiet /norestart"; \
    StatusMsg: "필수 구성요소(Visual C++ 런타임)를 설치하는 중입니다..."; \
    Flags: waituntilterminated

; 앱 실행
Filename: "{app}\{#ExeName}"; \
    Description: "{cm:LaunchProgram,{#AppName}}"; \
    Flags: nowait postinstall skipifsilent

[Icons]
Name: "{group}\{#AppName}";       Filename: "{app}\{#ExeName}"
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#ExeName}"; Tasks: desktopicon
