<?php

namespace App\Services;

use App\Models\C5iServiceResponse;
use App\Models\Patrulla;
use App\Models\Personal;
use App\Models\User;
use App\Models\UserLocation;
use App\Models\WhatsAppWebMessage;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

class C5iResponseTimeService
{
    private const CONTEXT = 'c5i-siniestros-tiempo-reaccion';

    private C5iSiniestrosRecommendationService $recommendations;
    private WhatsAppCloudService $whatsApp;
    private WhatsAppSendGuard $sendGuard;

    public function __construct(
        C5iSiniestrosRecommendationService $recommendations,
        WhatsAppCloudService $whatsApp,
        WhatsAppSendGuard $sendGuard
    ) {
        $this->recommendations = $recommendations;
        $this->whatsApp = $whatsApp;
        $this->sendGuard = $sendGuard;
    }

    public function processMessage(WhatsAppWebMessage $message): array
    {
        if (!(bool) config('services.whatsapp.c5i_response_time.enabled', false)) {
            return ['status' => 'disabled'];
        }

        try {
            return $this->processMessageSafely($message);
        } catch (Throwable $e) {
            Log::error('Error procesando tiempo de reacción C5i/Siniestros', [
                'whatsapp_web_message_id' => $message->id,
                'error' => $e->getMessage(),
            ]);

            return ['status' => 'failed', 'reason' => 'processing_exception'];
        }
    }

    public function processLocation(User $user, UserLocation $location): array
    {
        if (!(bool) config('services.whatsapp.c5i_response_time.enabled', false)) {
            return ['status' => 'disabled'];
        }

        try {
            $user->loadMissing(['unidad', 'patrulla', 'personal.patrulla']);

            if (!$this->isSiniestrosUser($user)) {
                return ['status' => 'ignored', 'reason' => 'user_not_siniestros'];
            }

            $patrulla = $user->personal && $user->personal->patrulla
                ? $user->personal->patrulla
                : $user->patrulla;

            if (!$patrulla) {
                return ['status' => 'ignored', 'reason' => 'patrulla_not_resolved'];
            }

            return $this->registerGpsArrival($patrulla, $location);
        } catch (Throwable $e) {
            Log::error('Error comparando ubicación con servicio C5i', [
                'user_id' => $user->id,
                'user_location_id' => $location->id,
                'error' => $e->getMessage(),
            ]);

            return ['status' => 'failed', 'reason' => 'processing_exception'];
        }
    }

    public function isOperationalMessageCandidate(?string $body): bool
    {
        $text = $this->normalizedText((string) $body);

        if ($text === '') {
            return false;
        }

        if (strpos($text, 'LATITUD') !== false && strpos($text, 'LONGITUD') !== false) {
            return true;
        }

        return $this->hasStrongAssignmentCue($text)
            || $this->hasArrivalCue($text)
            || $this->hasLooseAssignmentCue($text);
    }

    public function isOperationalAudioCandidate(?string $messageType, bool $hasMedia): bool
    {
        return $hasMedia && in_array(
            mb_strtolower(trim((string) $messageType), 'UTF-8'),
            ['audio', 'ptt', 'voice'],
            true
        );
    }

    public function shouldTranscribeAudio(WhatsAppWebMessage $message): bool
    {
        if (!(bool) config('services.whatsapp.c5i_response_time.enabled', false)
            || !(bool) config('services.whatsapp.c5i_response_time.transcribe_audio', true)
            || !$this->isOperationalAudioCandidate($message->message_type, (bool) $message->has_media)) {
            return false;
        }

        $message->loadMissing('group');

        if (!$this->groupAllowed((string) optional($message->group)->whatsapp_id)) {
            return false;
        }

        $at = $message->sent_at ?: now();
        $lookbackMinutes = max(30, (int) config(
            'services.whatsapp.c5i_response_time.open_service_minutes',
            240
        ));

        return C5iServiceResponse::query()
            ->where('whatsapp_web_group_id', $message->whatsapp_web_group_id)
            ->whereNotNull('assignment_message_id')
            ->whereNull('arrival_message_id')
            ->where('reported_at', '<=', $at)
            ->where('reported_at', '>=', $at->copy()->subMinutes($lookbackMinutes))
            ->exists();
    }

    public function isArrivalMessage(?string $body): bool
    {
        return $this->hasArrivalCue($this->normalizedText((string) $body));
    }

    private function processMessageSafely(WhatsAppWebMessage $message): array
    {
        $message->loadMissing('group');

        if (!$this->groupAllowed((string) optional($message->group)->whatsapp_id)) {
            return ['status' => 'ignored', 'reason' => 'group_not_allowed'];
        }

        $body = $this->operationalText($message);

        if ($this->recommendations->isExcludedIncident($body)) {
            return ['status' => 'ignored', 'reason' => 'arrival_code_not_relevant'];
        }

        $author = (string) $message->author_whatsapp_id;
        $incident = $this->recommendations->parseIncident($body);
        $normalized = $this->normalizedText($body);
        $patrulla = $this->resolvePatrulla($body, $author);

        if ($this->hasUnitReportCue($normalized) && $patrulla) {
            $arrivalResult = $this->recordArrival($message, $patrulla);

            if (($arrivalResult['status'] ?? 'ignored') !== 'ignored') {
                return $arrivalResult;
            }
        }

        if ($incident !== null && $this->sourceAllowed($author)) {
            return $this->recordIncident($message, $incident);
        }

        if ($this->dispatchAllowed($author)
            && $patrulla
            && $this->hasStrongAssignmentCue($normalized)) {
            return $this->recordAssignment($message, $patrulla);
        }

        if ($this->hasArrivalCue($normalized)) {
            if (!$patrulla) {
                return ['status' => 'ignored', 'reason' => 'arrival_patrulla_not_resolved'];
            }

            return $this->recordArrival($message, $patrulla);
        }

        if ($this->dispatchAllowed($author)
            && $patrulla
            && $this->hasLooseAssignmentCue($normalized)) {
            return $this->recordAssignment($message, $patrulla);
        }

        return ['status' => 'ignored', 'reason' => 'message_not_operational'];
    }

    private function recordIncident(WhatsAppWebMessage $message, array $incident): array
    {
        $response = C5iServiceResponse::query()->updateOrCreate(
            ['incident_message_id' => $message->id],
            [
                'whatsapp_web_group_id' => $message->whatsapp_web_group_id,
                'incident_reference' => $this->incidentReference((string) $message->body, $message->id),
                'incident_location' => $incident['location'],
                'incident_lat' => $incident['lat'],
                'incident_lng' => $incident['lng'],
                'reported_at' => $message->sent_at ?: now(),
                'status' => 'reported',
            ]
        );

        return ['status' => 'incident_recorded', 'response_id' => $response->id];
    }

    private function recordAssignment(WhatsAppWebMessage $message, Patrulla $patrulla): array
    {
        $response = $this->responseForMessage($message, null, true);

        if (!$response) {
            return ['status' => 'ignored', 'reason' => 'open_incident_not_found'];
        }

        $response->forceFill([
            'assignment_message_id' => $message->id,
            'patrulla_id' => $patrulla->id,
            'assigned_at' => $message->sent_at ?: now(),
            'status' => 'assigned',
        ])->save();

        return [
            'status' => 'assigned',
            'response_id' => $response->id,
            'patrulla_id' => $patrulla->id,
        ];
    }

    private function recordArrival(WhatsAppWebMessage $message, Patrulla $patrulla): array
    {
        $response = $this->responseForMessage($message, $patrulla, false);

        if (!$response) {
            return ['status' => 'ignored', 'reason' => 'assigned_incident_not_found'];
        }

        $arrivalAt = ($message->sent_at ? $message->sent_at->copy() : now())
            ->timezone('America/Mexico_City');
        $gpsAt = $response->gps_arrived_at
            ? $response->gps_arrived_at->copy()->timezone('America/Mexico_City')
            : null;

        $response->forceFill([
            'arrival_message_id' => $message->id,
            'arrival_reported_at' => $arrivalAt,
            'arrival_source' => $this->isOperationalAudioCandidate(
                $message->message_type,
                (bool) $message->has_media
            ) ? 'audio_transcription' : 'text_message',
            'arrival_message_delay_seconds' => $gpsAt
                ? $gpsAt->diffInSeconds($arrivalAt, false)
                : null,
            'status' => 'complete',
        ])->save();

        $this->notifyIfComplete($response->fresh(['patrulla']));

        return [
            'status' => 'complete',
            'response_id' => $response->id,
            'patrulla_id' => $patrulla->id,
        ];
    }

    private function registerGpsArrival(Patrulla $patrulla, UserLocation $location): array
    {
        $capturedAt = $location->captured_at
            ? $location->captured_at->copy()->timezone('America/Mexico_City')
            : now('America/Mexico_City');
        $maxAccuracy = max(0, (int) config(
            'services.whatsapp.c5i_response_time.max_accuracy_meters',
            100
        ));

        if ($maxAccuracy > 0
            && $location->accuracy !== null
            && (float) $location->accuracy > $maxAccuracy) {
            return ['status' => 'ignored', 'reason' => 'gps_accuracy_too_low'];
        }

        $lookbackMinutes = max(30, (int) config(
            'services.whatsapp.c5i_response_time.open_service_minutes',
            240
        ));
        $radiusMeters = max(25, (int) config(
            'services.whatsapp.c5i_response_time.arrival_radius_meters',
            200
        ));

        $responses = C5iServiceResponse::query()
            ->where('patrulla_id', $patrulla->id)
            ->whereNull('gps_arrived_at')
            ->whereNotNull('assigned_at')
            ->where('reported_at', '<=', $capturedAt)
            ->where('reported_at', '>=', $capturedAt->copy()->subMinutes($lookbackMinutes))
            ->latest('reported_at')
            ->get();

        $nearest = null;

        foreach ($responses as $response) {
            $distance = $this->haversineMeters(
                (float) $response->incident_lat,
                (float) $response->incident_lng,
                (float) $location->lat,
                (float) $location->lng
            );

            if ($distance <= $radiusMeters
                && ($nearest === null || $distance < $nearest['distance'])) {
                $nearest = ['response' => $response, 'distance' => $distance];
            }
        }

        if ($nearest === null) {
            return ['status' => 'outside_arrival_radius'];
        }

        /** @var C5iServiceResponse $response */
        $response = $nearest['response'];
        $reportedAt = $response->reported_at->copy()->timezone('America/Mexico_City');
        $assignedAt = $response->assigned_at
            ? $response->assigned_at->copy()->timezone('America/Mexico_City')
            : null;
        $arrivalMessageAt = $response->arrival_reported_at
            ? $response->arrival_reported_at->copy()->timezone('America/Mexico_City')
            : null;

        $response->forceFill([
            'gps_arrived_at' => $capturedAt,
            'gps_distance_meters' => round($nearest['distance'], 2),
            'gps_accuracy_meters' => $location->accuracy !== null
                ? round((float) $location->accuracy, 2)
                : null,
            'report_to_gps_seconds' => max(0, $reportedAt->diffInSeconds($capturedAt, false)),
            'assignment_to_gps_seconds' => $assignedAt
                ? max(0, $assignedAt->diffInSeconds($capturedAt, false))
                : null,
            'arrival_message_delay_seconds' => $arrivalMessageAt
                ? $capturedAt->diffInSeconds($arrivalMessageAt, false)
                : null,
            'status' => $arrivalMessageAt ? 'complete' : 'gps_arrived',
        ])->save();

        $this->notifyIfComplete($response->fresh(['patrulla']));

        return [
            'status' => $arrivalMessageAt ? 'complete' : 'gps_arrived',
            'response_id' => $response->id,
            'distance_meters' => round($nearest['distance'], 2),
        ];
    }

    private function responseForMessage(
        WhatsAppWebMessage $message,
        ?Patrulla $patrulla,
        bool $forAssignment
    ): ?C5iServiceResponse {
        $quotedId = trim((string) $message->quoted_whatsapp_message_id);

        if ($quotedId !== '') {
            $quoted = WhatsAppWebMessage::query()
                ->where('whatsapp_message_id', $quotedId)
                ->first();

            if ($quoted) {
                $quotedResponse = C5iServiceResponse::query()
                    ->where(function ($query) use ($quoted) {
                        $query->where('incident_message_id', $quoted->id)
                            ->orWhere('assignment_message_id', $quoted->id)
                            ->orWhere('arrival_message_id', $quoted->id);
                    })
                    ->first();

                if ($quotedResponse
                    && (!$patrulla || !$quotedResponse->patrulla_id
                        || (int) $quotedResponse->patrulla_id === (int) $patrulla->id)) {
                    return $quotedResponse;
                }
            }
        }

        $lookbackMinutes = max(30, (int) config(
            'services.whatsapp.c5i_response_time.open_service_minutes',
            240
        ));
        $query = C5iServiceResponse::query()
            ->where('whatsapp_web_group_id', $message->whatsapp_web_group_id)
            ->where('reported_at', '<=', $message->sent_at ?: now())
            ->where('reported_at', '>=', ($message->sent_at ?: now())->copy()->subMinutes($lookbackMinutes));

        if ($forAssignment) {
            $query->whereNull('assignment_message_id');
        } else {
            $query->where('patrulla_id', $patrulla->id)
                ->whereNotNull('assignment_message_id')
                ->whereNull('arrival_message_id');
        }

        return $query->latest('reported_at')->first();
    }

    private function resolvePatrulla(string $body, string $authorId): ?Patrulla
    {
        $fromText = $this->patrullaFromText($body);

        if ($fromText) {
            return $fromText;
        }

        return $this->patrullaFromAuthor($authorId);
    }

    private function patrullaFromText(string $body): ?Patrulla
    {
        $unitSlug = trim((string) config(
            'services.whatsapp.c5i_response_time.unit_slug',
            'siniestros'
        )) ?: 'siniestros';
        $patrullas = Patrulla::query()
            ->where('activa', 1)
            ->whereHas('unidad', function ($query) use ($unitSlug) {
                $query->where('slug', $unitSlug);
            })
            ->get()
            ->sortByDesc(function (Patrulla $patrulla) {
                return strlen(preg_replace('/\D+/', '', (string) $patrulla->numero_economico) ?: '');
            });

        foreach ($patrullas as $patrulla) {
            $digits = preg_replace('/\D+/', '', (string) $patrulla->numero_economico) ?: '';
            $aliases = array_values(array_unique(array_filter([
                $digits,
                ltrim($digits, '0'),
            ])));

            foreach ($aliases as $alias) {
                if (strlen($alias) < 3) {
                    continue;
                }

                $parts = str_split($alias);
                $pattern = implode('[\s\-\.]*', array_map('preg_quote', $parts));

                if (preg_match('/(?<!\d)' . $pattern . '(?!\d)/u', $body)) {
                    return $patrulla;
                }
            }
        }

        return null;
    }

    private function patrullaFromAuthor(string $authorId): ?Patrulla
    {
        $authorDigits = preg_replace('/\D+/', '', $authorId) ?: '';

        if ($authorDigits === '') {
            return null;
        }

        $users = User::query()
            ->where(function ($query) {
                $query->whereNotNull('telefono_whatsapp_operativo')
                    ->orWhereNotNull('telefono_whatsapp_operativo_secundario');
            })
            ->whereNotNull('patrulla_id')
            ->with(['unidad', 'patrulla'])
            ->get();

        foreach ($users as $user) {
            if (($this->samePhone($authorDigits, (string) $user->telefono_whatsapp_operativo)
                    || $this->samePhone($authorDigits, (string) $user->telefono_whatsapp_operativo_secundario))
                && $this->isSiniestrosUser($user)) {
                return $user->patrulla;
            }
        }

        $personals = Personal::query()
            ->whereNotNull('patrulla_id')
            ->with(['unidad', 'patrulla', 'contactos'])
            ->get();

        foreach ($personals as $personal) {
            if (mb_strtolower((string) optional($personal->unidad)->slug, 'UTF-8') !== 'siniestros') {
                continue;
            }

            foreach ($personal->contactos as $contacto) {
                foreach (['telefono_personal', 'telefono_secundario', 'valor'] as $field) {
                    if ($this->samePhone($authorDigits, (string) $contacto->{$field})) {
                        return $personal->patrulla;
                    }
                }
            }
        }

        return null;
    }

    private function notifyIfComplete(C5iServiceResponse $response): void
    {
        if (!$response->arrival_reported_at) {
            return;
        }

        if (in_array($response->notification_status, ['sent', 'dry_run'], true)) {
            return;
        }

        $recipients = $this->recipientNumbers();
        $template = trim((string) config('services.whatsapp.c5i_response_time.template', ''));
        $language = trim((string) config(
            'services.whatsapp.c5i_response_time.template_language',
            'es_MX'
        )) ?: 'es_MX';
        $params = $this->templateParams($response);
        $meta = [
            'template' => $template,
            'template_language' => $language,
            'recipients' => $recipients,
            'template_params' => $params,
        ];

        if ((bool) config('services.whatsapp.c5i_response_time.dry_run', true)) {
            $response->forceFill([
                'notification_status' => 'dry_run',
                'notification_meta' => $meta,
                'notification_processed_at' => now(),
            ])->save();
            return;
        }

        if (empty($recipients) || $template === '') {
            $meta['reason'] = empty($recipients)
                ? 'recipients_not_configured'
                : 'template_not_configured';
            $response->forceFill([
                'notification_status' => 'failed',
                'notification_meta' => $meta,
                'notification_processed_at' => now(),
            ])->save();
            return;
        }

        $results = [];
        $sent = 0;

        foreach ($recipients as $recipient) {
            $periodKey = 'response:' . $response->id;

            if (!$this->sendGuard->reserve(self::CONTEXT, $periodKey, $recipient, 30)) {
                $results[] = ['recipient' => $recipient, 'status' => 'duplicate'];
                continue;
            }

            try {
                $result = $this->whatsApp->sendTemplate($recipient, $template, $params, $language);

                if (!($result['ok'] ?? false)) {
                    $this->sendGuard->release(self::CONTEXT, $periodKey, $recipient);
                    $results[] = [
                        'recipient' => $recipient,
                        'status' => 'failed',
                        'error' => data_get($result, 'body.error.message'),
                    ];
                    continue;
                }

                $messageId = data_get($result, 'body.messages.0.id');
                $this->sendGuard->markSent(self::CONTEXT, $periodKey, $recipient, $messageId, 30);
                $results[] = [
                    'recipient' => $recipient,
                    'status' => 'sent',
                    'message_id' => $messageId,
                ];
                $sent++;
            } catch (Throwable $e) {
                $this->sendGuard->release(self::CONTEXT, $periodKey, $recipient);
                $results[] = [
                    'recipient' => $recipient,
                    'status' => 'failed',
                    'error' => $e->getMessage(),
                ];
            }
        }

        $status = $sent === count($recipients)
            ? 'sent'
            : ($sent > 0 ? 'partial' : 'failed');
        $meta['send_results'] = $results;

        $response->forceFill([
            'notification_status' => $status,
            'notification_meta' => $meta,
            'notification_processed_at' => now(),
        ])->save();
    }

    private function templateParams(C5iServiceResponse $response): array
    {
        $timezone = (string) config('app.schedule_timezone', 'America/Mexico_City');
        $patrulla = $response->patrulla
            ? (string) $response->patrulla->numero_economico
            : 'Sin unidad';
        $assignment = $response->assigned_at
            ? $response->assigned_at->copy()->timezone($timezone)->format('d/m/Y H:i:s')
            : 'Sin hora de asignación';
        $accuracy = $response->gps_accuracy_meters !== null
            ? number_format((float) $response->gps_accuracy_meters, 0, '.', '') . ' m'
            : 'sin dato';
        $reportedAt = $response->reported_at->copy()->timezone($timezone);
        $arrivalAt = $response->arrival_reported_at->copy()->timezone($timezone);
        $gpsAt = $response->gps_arrived_at
            ? $response->gps_arrived_at->copy()->timezone($timezone)
            : null;
        $reactionSeconds = max(0, $reportedAt->diffInSeconds($arrivalAt, false));
        $assignmentReactionSeconds = $response->assigned_at
            ? max(0, $response->assigned_at->copy()->timezone($timezone)
                ->diffInSeconds($arrivalAt, false))
            : null;
        $arrivalSource = $response->arrival_source === 'audio_transcription'
            ? 'audio transcrito'
            : 'mensaje de llegada';
        $gpsDetail = $gpsAt
            ? $this->delayDescription((int) $response->arrival_message_delay_seconds)
                . '; GPS a ' . number_format((float) $response->gps_distance_meters, 0, '.', '')
                . ' m del punto; precisión ' . $accuracy
            : 'Llegada confirmada por ' . $arrivalSource
                . '; C5i → audio: ' . $this->humanDuration($reactionSeconds)
                . '; asignación → audio: ' . ($assignmentReactionSeconds !== null
                    ? $this->humanDuration($assignmentReactionSeconds)
                    : 'sin hora de asignación')
                . '; sin lectura GPS disponible';

        return [
            $response->incident_reference ?: ('C5i #' . $response->id),
            $patrulla,
            $this->limitText((string) $response->incident_location, 400),
            $reportedAt->format('d/m/Y H:i:s'),
            $assignment,
            $gpsAt ? $gpsAt->format('d/m/Y H:i:s') : 'Sin lectura GPS',
            $arrivalAt->format('d/m/Y H:i:s'),
            $gpsAt && $response->report_to_gps_seconds !== null
                ? $this->humanDuration((int) $response->report_to_gps_seconds)
                : 'Sin lectura GPS',
            $gpsAt && $response->assignment_to_gps_seconds !== null
                ? $this->humanDuration((int) $response->assignment_to_gps_seconds)
                : 'Sin lectura GPS',
            $gpsDetail,
        ];
    }

    private function operationalText(WhatsAppWebMessage $message): string
    {
        $transcription = trim((string) $message->transcription_text);

        return $transcription !== '' ? $transcription : (string) $message->body;
    }

    private function delayDescription(int $seconds): string
    {
        if ($seconds > 0) {
            return 'El mensaje se envió ' . $this->humanDuration($seconds)
                . ' después del arribo GPS';
        }

        if ($seconds < 0) {
            return 'El GPS confirmó ' . $this->humanDuration(abs($seconds))
                . ' después del mensaje';
        }

        return 'El mensaje y el arribo GPS coinciden';
    }

    private function humanDuration(int $seconds): string
    {
        $seconds = abs($seconds);

        if ($seconds < 60) {
            return $seconds . ' segundos';
        }

        $minutes = intdiv($seconds, 60);
        $remaining = $seconds % 60;

        return $remaining > 0
            ? $minutes . ' min ' . $remaining . ' s'
            : $minutes . ' minutos';
    }

    private function hasStrongAssignmentCue(string $text): bool
    {
        return (bool) preg_match(
            '/\b(APROX(?:IMA(?:TE|RSE|R)?|IMARSE)?|ACUDE|ACUDIR|ATIENDE|ATENDER|DIRIGETE|DIRIJASE|TRASLADATE|TRASLADARSE|ASIGNAD[AO]|SERVICIO\s+PARA)\b/u',
            $text
        );
    }

    private function hasLooseAssignmentCue(string $text): bool
    {
        return (bool) preg_match('/\bK\s*\d+[A-Z]?\b|\b(?:AL|A)\s+(?:EL\s+)?40\b/u', $text);
    }

    private function hasArrivalCue(string $text): bool
    {
        return (bool) preg_match(
            '/(?:^|\s)86(?:\s|$)|\b(ARRIB(?:O|AMOS|ANDO|A)|LLEG(?:O|AMOS|ANDO|ADA)|YA\s+(?:ESTAMOS\s+)?EN|EN\s+EL\s+LUGAR|EN\s+EL\s+PUNTO|EN\s+PUNTO|PRESENTES\s+EN|EN\s+(?:EL\s+)?40|EN\s+(?:EL\s+)?K\s*\d+[A-Z]?|INFORMA\s+UNIDAD)\b/u',
            $text
        );
    }

    private function hasUnitReportCue(string $text): bool
    {
        return (bool) preg_match('/\bINFORMA\s+UNIDAD\b/u', $text);
    }

    private function normalizedText(string $text): string
    {
        $text = mb_strtoupper(Str::ascii($text), 'UTF-8');
        $text = preg_replace('/[^A-Z0-9\s]+/u', ' ', $text) ?? $text;

        return preg_replace('/\s+/u', ' ', trim($text)) ?? trim($text);
    }

    private function incidentReference(string $body, int $fallbackId): string
    {
        if (preg_match('/\b(?:FOLIO|INCIDENTE|REPORTE)\s*(?:C5I?)?\s*[:#-]?\s*([A-Z0-9\/-]{4,40})/iu', $body, $matches)) {
            return 'C5i ' . trim($matches[1]);
        }

        return 'C5i WA-' . $fallbackId;
    }

    private function samePhone(string $left, string $right): bool
    {
        $left = preg_replace('/\D+/', '', $left) ?: '';
        $right = preg_replace('/\D+/', '', $right) ?: '';

        if ($left === '' || $right === '') {
            return false;
        }

        if (hash_equals($left, $right)) {
            return true;
        }

        return strlen($left) >= 10
            && strlen($right) >= 10
            && hash_equals(substr($left, -10), substr($right, -10));
    }

    private function isSiniestrosUser(User $user): bool
    {
        return (int) $user->unidad_id === 1
            || mb_strtolower((string) optional($user->unidad)->slug, 'UTF-8') === 'siniestros';
    }

    private function groupAllowed(string $groupId): bool
    {
        return $this->identifierInConfig(
            $groupId,
            'services.whatsapp.c5i_response_time.group_ids'
        );
    }

    private function sourceAllowed(string $authorId): bool
    {
        return $this->identifierInConfig(
            $authorId,
            'services.whatsapp.c5i_response_time.source_author_ids'
        );
    }

    private function dispatchAllowed(string $authorId): bool
    {
        return $this->identifierInConfig(
            $authorId,
            'services.whatsapp.c5i_response_time.dispatch_author_ids'
        );
    }

    private function identifierInConfig(string $identifier, string $key): bool
    {
        $normalized = mb_strtolower(trim($identifier), 'UTF-8');
        $digits = preg_replace('/\D+/', '', $normalized) ?: '';

        foreach ($this->csvConfig($key) as $configured) {
            $allowed = mb_strtolower(trim($configured), 'UTF-8');
            $allowedDigits = preg_replace('/\D+/', '', $allowed) ?: '';

            if ($normalized !== '' && hash_equals($allowed, $normalized)) {
                return true;
            }

            if ($digits !== '' && $allowedDigits !== ''
                && ($this->samePhone($digits, $allowedDigits) || hash_equals($digits, $allowedDigits))) {
                return true;
            }
        }

        return false;
    }

    private function recipientNumbers(): array
    {
        $numbers = [];

        foreach ($this->csvConfig('services.whatsapp.c5i_response_time.to') as $recipient) {
            $number = preg_replace('/\D+/', '', $recipient) ?: '';

            if (strlen($number) >= 10 && strlen($number) <= 15) {
                $numbers[] = $number;
            }
        }

        return array_values(array_unique($numbers));
    }

    private function csvConfig(string $key): array
    {
        $parts = preg_split('/[\s,;|]+/', (string) config($key, ''), -1, PREG_SPLIT_NO_EMPTY);

        return array_values(array_unique(array_filter(array_map(
            function ($value) {
                return trim((string) $value);
            },
            $parts ?: []
        ))));
    }

    private function limitText(string $text, int $limit): string
    {
        $text = preg_replace('/\s+/u', ' ', trim($text)) ?? trim($text);

        return mb_strlen($text, 'UTF-8') <= $limit
            ? $text
            : mb_substr($text, 0, $limit - 3, 'UTF-8') . '...';
    }

    private function haversineMeters(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadiusMeters = 6371008.8;
        $latDelta = deg2rad($lat2 - $lat1);
        $lngDelta = deg2rad($lng2 - $lng1);
        $a = sin($latDelta / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($lngDelta / 2) ** 2;

        return $earthRadiusMeters * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
