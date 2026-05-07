#define MyAppName "HomeCraft"
#define MyAppVersion "0.1.0"
#ifndef OutputRoot
#define OutputRoot "..\..\dist"
#endif
#ifndef PackageRoot
#define PackageRoot "..\dist\package"
#endif

[Setup]
AppId={{7F6E62A8-52E5-47C0-96E7-6EAE9200F3A1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=HomeCraft
DefaultDirName={localappdata}\Programs\HomeCraft
DefaultGroupName=HomeCraft
DisableProgramGroupPage=yes
OutputDir={#OutputRoot}
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

[Dirs]
Name: "{app}\logs"

[Files]
Source: "{#PackageRoot}\HomeCraft.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageRoot}\app\*"; DestDir: "{app}\app"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PackageRoot}\tools\*"; DestDir: "{app}\tools"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PackageRoot}\installer\*"; DestDir: "{app}\installer"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\HomeCraft"; Filename: "{app}\HomeCraft.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\HomeCraft"; Filename: "{app}\HomeCraft.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\HomeCraft.exe"; Description: "Launch HomeCraft"; Flags: nowait postinstall skipifsilent unchecked; Check: ShouldLaunchHomeCraft

[Code]
var
	MinecraftPathPage: TInputDirWizardPage;
	BootstrapSucceeded: Boolean;

procedure InitializeWizard;
begin
	BootstrapSucceeded := False;

	MinecraftPathPage :=
		CreateInputDirPage(
			wpSelectDir,
			'Minecraft Server Folder',
			'Choose your existing Minecraft server folder.',
			'Select the folder that already contains server.jar. HomeCraft uses this folder to start and manage your server.',
			False,
			''
		);
	MinecraftPathPage.Add('');
	MinecraftPathPage.Values[0] := ExpandConstant('{userdocs}\HomeCraft Minecraft');
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

		if not DirExists(MinecraftPathPage.Values[0]) then begin
			MsgBox('The selected Minecraft server folder does not exist.', mbError, MB_OK);
			Result := False;
			exit;
		end;

		if not FileExists(AddBackslash(MinecraftPathPage.Values[0]) + 'server.jar') then begin
			MsgBox('The selected Minecraft server folder must contain server.jar.', mbError, MB_OK);
			Result := False;
			exit;
		end;
	end;
end;

function Quote(Value: String): String;
begin
	Result := '"' + Value + '"';
end;

function GetBootstrapParameters: String;
begin
	Result :=
		'-NoProfile -ExecutionPolicy Bypass -File ' +
		Quote(ExpandConstant('{app}\installer\bootstrap-homecraft.ps1')) +
		' -InstallDir ' + Quote(ExpandConstant('{app}')) +
		' -MinecraftDir ' + Quote(MinecraftPathPage.Values[0]);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
	ResultCode: Integer;
	AppBuildDir: String;
	LogFile: String;
begin
	if CurStep = ssPostInstall then begin
		WizardForm.StatusLabel.Caption := 'Configuring HomeCraft...';

		if not Exec(
			'powershell.exe',
			GetBootstrapParameters,
			ExpandConstant('{app}'),
			SW_SHOW,
			ewWaitUntilTerminated,
			ResultCode
		) then begin
			MsgBox('Could not start PowerShell to configure HomeCraft.', mbError, MB_OK);
			Abort;
		end;

		if ResultCode <> 0 then begin
			LogFile := ExpandConstant('{app}\logs\install.log');
			MsgBox(
				'HomeCraft configuration failed with exit code ' + IntToStr(ResultCode) + '.' + #13#10 +
				'Check the install log at:' + #13#10 + LogFile,
				mbError,
				MB_OK
			);
			Abort;
		end;

		AppBuildDir := ExpandConstant('{app}\app\build');
		if not DirExists(AppBuildDir) then begin
			LogFile := ExpandConstant('{app}\logs\install.log');
			MsgBox(
				'HomeCraft was not installed correctly. Missing folder:' + #13#10 +
				AppBuildDir + #13#10 + #13#10 +
				'Check the install log at:' + #13#10 + LogFile,
				mbError,
				MB_OK
			);
			Abort;
		end;

		BootstrapSucceeded := True;
	end;
end;

function ShouldLaunchHomeCraft: Boolean;
begin
	Result := BootstrapSucceeded and DirExists(ExpandConstant('{app}\app\build'));
end;
