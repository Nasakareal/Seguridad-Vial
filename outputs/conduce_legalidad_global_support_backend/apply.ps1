$ErrorActionPreference = 'Stop'

$packageRoot = $PSScriptRoot
$backendRoot = 'C:\wamp64\www\sistemaEstadistico'
$controllerSource = Join-Path $packageRoot 'app\Http\Controllers\Api\ConduceLegalidadController.php'
$testSource = Join-Path $packageRoot 'tests\Unit\ConduceLegalidadOperativoAccessTest.php'
$controllerTarget = Join-Path $backendRoot 'app\Http\Controllers\Api\ConduceLegalidadController.php'
$testTarget = Join-Path $backendRoot 'tests\Unit\ConduceLegalidadOperativoAccessTest.php'
$backupRoot = Join-Path $packageRoot 'backup'

New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
Copy-Item -LiteralPath $controllerTarget -Destination (Join-Path $backupRoot 'ConduceLegalidadController.php') -Force
Copy-Item -LiteralPath $testTarget -Destination (Join-Path $backupRoot 'ConduceLegalidadOperativoAccessTest.php') -Force
Copy-Item -LiteralPath $controllerSource -Destination $controllerTarget -Force
Copy-Item -LiteralPath $testSource -Destination $testTarget -Force

Write-Host 'Acceso global a operativos activos y vista total del delegado aplicados.'
