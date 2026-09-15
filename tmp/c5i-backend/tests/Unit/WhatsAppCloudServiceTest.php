<?php

namespace Tests\Unit;

use App\Services\WhatsAppCloudService;
use Tests\TestCase;

class WhatsAppCloudServiceTest extends TestCase
{
    public function test_send_template_sanitiza_parametros_de_texto_para_meta(): void
    {
        $service = new class extends WhatsAppCloudService {
            protected function request(array $payload): array
            {
                return [
                    'ok' => true,
                    'status' => 200,
                    'payload' => $payload,
                ];
            }
        };

        $response = $service->sendTemplate('5214431234567', 'template_prueba', [
            "Linea uno\n\tLinea dos     final",
        ]);

        $parameter = $response['payload']['template']['components'][0]['parameters'][0]['text'];

        $this->assertSame('Linea uno Linea dos final', $parameter);
        $this->assertDoesNotMatchRegularExpression('/[\r\n\t]/', $parameter);
        $this->assertDoesNotMatchRegularExpression('/ {5,}/', $parameter);
    }

    public function test_send_document_template_sanitiza_parametros_de_texto_para_meta(): void
    {
        $service = new class extends WhatsAppCloudService {
            protected function request(array $payload): array
            {
                return [
                    'ok' => true,
                    'status' => 200,
                    'payload' => $payload,
                ];
            }
        };

        $response = $service->sendDocumentTemplate(
            '5214431234567',
            'template_documento',
            'media-id',
            'archivo.pdf',
            ["A\tB\nC      D"]
        );

        $parameter = $response['payload']['template']['components'][1]['parameters'][0]['text'];

        $this->assertSame('A B C D', $parameter);
        $this->assertDoesNotMatchRegularExpression('/[\r\n\t]/', $parameter);
        $this->assertDoesNotMatchRegularExpression('/ {5,}/', $parameter);
    }

    public function test_send_template_with_url_button_builds_meta_components(): void
    {
        $service = new class extends WhatsAppCloudService {
            protected function request(array $payload): array
            {
                return ['ok' => true, 'status' => 200, 'payload' => $payload];
            }
        };

        $response = $service->sendTemplateWithUrlButton(
            '5214431234567',
            'alerta_tiempo_reaccion_siniestros_v2',
            ['folio', '174'],
            '321',
            'es_MX'
        );

        $components = $response['payload']['template']['components'];
        $this->assertSame('body', $components[0]['type']);
        $this->assertCount(2, $components[0]['parameters']);
        $this->assertSame('button', $components[1]['type']);
        $this->assertSame('url', $components[1]['sub_type']);
        $this->assertSame('0', $components[1]['index']);
        $this->assertSame('321', $components[1]['parameters'][0]['text']);
    }
}
