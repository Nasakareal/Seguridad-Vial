$ErrorActionPreference = 'Stop'

$workspaceRoot = 'C:\Users\naasa\seguridad_vial_app'
$backendRoot = 'C:\wamp64\www\sistemaEstadistico'
$backupRoot = Join-Path $workspaceRoot 'tmp\barandillas-iph-vehicle-backup'

$serviceSource = Join-Path $workspaceRoot 'outputs\conduce_legalidad_agente\app\Services\IphPuestaDisposicionDocxService.php'
$serviceTestSource = Join-Path $workspaceRoot 'outputs\conduce_legalidad_agente\tests\Unit\IphPuestaDisposicionDocxServiceTest.php'
$serviceTarget = Join-Path $backendRoot 'app\Services\IphPuestaDisposicionDocxService.php'
$serviceTestTarget = Join-Path $backendRoot 'tests\Unit\IphPuestaDisposicionDocxServiceTest.php'
$controllerTarget = Join-Path $backendRoot 'app\Http\Controllers\Api\ConduceLegalidadController.php'
$controllerTestTarget = Join-Path $backendRoot 'tests\Unit\ConduceLegalidadBarandillasWhatsappTest.php'

$targets = @($serviceTarget, $serviceTestTarget, $controllerTarget, $controllerTestTarget)
foreach ($target in $targets) {
    $resolved = [IO.Path]::GetFullPath($target)
    if (-not $resolved.StartsWith($backendRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Destino fuera del backend: $resolved"
    }
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "No existe el archivo de destino: $resolved"
    }

    $relative = $resolved.Substring($backendRoot.Length).TrimStart('\')
    $backup = Join-Path $backupRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $backup) | Out-Null
    Copy-Item -LiteralPath $resolved -Destination $backup -Force
}

Copy-Item -LiteralPath $serviceSource -Destination $serviceTarget -Force
Copy-Item -LiteralPath $serviceTestSource -Destination $serviceTestTarget -Force

$controller = [IO.File]::ReadAllText($controllerTarget)
$oldCall = '[$iphPath, $iphFilename] = $docxService->generarConduceLegalidadBarandillas($hecho, $mapeo);'
$newCall = '[$iphPath, $iphFilename] = $docxService->generarConduceLegalidadBarandillasSoloVehiculo($hecho, $mapeo);'
$callCount = ([regex]::Matches($controller, [regex]::Escape($oldCall))).Count
if ($callCount -ne 1) {
    throw "Se esperaba exactamente una llamada automática anterior; se encontraron $callCount."
}
$controller = $controller.Replace($oldCall, $newCall)
[IO.File]::WriteAllText($controllerTarget, $controller, [Text.UTF8Encoding]::new($false))

$controllerTest = [IO.File]::ReadAllText($controllerTestTarget)
$oldExpectation = "'generarConduceLegalidadBarandillas'"
$newExpectation = "'generarConduceLegalidadBarandillasSoloVehiculo'"
$expectationCount = ([regex]::Matches($controllerTest, [regex]::Escape($oldExpectation))).Count
if ($expectationCount -lt 2) {
    throw "No se encontraron las expectativas esperadas del test de Barandillas."
}
$controllerTest = $controllerTest.Replace($oldExpectation, $newExpectation)
[IO.File]::WriteAllText($controllerTestTarget, $controllerTest, [Text.UTF8Encoding]::new($false))

Write-Output 'IPH de Barandillas actualizado a solo vehículo.'
Write-Output "Respaldo: $backupRoot"
