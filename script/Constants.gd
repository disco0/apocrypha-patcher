tool
class_name Constants


const BinPath := 'res://bin'
const GodotPckExplorerPath := BinPath + '/GodotPCKExplorer.exe'
const GodotPckToolPath     := BinPath + '/godotpcktool.exe'

const ReleaseBaseName := 'crueltysquad'
const ReleaseExeName  := ReleaseBaseName + '.exe'
const ReleasePckName  := ReleaseBaseName + '.pck'

# @NOTE: Keep in sync with name used in build script
const ApocBaseName    := 'csquad-apoc'
const ApocBinName     := ApocBaseName + '.exe'
const ApocPckName     := ApocBaseName + '.pck'
const ApocPckBaseName := ApocBaseName + '-content.pck'

const DefaultTheme := 'res://res/theme/main_theme.tres'

const TestConfig := {
	patcher_dir      = 'C:/csquad/steam/public',
	apoc_content_dir = 'C:/csquad/steam/public',
	out_dir_config   = 'C:/csquad/steam/public',
}
