<?php

namespace App\Services;

use App\Models\Comunicacion;
use App\Models\DeviceToken;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

class ComunicacionPushService
{
    // Run after the response: a push failure must never turn a saved message
    // into a failed HTTP send that the sender repeats.
    public function schedule(int $comunicacionId): void
    {
        app()->terminating(function () use ($comunicacionId) {
            $this->send($comunicacionId);
        });
    }

    public function send(int $comunicacionId): void
    {
        try {
            $comunicacion = Comunicacion::with('remitente')->find($comunicacionId);
            if (!$comunicacion) {
                return;
            }
            $userIds = $comunicacion->destinatarios()->pluck('user_id');
            $tokens = DeviceToken::whereIn('user_id', $userIds)
                ->where('user_id', '!=', $comunicacion->remitente_user_id)
                ->whereNotNull('token')->where('token', '!=', '')
                ->pluck('token')->unique()->values()->all();
            if (!$tokens) {
                Log::notice('Comunicacion without registered push devices', ['comunicacion_id' => $comunicacionId]);
                return;
            }
            $remitente = $comunicacion->remitente->nombre_completo
                ?? $comunicacion->remitente->name ?? 'Seguridad Vial';
            $body = trim((string) $comunicacion->contenido);
            $hasImages = $comunicacion->adjuntos()->exists();
            $ok = app(PushService::class)->sendToTokens($tokens, $remitente,
                Str::limit($body !== '' ? $body : 'Te envió una imagen', 180), [
                    'modulo' => 'comunicaciones',
                    'comunicacion_id' => (string) $comunicacion->id,
                    'remitente_user_id' => (string) $comunicacion->remitente_user_id,
                    'tipo' => $comunicacion->tipo,
                    'remitente' => $remitente,
                    'asunto' => $comunicacion->asunto,
                    'contenido' => Str::limit($body, 180),
                    'tiene_imagenes' => $hasImages ? '1' : '0',
                ]);
            if (!$ok) {
                Log::warning('Comunicacion push delivery failed', ['comunicacion_id' => $comunicacionId]);
            }
        } catch (Throwable $e) {
            Log::error('Comunicacion push exception', [
                'comunicacion_id' => $comunicacionId,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
