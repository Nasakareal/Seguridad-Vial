$ErrorActionPreference = 'Stop'

$packageRoot = $PSScriptRoot
$backendRoot = 'C:\wamp64\www\sistemaEstadistico'
$backupRoot = Join-Path $packageRoot 'backup'

$controllerTarget = Join-Path $backendRoot 'app\Http\Controllers\Api\ConduceLegalidadController.php'
$serviceTarget = Join-Path $backendRoot 'app\Services\ConduceLegalidadDuplicateGuard.php'
$testTarget = Join-Path $backendRoot 'tests\Unit\ConduceLegalidadDuplicateGuardTest.php'

New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
Copy-Item -LiteralPath $controllerTarget -Destination (Join-Path $backupRoot 'ConduceLegalidadController.php') -Force
if (Test-Path -LiteralPath $serviceTarget) {
    Copy-Item -LiteralPath $serviceTarget -Destination (Join-Path $backupRoot 'ConduceLegalidadDuplicateGuard.php') -Force
}

Copy-Item -LiteralPath (Join-Path $packageRoot 'app\Http\Controllers\Api\ConduceLegalidadController.php') -Destination $controllerTarget -Force
Copy-Item -LiteralPath (Join-Path $packageRoot 'app\Services\ConduceLegalidadDuplicateGuard.php') -Destination $serviceTarget -Force
Copy-Item -LiteralPath (Join-Path $packageRoot 'tests\Unit\ConduceLegalidadDuplicateGuardTest.php') -Destination $testTarget -Force

php -l $controllerTarget
php -l $serviceTarget
php -l $testTarget

Write-Host 'Orden cronológico y protección de duplicados instalados.'
Write-Host "Respaldo: $backupRoot"
