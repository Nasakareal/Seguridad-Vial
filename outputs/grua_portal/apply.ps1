$ErrorActionPreference = 'Stop'

$packageRoot = $PSScriptRoot
$backendRoot = 'C:\wamp64\www\sistemaEstadistico'
$backupRoot = Join-Path $packageRoot 'backup-secure-evidence'
$migrationNames = @(
    '2026_10_14_180000_add_sierse_closure_to_liberaciones_corralon_table.php',
    '2026_10_14_220000_add_operational_details_to_servicios_table.php',
    '2026_10_14_230000_add_sierse_record_to_servicios_table.php',
    '2026_10_14_240000_add_quick_inventory_to_servicios_table.php'
)

$files = @(
    @{ Source = 'app\Http\Controllers\LiberacionCorralonController.php'; Target = 'app\Http\Controllers\LiberacionCorralonController.php' },
    @{ Source = 'app\Http\Controllers\GruaUsuarioController.php'; Target = 'app\Http\Controllers\GruaUsuarioController.php' },
    @{ Source = 'app\Http\Controllers\Api\AuthController.php'; Target = 'app\Http\Controllers\Api\AuthController.php' },
    @{ Source = 'app\Http\Controllers\Api\GruaCorralonController.php'; Target = 'app\Http\Controllers\Api\GruaCorralonController.php' },
    @{ Source = 'app\Http\Middleware\RestrictGruaApiAccess.php'; Target = 'app\Http\Middleware\RestrictGruaApiAccess.php' },
    @{ Source = 'app\Http\Kernel.php'; Target = 'app\Http\Kernel.php' },
    @{ Source = 'app\Models\LiberacionCorralon.php'; Target = 'app\Models\LiberacionCorralon.php' },
    @{ Source = 'app\Models\GruaUsuario.php'; Target = 'app\Models\GruaUsuario.php' },
    @{ Source = 'app\Models\Servicio.php'; Target = 'app\Models\Servicio.php' },
    @{ Source = 'app\Providers\AuthServiceProvider.php'; Target = 'app\Providers\AuthServiceProvider.php' },
    @{ Source = 'routes\web.php'; Target = 'routes\web.php' },
    @{ Source = 'routes\api.php'; Target = 'routes\api.php' },
    @{ Source = 'resources\views\liberaciones_corralon\index.blade.php'; Target = 'resources\views\liberaciones_corralon\index.blade.php' },
    @{ Source = 'resources\views\liberaciones_corralon\show.blade.php'; Target = 'resources\views\liberaciones_corralon\show.blade.php' },
    @{ Source = 'resources\views\pdf\grua_corralon_reporte.blade.php'; Target = 'resources\views\pdf\grua_corralon_reporte.blade.php' },
    @{ Source = 'resources\views\pdf\grua_memoria_descriptiva.blade.php'; Target = 'resources\views\pdf\grua_memoria_descriptiva.blade.php' },
    @{ Source = 'resources\views\admin\settings\grua_usuarios\create.blade.php'; Target = 'resources\views\admin\settings\grua_usuarios\create.blade.php' },
    @{ Source = 'resources\views\admin\settings\grua_usuarios\edit.blade.php'; Target = 'resources\views\admin\settings\grua_usuarios\edit.blade.php' }
)

New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

foreach ($file in $files) {
    $target = Join-Path $backendRoot $file.Target
    $backup = Join-Path $backupRoot $file.Target
    New-Item -ItemType Directory -Force -Path (Split-Path $backup -Parent) | Out-Null
    if (Test-Path -LiteralPath $target) {
        Copy-Item -LiteralPath $target -Destination $backup -Force
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
    Copy-Item -LiteralPath (Join-Path $packageRoot $file.Source) -Destination $target -Force
}

$testTarget = Join-Path $backendRoot 'tests\Unit\GruaPortalScopeTest.php'
$apiLoginTestTarget = Join-Path $backendRoot 'tests\Feature\GruaApiLoginTest.php'
$corralonApiTestTarget = Join-Path $backendRoot 'tests\Feature\GruaCorralonApiTest.php'
foreach ($migrationName in $migrationNames) {
    $migrationTarget = Join-Path $backendRoot "database\migrations\$migrationName"
    Copy-Item -LiteralPath (Join-Path $packageRoot "database\migrations\$migrationName") -Destination $migrationTarget -Force
    php -l $migrationTarget
}
Copy-Item -LiteralPath (Join-Path $packageRoot 'tests\Unit\GruaPortalScopeTest.php') -Destination $testTarget -Force
Copy-Item -LiteralPath (Join-Path $packageRoot 'tests\Feature\GruaApiLoginTest.php') -Destination $apiLoginTestTarget -Force
Copy-Item -LiteralPath (Join-Path $packageRoot 'tests\Feature\GruaCorralonApiTest.php') -Destination $corralonApiTestTarget -Force

php -l (Join-Path $backendRoot 'app\Http\Controllers\LiberacionCorralonController.php')
php -l (Join-Path $backendRoot 'app\Http\Controllers\GruaUsuarioController.php')
php -l (Join-Path $backendRoot 'app\Http\Controllers\Api\AuthController.php')
php -l (Join-Path $backendRoot 'app\Http\Controllers\Api\GruaCorralonController.php')
php -l (Join-Path $backendRoot 'app\Http\Middleware\RestrictGruaApiAccess.php')
php -l (Join-Path $backendRoot 'app\Http\Kernel.php')
php -l (Join-Path $backendRoot 'app\Models\LiberacionCorralon.php')
php -l (Join-Path $backendRoot 'app\Models\GruaUsuario.php')
php -l (Join-Path $backendRoot 'app\Models\Servicio.php')
php -l (Join-Path $backendRoot 'app\Providers\AuthServiceProvider.php')
php -l $testTarget
php -l $apiLoginTestTarget
php -l $corralonApiTestTarget

Push-Location $backendRoot
try {
    php artisan migrate --force
    if ($LASTEXITCODE -ne 0) {
        throw 'La migracion del portal de gruas fallo.'
    }
    php artisan view:clear
} catch {
    foreach ($file in $files) {
        $backup = Join-Path $backupRoot $file.Target
        if (Test-Path -LiteralPath $backup) {
            Copy-Item -LiteralPath $backup -Destination (Join-Path $backendRoot $file.Target) -Force
        }
    }
    throw
} finally {
    Pop-Location
}

Write-Host 'Portal de gruas actualizado.'
Write-Host "Respaldo: $backupRoot"
