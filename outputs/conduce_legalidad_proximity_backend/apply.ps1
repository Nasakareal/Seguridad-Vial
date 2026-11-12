param(
    [string]$BackendRoot = 'C:\wamp64\www\sistemaEstadistico'
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = @(
    'app\Http\Controllers\Api\ConduceLegalidadController.php',
    'tests\Unit\ConduceLegalidadOperativoProximityTest.php'
)

foreach ($relativePath in $files) {
    $source = Join-Path $packageRoot $relativePath
    $target = Join-Path $BackendRoot $relativePath
    $targetDirectory = Split-Path -Parent $target
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
}

Write-Host 'Protección geográfica de operativos aplicada.'
