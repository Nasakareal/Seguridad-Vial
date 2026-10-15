<?php

namespace Tests\Unit;

use App\Http\Controllers\Api\ConduceLegalidadController;
use App\Models\ConduceLegalidadCaptura;
use App\Models\ConduceLegalidadOperativo;
use App\Models\ConduceLegalidadPersona;
use App\Models\ConduceLegalidadVehiculo;
use App\Services\IphPuestaDisposicionDocxService;
use App\Services\WhatsAppCloudService;
use Illuminate\Support\Collection;
use Mockery;
use ReflectionMethod;
use Tests\TestCase;

class ConduceLegalidadBarandillasWhatsappTest extends TestCase
{
    public function test_envio_automatico_solicita_el_iph_exclusivo_de_vehiculo(): void
    {
        config()->set('services.whatsapp.conduce_legalidad.barandillas_enabled', true);
        config()->set('services.whatsapp.conduce_legalidad.barandillas_to', '5214433163728');
        config()->set('services.whatsapp.conduce_legalidad.barandillas_boleta_template', 'aviso_barandillas_conduce_v1');
        config()->set('services.whatsapp.conduce_legalidad.barandillas_iph_template', 'iph_barandillas_conduce_v1');

        [$operativo, $captura] = $this->capturaConVehiculo();
        $iphPath = tempnam(sys_get_temp_dir(), 'iph_barandillas_test_');
        file_put_contents($iphPath, 'documento de prueba');

        $whatsApp = Mockery::mock(WhatsAppCloudService::class);
        $whatsApp->shouldReceive('uploadMedia')->twice()->andReturn(
            ['ok' => true, 'body' => ['id' => 'media-boleta']],
            ['ok' => true, 'body' => ['id' => 'media-iph']]
        );
        $whatsApp->shouldReceive('sendDocumentTemplate')->twice()->andReturn(['ok' => true]);

        $docx = Mockery::mock(IphPuestaDisposicionDocxService::class);
        $docx->shouldReceive('generarConduceLegalidadBarandillasSoloVehiculo')
            ->once()
            ->andReturn([$iphPath, 'iph_barandillas_conduce_vehiculo_CL_10_20.docx']);

        $resultado = $this->invocarNotificacion($operativo, $captura, $whatsApp, $docx);

        $this->assertTrue($resultado['ok']);
        $this->assertTrue($resultado['enviado']);
        $this->assertTrue($resultado['data']['boleta_enviada']);
        $this->assertTrue($resultado['data']['iph_enviado']);
        $this->assertFileDoesNotExist($iphPath);
    }

    private function capturaConVehiculo(): array
    {
        $operativo = new ConduceLegalidadOperativo([
            'municipio' => 'Morelia',
            'lugar' => 'Avenida Madero',
            'tipo_operativo' => 'conduce_legalidad',
            'unidad_id' => 3,
            'firmante_iph_nombres' => 'Laura Beatriz',
            'firmante_iph_apellido_paterno' => 'Ramírez',
            'firmante_iph_apellido_materno' => 'Torres',
        ]);
        $operativo->id = 10;
        $operativo->setRelation('creador', null);

        $captura = new ConduceLegalidadCaptura([
            'municipio' => 'Morelia',
            'lugar' => 'Avenida Madero',
            'fecha' => '2026-10-14',
            'hora' => '10:45',
            'fundamento_legal' => 'Artículo 402.',
            'agente_nombre' => 'Agente del resguardo',
        ]);
        $captura->id = 20;

        $vehiculo = new ConduceLegalidadVehiculo([
            'marca' => 'Honda',
            'linea' => 'Cargo',
            'tipo' => 'Motocicleta',
            'placas' => 'ABC123',
            'retencion_vehiculo' => true,
            'corralon' => 'Barandillas',
        ]);
        $vehiculo->setRelation('infraccion', null);
        $vehiculo->setRelation('gruaRelacion', null);
        $vehiculo->setRelation('corralonRelacion', null);

        $persona = new ConduceLegalidadPersona(['nombre' => 'Persona conductora']);
        $persona->setRelation('infraccion', null);

        $captura->setRelation('creador', null);
        $captura->setRelation('unidad', null);
        $captura->setRelation('delegacion', null);
        $captura->setRelation('infraccion', null);
        $captura->setRelation('fundamentos', new Collection());
        $captura->setRelation('vehiculos', new Collection([$vehiculo]));
        $captura->setRelation('personas', new Collection([$persona]));
        $captura->setRelation('fotos', new Collection());

        return [$operativo, $captura];
    }

    private function invocarNotificacion(
        ConduceLegalidadOperativo $operativo,
        ConduceLegalidadCaptura $captura,
        WhatsAppCloudService $whatsApp,
        IphPuestaDisposicionDocxService $docx
    ): array {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'notificarBarandillasWhatsApp');
        $method->setAccessible(true);

        return $method->invoke(
            new ConduceLegalidadController(),
            $operativo,
            $captura,
            null,
            $whatsApp,
            $docx
        );
    }
}
