$ErrorActionPreference = 'Stop'

$backendRoot = 'C:\wamp64\www\sistemaEstadistico'
$packageRoot = Split-Path -Parent $PSScriptRoot
$controllerPath = Join-Path $backendRoot 'app\Http\Controllers\Api\ConduceLegalidadController.php'
$modelPath = Join-Path $backendRoot 'app\Models\ConduceLegalidadCaptura.php'
$routesPath = Join-Path $backendRoot 'routes\api.php'
$migrationName = '2026_10_14_120000_reserve_conduce_legalidad_capture_folios.php'
$migrationSource = Join-Path $packageRoot "captura_scope_backend\database\migrations\$migrationName"
$migrationTarget = Join-Path $backendRoot "database\migrations\$migrationName"
$backupRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tmp\sierse-gruas-backup'

New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
Copy-Item -LiteralPath $controllerPath -Destination (Join-Path $backupRoot 'ConduceLegalidadController.php') -Force
Copy-Item -LiteralPath $modelPath -Destination (Join-Path $backupRoot 'ConduceLegalidadCaptura.php') -Force
Copy-Item -LiteralPath $routesPath -Destination (Join-Path $backupRoot 'api.php') -Force

function Add-BeforeRequired {
    param(
        [string] $Text,
        [string] $Anchor,
        [string] $Addition,
        [string] $AlreadyPresent
    )
    if ($Text.Contains($AlreadyPresent)) { return $Text }
    if (-not $Text.Contains($Anchor)) { throw "No se encontró el ancla: $Anchor" }
    return $Text.Replace($Anchor, "$Addition`r`n`r`n$Anchor")
}

function Replace-Required {
    param(
        [string] $Text,
        [string] $Old,
        [string] $New
    )
    if ($Text.Contains($New)) { return $Text }
    if (-not $Text.Contains($Old)) { throw "No se encontró el bloque requerido: $Old" }
    return $Text.Replace($Old, $New)
}

function Write-Utf8NoBom {
    param([string] $Path, [string] $Text)
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

$controller = (Get-Content -LiteralPath $controllerPath -Raw).Replace("`r`n", "`n")

$oldFolioQuery = @'
                    $porFolio->where('conduce_legalidad_capturas.operativo_id', $folio['operativo_id'])
                        ->where('conduce_legalidad_capturas.id', $folio['captura_id'])
'@
$newFolioQuery = @'
                    $porFolio->where('conduce_legalidad_capturas.operativo_id', $folio['operativo_id'])
                        ->where(function ($capturaFolio) use ($folio) {
                            $capturaFolio->where('conduce_legalidad_capturas.folio_numero', $folio['captura_id'])
                                ->orWhere(function ($legacy) use ($folio) {
                                    $legacy->whereNull('conduce_legalidad_capturas.folio_numero')
                                        ->where('conduce_legalidad_capturas.id', $folio['captura_id']);
                                });
                        })
'@
$controller = Replace-Required $controller $oldFolioQuery $newFolioQuery

$reserveMethod = @'
    public function reservarFolioCaptura(Request $request, ConduceLegalidadOperativo $operativo)
    {
        $user = $request->user();
        abort_unless($user, 403);
        $this->assertPuedeVerOperativo($operativo, $user);
        $this->assertPuedeAlimentarOperativo($operativo, $user);

        $validated = $request->validate([
            'client_uuid' => ['required', 'uuid'],
        ]);
        $numero = $this->reservarNumeroFolio(
            $operativo,
            $validated['client_uuid'],
            (int) $user->id
        );

        return response()->json([
            'ok' => true,
            'data' => [
                'client_uuid' => $validated['client_uuid'],
                'folio_numero' => $numero,
                'folio' => $this->prefijoFolioOperativo($operativo) . '-' . $operativo->id . '-' . $numero,
            ],
        ]);
    }
'@
$controller = Add-BeforeRequired $controller '    public function updateOperativo(Request $request, ConduceLegalidadOperativo $operativo)' $reserveMethod 'public function reservarFolioCaptura'

$oldCreate = @'
            $now = now();
            $captura = $operativo->capturas()->create([
                'client_uuid' => $clientUuid,
'@
$newCreate = @'
            $now = now();
            $folioNumero = $this->reservarNumeroFolio(
                $operativo,
                $clientUuid ?: (string) Str::uuid(),
                (int) $user->id
            );
            $captura = $operativo->capturas()->create([
                'client_uuid' => $clientUuid,
                'folio_numero' => $folioNumero,
'@
$controller = Replace-Required $controller $oldCreate $newCreate
$controller = Replace-Required $controller "            'folio' => 'CL-' . `$operativo->id . '-' . `$captura->id," "            'folio' => `$this->folioCaptura(`$operativo, `$captura),"

$oldFolioMethod = @'
    private function folioCaptura(ConduceLegalidadOperativo $operativo, ConduceLegalidadCaptura $captura): string
    {
        return $this->prefijoFolioOperativo($operativo) . '-' . $operativo->id . '-' . $captura->id;
    }
'@
$newFolioMethod = @'
    private function folioCaptura(ConduceLegalidadOperativo $operativo, ConduceLegalidadCaptura $captura): string
    {
        return $this->prefijoFolioOperativo($operativo) . '-' . $operativo->id . '-' . ($captura->folio_numero ?: $captura->id);
    }

    private function reservarNumeroFolio(
        ConduceLegalidadOperativo $operativo,
        string $clientUuid,
        int $userId
    ): int {
        $now = now();
        DB::table('conduce_legalidad_folio_reservas')->insertOrIgnore([
            'operativo_id' => $operativo->id,
            'client_uuid' => $clientUuid,
            'created_by' => $userId,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return (int) DB::table('conduce_legalidad_folio_reservas')
            ->where('operativo_id', $operativo->id)
            ->where('client_uuid', $clientUuid)
            ->lockForUpdate()
            ->value('id');
    }
'@
$controller = Replace-Required $controller $oldFolioMethod $newFolioMethod

$capturePayloadAnchor = @'
        return [
            'id' => $captura->id,
            'client_uuid' => $captura->client_uuid,
            'operativo_id' => $captura->operativo_id,
'@
$capturePayloadNew = @'
        return [
            'id' => $captura->id,
            'client_uuid' => $captura->client_uuid,
            'folio_numero' => $captura->folio_numero,
            'folio' => $this->folioCaptura($captura->operativo, $captura),
            'operativo_id' => $captura->operativo_id,
'@
$controller = Replace-Required $controller $capturePayloadAnchor $capturePayloadNew

$captureFunctionAnchor = @'
    private function capturaPayload(ConduceLegalidadCaptura $captura, $user): array
    {
        $captura->loadMissing(['creador', 'unidad', 'delegacion', 'infraccion', 'fundamentos.infraccion', 'vehiculos.infraccion', 'personas.infraccion', 'fotos']);
'@
$captureFunctionNew = @'
    private function capturaPayload(ConduceLegalidadCaptura $captura, $user): array
    {
        $captura->loadMissing(['operativo', 'creador', 'unidad', 'delegacion', 'infraccion', 'fundamentos.infraccion', 'vehiculos.infraccion', 'personas.infraccion', 'fotos']);
'@
$controller = Replace-Required $controller $captureFunctionAnchor $captureFunctionNew
Write-Utf8NoBom $controllerPath $controller

$model = (Get-Content -LiteralPath $modelPath -Raw).Replace("`r`n", "`n")
$oldModelFields = @'
        'client_uuid',
        'created_by',
'@
$newModelFields = @'
        'client_uuid',
        'folio_numero',
        'created_by',
'@
$model = Replace-Required $model $oldModelFields $newModelFields
Write-Utf8NoBom $modelPath $model

$route = "        Route::post('/operativos/{operativo}/capturas/reservar-folio', [ApiConduceLegalidadController::class, 'reservarFolioCaptura'])->whereNumber('operativo')->name('api.conduce_legalidad.capturas.reservar_folio');"
$routes = (Get-Content -LiteralPath $routesPath -Raw).Replace("`r`n", "`n")
$routes = Add-BeforeRequired $routes "        Route::post('/operativos/{operativo}/capturas', [ApiConduceLegalidadController::class, 'storeCaptura'])->whereNumber('operativo')->name('api.conduce_legalidad.capturas.store');" $route 'api.conduce_legalidad.capturas.reservar_folio'
Write-Utf8NoBom $routesPath $routes

Copy-Item -LiteralPath $migrationSource -Destination $migrationTarget -Force

Push-Location $backendRoot
try {
    & php artisan migrate --force
    if ($LASTEXITCODE -ne 0) {
        throw "La migración terminó con código $LASTEXITCODE"
    }
}
catch {
    Copy-Item -LiteralPath (Join-Path $backupRoot 'ConduceLegalidadController.php') -Destination $controllerPath -Force
    Copy-Item -LiteralPath (Join-Path $backupRoot 'ConduceLegalidadCaptura.php') -Destination $modelPath -Force
    Copy-Item -LiteralPath (Join-Path $backupRoot 'api.php') -Destination $routesPath -Force
    throw "No se pudo migrar la base. Se restauraron controlador, modelo y rutas. $($_.Exception.Message)"
}
finally {
    Pop-Location
}

Write-Output 'Backend SIERSE/grúas actualizado.'
Write-Output "Respaldo: $backupRoot"
Write-Output "Migración: $migrationTarget"
