param(
    [string]$ProjectRoot = "",
    [string]$Config = "",
    [string]$Mdl = "",
    [string]$ModelUuid = "",
    [string]$PrefabUuid = "",
    [string]$AssetRoot = "",
    [string[]]$Texture = @(),
    [string]$Out = "",
    [string]$SceneId = "",
    [int]$MaxWidth = 0,
    [int]$MaxHeight = 0,
    [int]$MaxDepth = 0,
    [ValidateSet("surface", "column-solid")]
    [string]$FillMode = "surface",
    [double]$SurfaceThickness = 0,
    [int]$MaxPaletteColors = 0,
    [int]$ColorLevels = 0,
    [int]$RasterColorSamples = 0,
    [int]$RasterCoverageSamples = 0,
    [double]$RasterMinCoverage = -1
)

$ErrorActionPreference = "Stop"

$launcherPath = Join-Path $PSScriptRoot "run_voxelize.py"
if (-not (Test-Path -LiteralPath $launcherPath)) {
    throw "缺少 launcher 脚本: $launcherPath"
}

function Show-Usage {
    Write-Host "用法:"
    Write-Host "  cd <tapmaker_project>"
    Write-Host "  <skill>\scripts\run_voxelize.cmd -Mdl <path> [-Texture <path1>[,<path2>]]"
    Write-Host "  <skill>\scripts\run_voxelize.cmd -ModelUuid <uuid>"
    Write-Host "  <skill>\scripts\run_voxelize.cmd -PrefabUuid <uuid>"
    Write-Host ""
    Write-Host "默认不传 -ProjectRoot；相对路径按当前项目根解析。只有从项目根以外调用时才传 -ProjectRoot。"
    Write-Host "默认输出: assets/voxels/<输入名>_voxel.json，可用 -Out 覆盖。"
    Write-Host "默认配置: <skill>\config.json，可用 -Config 覆盖。"
}

function Get-Python {
    $cmd = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $cmd = Get-Command python -ErrorAction SilentlyContinue
    }
    if (-not $cmd) {
        throw "PATH 中找不到 python3 或 python。"
    }
    return $cmd.Source
}

if ($PSBoundParameters.Count -eq 0) {
    Show-Usage
    return
}

if (-not $Mdl -and -not $ModelUuid -and -not $PrefabUuid) {
    Show-Usage
    throw "缺少输入源: 必须提供 -Mdl、-ModelUuid 或 -PrefabUuid。"
}

$argsList = @($launcherPath)

if ($ProjectRoot) { $argsList += @("--project-root", $ProjectRoot) }
if ($Config) { $argsList += @("--config", $Config) }
if ($Mdl) { $argsList += @("--mdl", $Mdl) }
if ($ModelUuid) { $argsList += @("--model-uuid", $ModelUuid) }
if ($PrefabUuid) { $argsList += @("--prefab-uuid", $PrefabUuid) }
if ($AssetRoot) { $argsList += @("--asset-root", $AssetRoot) }
if ($Out) { $argsList += @("--out", $Out) }
if ($SceneId) { $argsList += @("--scene-id", $SceneId) }
if ($MaxWidth -gt 0) { $argsList += @("--max-width", "$MaxWidth") }
if ($MaxHeight -gt 0) { $argsList += @("--max-height", "$MaxHeight") }
if ($MaxDepth -gt 0) { $argsList += @("--max-depth", "$MaxDepth") }
if ($PSBoundParameters.ContainsKey("FillMode")) { $argsList += @("--fill-mode", $FillMode) }
if ($SurfaceThickness -gt 0) { $argsList += @("--surface-thickness", "$SurfaceThickness") }
if ($MaxPaletteColors -gt 0) { $argsList += @("--max-palette-colors", "$MaxPaletteColors") }
if ($ColorLevels -gt 0) { $argsList += @("--color-levels", "$ColorLevels") }
if ($RasterColorSamples -gt 0) { $argsList += @("--raster-color-samples", "$RasterColorSamples") }
if ($RasterCoverageSamples -gt 0) { $argsList += @("--raster-coverage-samples", "$RasterCoverageSamples") }
if ($RasterMinCoverage -ge 0) { $argsList += @("--raster-min-coverage", "$RasterMinCoverage") }

foreach ($textureEntry in $Texture) {
    foreach ($texturePath in ($textureEntry -split ",")) {
        $trimmedTexturePath = $texturePath.Trim()
        if ($trimmedTexturePath) {
            $argsList += @("--texture", $trimmedTexturePath)
        }
    }
}

$python = Get-Python
Write-Host "[voxelize] $python $($argsList -join ' ')"
& $python @argsList
if ($LASTEXITCODE -ne 0) {
    throw "体素化脚本失败，退出码 $LASTEXITCODE。"
}

