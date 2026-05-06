#define MyAppName "HomeCraft"
#define MyAppVersion "0.1.0"
#define RepoRoot "..\.."
#define InstallerRoot ".."

[Setup]
AppId={{7F6E62A8-52E5-47C0-96E7-6EAE9200F3A1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=HomeCraft
DefaultDirName={localappdata}\Programs\HomeCraft
DefaultGroupName=HomeCraft
DisableProgramGroupPage=yes
OutputDir={#RepoRoot}\dist
OutputBaseFilename=HomeCraftSetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\HomeCraft.exe
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#InstallerRoot}\dist\launcher\HomeCraft.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#InstallerRoot}\scripts\bootstrap-homecraft.ps1"; DestDir: "{app}\installer"; Flags: ignoreversion

[Icons]
Name: "{group}\HomeCraft"; Filename: "{app}\HomeCraft.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\HomeCraft"; Filename: "{app}\HomeCraft.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "powershell.exe"; \
	Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\installer\bootstrap-homecraft.ps1"" -InstallDir ""{app}"" -MinecraftMode ""{code:GetMinecraftMode}"" -MinecraftDir ""{code:GetMinecraftDir}"" -AcceptMinecraftEula {code:GetMinecraftEulaAccepted}"; \
	Description: "Install HomeCraft dependencies and build the app"; \
	Flags: waituntilterminated
Filename: "{app}\HomeCraft.exe"; Description: "Launch HomeCraft"; Flags: nowait postinstall skipifsilent unchecked

[Code]
var
	ServerModePage: TInputOptionWizardPage;
	MinecraftPathPage: TInputDirWizardPage;
	EulaPage: TInputOptionWizardPage;

procedure InitializeWizard;
begin
	ServerModePage :=
		CreateInputOptionPage(
			wpSelectDir,
			'Minecraft Server',
			'Choose how HomeCraft should connect to Minecraft.',
			'Select whether the installer should create a fresh vanilla server or use an existing server folder.',
			True,
			False
		);
	ServerModePage.Add('Create a fresh vanilla Minecraft server');
	ServerModePage.Add('Use an existing Minecraft server folder');
	ServerModePage.Values[0] := True;

	MinecraftPathPage :=
		CreateInputDirPage(
			ServerModePage.ID,
			'Minecraft Server Folder',
			'Choose the Minecraft server folder.',
			'For a fresh server, this folder will be created if needed. For an existing server, it must already contain server.jar.',
			False,
			''
		);
	MinecraftPathPage.Add('');
	MinecraftPathPage.Values[0] := ExpandConstant('{userdocs}\HomeCraft Minecraft');

	EulaPage :=
		CreateInputOptionPage(
			MinecraftPathPage.ID,
			'Minecraft EULA',
			'Accept the Minecraft EULA for fresh server setup.',
			'HomeCraft can only create a fresh server when you confirm that you accept the Minecraft EULA.',
			False,
			False
		);
	EulaPage.Add('I accept the Minecraft EULA');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
	Result := True;

	if CurPageID = MinecraftPathPage.ID then begin
		if Trim(MinecraftPathPage.Values[0]) = '' then begin
			MsgBox('Choose a Minecraft server folder.', mbError, MB_OK);
			Result := False;
			exit;
		end;

		if ServerModePage.Values[1] and not FileExists(AddBackslash(MinecraftPathPage.Values[0]) + 'server.jar') then begin
			MsgBox('Existing server folders must contain server.jar.', mbError, MB_OK);
			Result := False;
			exit;
		end;
	end;

	if CurPageID = EulaPage.ID then begin
		if ServerModePage.Values[0] and not EulaPage.Values[0] then begin
			MsgBox('You must accept the Minecraft EULA to create a fresh server.', mbError, MB_OK);
			Result := False;
			exit;
		end;
	end;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
	Result := False;

	if PageID = EulaPage.ID then begin
		Result := ServerModePage.Values[1];
	end;
end;

function GetMinecraftMode(Param: String): String;
begin
	if ServerModePage.Values[0] then
		Result := 'Fresh'
	else
		Result := 'Existing';
end;

function GetMinecraftDir(Param: String): String;
begin
	Result := MinecraftPathPage.Values[0];
end;

function GetMinecraftEulaAccepted(Param: String): String;
begin
	if ServerModePage.Values[0] and EulaPage.Values[0] then
		Result := '$true'
	else
		Result := '$false';
end;
