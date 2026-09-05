<?php

namespace App\Services;

use Google\Auth\ApplicationDefaultCredentials;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PushService
{
    public function sendToTokens(array $tokens, string $title, string $body, array $data = []): bool
    {
        $projectId = config('services.firebase.project_id');
        $serviceAccountPath = config('services.firebase.service_account');

        if (!$projectId || !$serviceAccountPath) {
            Log::error('FCM config missing', ['project_id' => $projectId, 'service_account' => $serviceAccountPath]);
            return false;
        }

        if (!file_exists($serviceAccountPath)) {
            Log::error('FCM service account file not found', ['path' => $serviceAccountPath]);
            return false;
        }

        try {
            putenv('GOOGLE_APPLICATION_CREDENTIALS='.$serviceAccountPath);

            $scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
            $creds = ApplicationDefaultCredentials::getCredentials($scopes);
            $tokenArr = $creds->fetchAuthToken();

            $accessToken = $tokenArr['access_token'] ?? null;
            if (!$accessToken) {
                Log::error('FCM access token missing');
                return false;
            }

            $endpoint = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";

            $allOk = true;

            foreach ($tokens as $t) {
                $payload = [
                    'message' => [
                        'token' => $t,
                        'notification' => [
                            'title' => $title,
                            'body'  => $body,
                        ],
                        'data' => $this->stringifyData($data),
                    ] + self::platformOptions($data),
                ];

                $res = Http::timeout(15)
                    ->withToken($accessToken)
                    ->post($endpoint, $payload);

                if (!$res->ok()) {
                    $allOk = false;
                    Log::warning('FCM send failed', [
                        'status' => $res->status(),
                        'body' => $res->body(),
                    ]);
                }
            }

            return $allOk;

        } catch (\Throwable $e) {
            Log::error('FCM send exception', ['error' => $e->getMessage()]);
            return false;
        }
    }

    public static function platformOptions(array $data): array
    {
        if (($data['modulo'] ?? '') !== 'comunicaciones') {
            return [];
        }
        return [
            'android' => [
                'priority' => 'high',
                'notification' => [
                    'channel_id' => 'comunicaciones_v3',
                    'sound' => 'message_received',
                    'tag' => 'comunicacion_'.($data['comunicacion_id'] ?? ''),
                ],
            ],
            'apns' => [
                'headers' => ['apns-priority' => '10', 'apns-push-type' => 'alert'],
                'payload' => ['aps' => ['sound' => 'default']],
            ],
        ];
    }

    private function stringifyData(array $data): array
    {
        $out = [];
        foreach ($data as $k => $v) {
            $out[$k] = is_string($v) ? $v : json_encode($v, JSON_UNESCAPED_UNICODE);
        }
        return $out;
    }
}
