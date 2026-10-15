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
    public function test_envia_boleta_e_iph_a_barandillas_cuando_hay_vehiculo_remitido(): void
    {
        config()->set('services.whatsapp.conduce_legalidad.barandillas_enabled', true);
        config()->set('services.whatsapp.conduce_legalidad.barandillas_to', '5214433163728');
        config()->set('services.whatsapp.conduce_legalidad.barandillas_boleta_template', 'aviso_barandillas_conduce_v1');
        config()->set('services.whatsapp.conduce_legalidad.barandillas_iph_template', 'iph_barandillas_conduce_v1');

        [$operativo, $captura] = $this->capturaConVehiculo(true);
        $iphPath = tempnam(sys_get_temp_dir(), 'iph_barandillas_test_');
        file_put_contents($iphPath, 'documento de prueba');

        $whatsApp = Mockery::mock(WhatsAppCloudService::class);
        $whatsApp->shouldReceive('uploadMedia')->twice()->andReturn(
            ['ok' => true, 'body' => ['id' => 'media-boleta']],
            ['ok' => true, 'body' => ['id' => 'media-iph']]
        );
        $whatsApp->shouldReceive('sendDocumentTemplate')
            ->twice()
            ->withArgs(fn ($to) => $to === '5214433163728')
            ->andReturn(['ok' => true]);

        $docx = Mockery::mock(IphPuestaDisposicionDocxService::class);
        $docx->shouldReceive('generarConduceLegalidadBarandillas')
            ->once()
            ->andReturn([$iphPath, 'iph_barandillas_CL_10_20.docx']);

        $resultado = $this->invocarNotificacion($operativo, $captura, $whatsApp, $docx);

        $this->assertTrue($resultado['ok']);
        $this->assertTrue($resultado['enviado']);
        $this->assertTrue($resultado['data']['boleta_enviada']);
        $this->assertTrue($resultado['data']['iph_enviado']);
        $this->assertSame('3728', $resultado['data']['telefono_terminacion']);
        $this->assertFileDoesNotExist($iphPath);
    }

    public function test_no_avisa_a_barandillas_si_no_hay_vehiculo_remitido(): void
    {
        config()->set('services.whatsapp.conduce_legalidad.barandillas_enabled', true);

        [$operativo, $captura] = $this->capturaConVehiculo(false);
        $whatsApp = Mockery::mock(WhatsAppCloudService::class);
        $whatsApp->shouldNotReceive('uploadMedia');
        $docx = Mockery::mock(IphPuestaDisposicionDocxService::class);
        $docx->shouldNotReceive('generarConduceLegalidadBarandillas');

        $resultado = $this->invocarNotificacion($operativo, $captura, $whatsApp, $docx);

        $this->assertTrue($resultado['ok']);
        $this->assertFalse($resultado['enviado']);
    }

    private function capturaConVehiculo(bool $remitido): array
    {
        $operativo = new ConduceLegalidadOperativo([
            'municipio' => 'Morelia',
            'lugar' => 'Avenida Madero',
            'tipo_operativo' => 'conduce_legalidad',
        ]);
        $operativo->id = 10;
        $operativo->setRelation('creador', null);

        $captura = new ConduceLegalidadCaptura([
            'municipio' => 'Morelia',
            'lugar' => 'Avenida Madero',
            'fecha' => '2026-09-29',
            'hora' => '18:30',
            'fundamento_legal' => 'Artículo 402.',
            'agente_nombre' => 'Elemento de prueba',
        ]);
        $captura->id = 20;

        $vehiculo = new ConduceLegalidadVehiculo([
            'marca' => 'Honda',
            'linea' => 'Cargo',
            'tipo' => 'Motocicleta',
            'placas' => 'ABC123',
            'retencion_vehiculo' => $remitido,
            'corralon' => $remitido ? 'Barandillas' : null,
        ]);
        $vehiculo->setRelation('infraccion', null);
        $vehiculo->setRelation('gruaRelacion', null);
        $vehiculo->setRelation('corralonRelacion', null);

        $persona = new ConduceLegalidadPersona(['nombre' => 'Persona de prueba']);
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
