$ErrorActionPreference = 'Stop'
$sourceRoot = 'C:\Users\naasa\seguridad_vial_app\tmp\c5i-backend'
$targetRoot = 'C:\wamp64\www\sistemaEstadistico'
$backupRoot = 'C:\Users\naasa\seguridad_vial_app\tmp\c5i-backend-originals'
$files = @(
    'app\Services\C5iResponseTimeService.php',
    'app\Services\C5iRouteService.php',
    'app\Http\Controllers\Api\LocationController.php',
    'app\Http\Controllers\Api\C5iRouteController.php',
    'app\Http\Controllers\C5iResponseReportController.php',
    'routes\api.php', 'routes\web.php',
    'resources\views\c5i\response-report.blade.php',
    'database\migrations\2026_09_15_180000_create_c5i_route_points_table.php',
    'tests\Unit\C5iRouteRegressionTest.php'
)
foreach ($file in $files) {
    $target = [IO.Path]::GetFullPath((Join-Path $targetRoot $file))
    if (-not $target.StartsWith($targetRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Destino fuera del backend' }
    if (Test-Path -LiteralPath $target) {
        $backup = Join-Path $backupRoot $file
        New-Item -ItemType Directory -Force -Path (Split-Path $backup) | Out-Null
        Copy-Item -LiteralPath $target -Destination $backup
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceRoot $file) -Destination $target
    Write-Output $file
}
