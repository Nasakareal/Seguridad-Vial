<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class WhatsAppCloudService
{
    public function sendText(string $to, string $body): array
    {
        return $this->request([
            'messaging_product' => 'whatsapp',
            'to' => $this->normalizeTo($to),
            'type' => 'text',
            'text' => [
                'preview_url' => false,
                'body' => $body,
            ],
        ]);
    }

    public function sendTemplate(string $to, string $templateName, array $bodyParameters = [], string $language = 'es_MX'): array
    {
        $parameters = [];

        foreach ($bodyParameters as $value) {
            $parameters[] = [
                'type' => 'text',
                'text' => $this->templateTextParameter((string) $value),
            ];
        }

        return $this->request([
            'messaging_product' => 'whatsapp',
            'to' => $this->normalizeTo($to),
            'type' => 'template',
            'template' => [
                'name' => $templateName,
                'language' => [
                    'code' => $language,
                ],
                'components' => [
                    [
                        'type' => 'body',
                        'parameters' => $parameters,
                    ],
                ],
            ],
        ]);
    }

    public function sendTemplateWithUrlButton(
        string $to,
        string $templateName,
        array $bodyParameters,
        string $urlSuffix,
        string $language = 'es_MX',
        int $buttonIndex = 0
    ): array {
        $parameters = [];

        foreach ($bodyParameters as $value) {
            $parameters[] = [
                'type' => 'text',
                'text' => $this->templateTextParameter((string) $value),
            ];
        }

        return $this->request([
            'messaging_product' => 'whatsapp',
            'to' => $this->normalizeTo($to),
            'type' => 'template',
            'template' => [
                'name' => $templateName,
                'language' => ['code' => $language],
                'components' => [
                    [
                        'type' => 'body',
                        'parameters' => $parameters,
                    ],
                    [
                        'type' => 'button',
                        'sub_type' => 'url',
                        'index' => (string) $buttonIndex,
                        'parameters' => [[
                            'type' => 'text',
                            'text' => $this->templateTextParameter($urlSuffix),
                        ]],
                    ],
                ],
            ],
        ]);
    }

    public function sendInteractive(string $to, array $interactive): array
    {
        return $this->request([
            'messaging_product' => 'whatsapp',
            'to' => $this->normalizeTo($to),
            'type' => 'interactive',
            'interactive' => $interactive,
        ]);
    }

    public function sendImage(string $to, string $imageUrl): array
    {
        return $this->request([
            'messaging_product' => 'whatsapp',
            'to' => $this->normalizeTo($to),
            'type' => 'image',
            'image' => [
                'link' => $imageUrl,
            ],
        ]);
    }

    public function sendDocument(string $to, string $mediaId, string $filename, ?string $caption = null): array
    {
        $document = [
            'id' => $mediaId,
            'filename' => $filename,
        ];

        if ($caption !== null && trim($caption) !== '') {
            $document['caption'] = $caption;
        }

        return $this->request([
            'messaging_product' => 'whatsapp',
            'to' => $this->normalizeTo($to),
            'type' => 'document',
            'document' => $document,
        ]);
    }

    public function sendDocumentTemplate(
        string $to,
        string $templateName,
        string $mediaId,
        string $filename,
        array $bodyParameters = [],
        string $language = 'es_MX'
    ): array {
        $components = [
            [
                'type' => 'header',
                'parameters' => [
                    [
                        'type' => 'document',
                        'document' => [
                            'id' => $mediaId,
                            'filename' => $filename,
                        ],
                    ],
                ],
            ],
        ];

        if (!empty($bodyParameters)) {
            $parameters = [];

            foreach ($bodyParameters as $value) {
                $parameters[] = [
                    'type' => 'text',
                    'text' => $this->templateTextParameter((string) $value),
                ];
            }

            $components[] = [
                'type' => 'body',
                'parameters' => $parameters,
            ];
        }

        return $this->request([
            'messaging_product' => 'whatsapp',
            'to' => $this->normalizeTo($to),
            'type' => 'template',
            'template' => [
                'name' => $templateName,
                'language' => [
                    'code' => $language,
                ],
                'components' => $components,
            ],
        ]);
    }

    public function sendDocumentFromPath(string $to, string $filePath, ?string $filename = null, ?string $caption = null, string $mimeType = 'application/pdf'): array
    {
        $upload = $this->uploadMedia($filePath, $mimeType);

        if (!($upload['ok'] ?? false)) {
            $upload['stage'] = 'upload';
            return $upload;
        }

        $mediaId = $upload['body']['id'] ?? null;

        if (!$mediaId) {
            return [
                'ok' => false,
                'status' => $upload['status'] ?? 0,
                'body' => ['error' => 'Meta respondio sin media id.'],
                'raw' => $upload['raw'] ?? null,
                'payload' => $upload['payload'] ?? null,
                'url' => $upload['url'] ?? null,
                'stage' => 'upload',
                'upload' => $upload,
            ];
        }

        $response = $this->sendDocument(
            $to,
            (string) $mediaId,
            $filename ?: basename($filePath),
            $caption
        );
        $response['upload'] = $upload;

        return $response;
    }

    public function uploadMedia(string $filePath, string $mimeType = 'application/pdf'): array
    {
        if (!is_file($filePath) || !is_readable($filePath)) {
            return [
                'ok' => false,
                'status' => 0,
                'body' => ['error' => 'El archivo no existe o no se puede leer.'],
                'raw' => null,
                'payload' => ['file' => $filePath, 'type' => $mimeType],
                'url' => null,
            ];
        }

        [$graphVersion, $accessToken, $phoneNumberId] = $this->credentials();

        if ($accessToken === '' || $phoneNumberId === '') {
            Log::warning('WA Cloud sin configuracion para media', [
                'file' => basename($filePath),
                'type' => $mimeType,
            ]);

            return [
                'ok' => false,
                'status' => 0,
                'body' => ['error' => 'Configuracion incompleta de WhatsApp.'],
                'raw' => null,
                'payload' => ['file' => $filePath, 'type' => $mimeType],
                'url' => null,
            ];
        }

        $url = "https://graph.facebook.com/{$graphVersion}/{$phoneNumberId}/media";
        $handle = fopen($filePath, 'r');

        if (!is_resource($handle)) {
            return [
                'ok' => false,
                'status' => 0,
                'body' => ['error' => 'No se pudo abrir el archivo para subirlo a Meta.'],
                'raw' => null,
                'payload' => ['file' => $filePath, 'type' => $mimeType],
                'url' => $url,
            ];
        }

        try {
            $response = Http::withToken($accessToken)
                ->attach('file', $handle, basename($filePath), ['Content-Type' => $mimeType])
                ->post($url, [
                    'messaging_product' => 'whatsapp',
                    'type' => $mimeType,
                ]);
        } finally {
            if (is_resource($handle)) {
                fclose($handle);
            }
        }

        Log::info('WA Cloud media upload response', [
            'file' => basename($filePath),
            'type' => $mimeType,
            'status' => $response->status(),
            'body' => $response->json(),
        ]);

        return [
            'ok' => $response->successful(),
            'status' => $response->status(),
            'body' => $response->json(),
            'raw' => $response->body(),
            'payload' => [
                'messaging_product' => 'whatsapp',
                'type' => $mimeType,
                'file' => basename($filePath),
            ],
            'url' => $url,
        ];
    }

    protected function request(array $payload): array
    {
        [$graphVersion, $accessToken, $phoneNumberId] = $this->credentials();

        if ($accessToken === '' || $phoneNumberId === '') {
            Log::warning('WA Cloud sin configuración', [
                'to' => $payload['to'] ?? null,
                'type' => $payload['type'] ?? null,
            ]);

            return [
                'ok' => false,
                'status' => 0,
                'body' => ['error' => 'Configuración incompleta de WhatsApp.'],
                'raw' => null,
                'payload' => $payload,
                'url' => null,
            ];
        }

        $url = "https://graph.facebook.com/{$graphVersion}/{$phoneNumberId}/messages";

        $response = Http::withToken($accessToken)
            ->acceptJson()
            ->asJson()
            ->post($url, $payload);

        Log::info('WA Cloud response', [
            'to' => $payload['to'] ?? null,
            'type' => $payload['type'] ?? null,
            'status' => $response->status(),
            'body' => $response->json(),
        ]);

        return [
            'ok' => $response->successful(),
            'status' => $response->status(),
            'body' => $response->json(),
            'raw' => $response->body(),
            'payload' => $payload,
            'url' => $url,
        ];
    }

    protected function normalizeTo(string $to): string
    {
        return preg_replace('/\D+/', '', $to ?? '');
    }

    protected function templateTextParameter(string $text): string
    {
        $text = str_replace(["\r\n", "\r", "\n", "\t"], ' ', $text);
        $text = preg_replace('/ {2,}/', ' ', $text) ?? $text;

        return trim($text);
    }

    protected function credentials(): array
    {
        return [
            (string) config('services.whatsapp.graph_version', 'v19.0'),
            (string) (
                config('services.whatsapp.token')
                ?: config('services.whatsapp.access_token')
                ?: env('WHATSAPP_ACCESS_TOKEN')
            ),
            (string) config('services.whatsapp.phone_number_id', ''),
        ];
    }
}
