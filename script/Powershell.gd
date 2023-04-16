tool
class_name PowershellCommands


# @TODO: Deferring proper error checking due to maddening double quote issues
const SteamLibraryFoldersFileCommand := """
$ErrorActionPreference = 'Stop'

$dquot = '""'
$gameId = '1388770'
$gameIdPat = ('{0}(' + $gameId + '){0}') -f $dquot
$libPathPat = '{0}path\\s*{0}([^{0}]+)' -f $dquot
$installDirPat = '{0}installdir{0}\\s*{0}([^{0}]+){0}' -f $dquot

$SteamDirPath = (Get-Item HKLM:/SOFTWARE/WOW6432Node/Valve/Steam).GetValue('InstallPath')
$SteamAppsDir = Get-Item $SteamDirPath/steamapps

$LibraryPath = ''
$GameDirName = ''
foreach($line in (Get-Content $SteamAppsDir/libraryfolders.vdf))
{
	if($line -match $libPathPat)
	{
		$LibraryPath = $line -replace ('^.+\\s{0}|{0}$' -f $dquot), ''
	}
	elseif($line -Match $gameIdPat)
	{
		$GameDirName = $Matches[1]
		break
	}
}
$LibrarySteamAppsPath = Join-Path $LibraryPath 'steamapps'
$AcfPath = Join-Path $LibrarySteamAppsPath ('appmanifest_{0}.acf' -f $gameId)
$GameDirName = (Get-Content $AcfPath | Select-String $installDirPat).Matches.Groups[1].Value
$GameDir = Get-Item ""$LibrarySteamAppsPath/common/$GameDirName""
$GameDir.FullName
"""


const GodotPckExplorerPatchBlock := """
filter Watch-PCKExplorerOutput()
{
	param([string] $Prefix = 'LOG: ', [string] $delim =' ')
	Process
	{
		$msg = 'PCKExplorer: {0}' -f $_
		if($msg -match 'Error:') { throw 'Caught PCKExplorer error, throwing' }
		if($Simulate) { $msg >> $LogPath }
	}
}
$GodotPckExplorer = Get-Command $Paths.PckExplorerPath

if($Simulate)
{
	WriteLog 'Would run pck explorer commands:'
	Write-Output $GodotPckExplorer '-e'  $Paths.ApocContentPckPath $PatchTempDir                         | WriteLog
	Write-Output $GodotPckExplorer '-es' $Paths.SteamPckPath       $PatchTempDir            '.import/*'  | WriteLog
	Write-Output $GodotPckExplorer '-p'  $PatchTempDir             $Paths.PatchedPckTmpPath $PckVersion  | WriteLog
}
else
{
	'Extracting apocrypha content from <{0}> to <{1}>' -f $Paths.ApocContentPckPath, $PatchTempDir | WriteLog
	& $GodotPckExplorer -e  $Paths.ApocContentPckPath $PatchTempDir | Watch-PCKExplorerOutput

	'Extracting base game .import content from <{0}> to <{1}>' -f $Paths.SteamPckPath, $PatchTempDir | WriteLog
	& $GodotPckExplorer -es $Paths.SteamPckPath $PatchTempDir '.import/*' | Watch-PCKExplorerOutput

	'Building patched pck to <{0}>' -f $Paths.PatchedPckTmpPath | WriteLog
	& $GodotPckExplorer -p  $PatchTempDir $Paths.PatchedPckTmpPath $PckVersion | Watch-PCKExplorerOutput

	'Moving patched pck to <{0}>' -f $Paths.PatchedPckTmpPath | WriteLog
	Move-Item -Force $Paths.PatchedPckTmpPath $Paths.PatchedPckDestPath
}
"""

const SUCCESS_SIGIL := '<<<< BUILD COMPLETE >>>>'

# fmt key list:
# patcher_dir
# steam_pck_path
# patched_pck_dir
# apoc_pck_base_name
# output_pck_name
# debug
const PackApocPckCommandFmtString := """
# Redeclared in scriptblock scope, needed here for debug script
$LogDir  = '{patcher_dir}' # Join-Path $HOME Desktop
$LogPath = Join-Path $LogDir apoc-installer.log

$cmd = {

'------ PATCHER START {0} ------' -f (Get-Date).tostring('yy-MM-dd hh.mm.ss')

$Simulate = ${SIMULATE_MODE}
'Simulation Mode: {0}' -f $Simulate

$debug_keep_workdir = ${DEBUG_PRESERVE_WORKDIR}
'Preserving Work Dir: {0}' -f $debug_keep_workdir

$LogDir  = '{patcher_dir}'
$LogPath = Join-Path $LogDir apoc-installer.log
function WriteLog()
{
	param([string] $Prefix = 'LOG: ', [string] $delim =' ')
	Begin { $parts = @() }
	Process { $parts += $_ }
	End
	{
		$msg = '{0}{1}' -f $Prefix, ($parts -join $delim)
		$msg;
		if($Simulate) { $msg >> $LogPath }
	}
}
function WriteDbg()
{
	param([string] $delim =' ')
	Process { $parts | WriteLog -Delim:$Delim -Prefix 'DEBUG: ' }
}

$Local:ErrorActionPreference = 'Stop'

$PckVersion = '1.3.5.0'

# Files to copy if output folder is not patcher folder. For now don't overwrite
$OtherFiles = @(
	'buildinfo.json'
	'csquad-apoc.exe'
	'godotsteam.dll'
	'libgodot_archive_rust.dll'
	'libmap.dll'
	'libqodot.dll'
	'steam_api64.dll'
	'steam_appid.txt'
)

# Setup/check config
$Paths = @{
	PatcherDirPath     = '{patcher_dir}'
	SteamPckPath       = '{steam_pck_path}'
	PatchedPckDirPath  = '{patched_pck_dir}'
	ApocContentDirPath = '{apoc_content_dir}'
}
#$Paths.PckExplorerPath   = Join-Path $Paths.PatcherDirPath     GodotPckExplorer.exe
$Paths.ApocContentPckPath = Join-Path $Paths.ApocContentDirPath '{apoc_pck_base_name}'
$Paths.GodotPckToolPath   = Join-Path $Paths.ApocContentDirPath godotpcktool.exe

foreach($req in $Paths.GetEnumerator())
{
	WriteLog ('Validating config path {0}: {1}' -f $req.Key, $req.Value)

	if($req.Value -eq '')
	{ Throw ('Empty config value: {0}' -f $req.Key) }

	if(Test-Path $req.Value) { continue }

	Throw ('Missing required path config {0} {1}' -f $req.Key, $req.Value)
}

$Paths.PatchedPckTmpPath  = Join-Path $Paths.PatcherDirPath '{output_pck_name}'
$Paths.PatchedPckDestPath = Join-Path $Paths.PatchedPckDirPath '{output_pck_name}'

$GodotPckTool = Get-Command $Paths.GodotPckToolPath

'PatcherDirPath: {0}' -f $Paths.PatcherDirPath | WriteLog
$PatchTempDir = Join-Path $Paths.PatcherDirPath apoc-tmp
if(Test-Path $PatchTempDir) { Remove-Item -Recurse $PatchTempDir }
if(-not (mkdir $PatchTempDir)) { throw "Failed to create patcher temp directory" }

if(-not $Simulate)
{
	if(test-path $Paths.PatchedPckDestPath) { remove-item $Paths.PatchedPckDestPath };
	Copy-Item $Paths.ApocContentPckPath $Paths.PatchedPckDestPath

	# Original .import only targeting
	# & $GodotPckTool --pack $Paths.SteamPckPath       --action extract  --include-regex-filter '^res://\\.import\\/.*' --output $PatchTempDir |

	# Add in base files
	& $GodotPckTool --action extract --pack $Paths.SteamPckPath --output $PatchTempDir |
		ForEach-Object { if($_ -notmatch '^(Extracting|Adding) .*') { $_ } }

	# Add in apoc files
	& $GodotPckTool --action extract --pack $Paths.ApocContentPckPath --output $PatchTempDir |
		ForEach-Object { if($_ -notmatch '^(Extracting|Adding) .*') { $_ } }

	# Build new pck
	& $GodotPckTool --action add     --pack $Paths.PatchedPckDestPath $PatchTempDir --remove-prefix $PatchTempDir |
		ForEach-Object { if($_ -notmatch '^(Extracting|Adding) .*') { $_ } }

	$OtherFiles | ForEach-Object {
		$SourcePath = Join-Path $Paths.ApocContentDirPath $_
		$OutPath    = Join-Path $Paths.PatchedPckDirPath  $_

		('Copying <{0}> to <{1}>' -f $SourcePath, $OutPath) | WriteLog
		Copy-Item -Force $SourcePath $OutPath
	}

	if(Test-Path $PatchTempDir)
	{
		if($debug_keep_workdir)
		{
			('Perserving temp path <{0}>' -f $PatchTempDir) | WriteLog
		}
		else
		{
			('Clearing temp path <{0}>' -f $PatchTempDir) | WriteLog
			Remove-Item -Recurse $PatchTempDir
		}
	}

	'{SUCCESS_SIGIL}' | WriteLog
}

# @TODO: Add param to launch game
# Push-Location $Paths.PatcherDirPath; ./csquad-apoc.exe; Pop-Location
}

$scriptblockFileName = 'last-patcher-scriptblock.ps1'

if(${SIMULATE_MODE})
{
	Write-Output 'Compiled scriptblock'
	$cmd.toString() > $LogDir/$scriptblockFileName
}
else
{
	$cmd.toString() > $LogDir/$scriptblockFileName
	& $cmd | Tee-Object $LogPath -Append
}
"""


#section statics


static func BuildPackApocPckCommandFmtString(patcher_dir: String,
											 steam_pck_path: String,
											 apoc_content_dir: String,
											 patched_pck_dir: String,
											 debug_workdir := false,
											 simulate := false) -> String:
	var params := {
		patcher_dir      = patcher_dir,
		apoc_content_dir = apoc_content_dir,
		steam_pck_path   = steam_pck_path,
		patched_pck_dir  = patched_pck_dir,
		simulate         = simulate,
	}

	print('Running build command with params:\n%s' % [ JSON.print(params, '  ') ])

	return PackApocPckCommandFmtString.format({
		patcher_dir        = patcher_dir,
		apoc_content_dir   = apoc_content_dir,
		steam_pck_path     = steam_pck_path,
		patched_pck_dir    = patched_pck_dir,
		SIMULATE_MODE      = simulate,
		output_pck_name    = Constants.ApocPckName,
		apoc_pck_base_name = Constants.ApocPckBaseName,
		SUCCESS_SIGIL      = SUCCESS_SIGIL,
		DEBUG_PRESERVE_WORKDIR = debug_workdir
	})
