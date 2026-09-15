<?php

namespace Tests\Unit;

use App\Models\{C5iServiceResponse, Patrulla, User, WhatsAppWebGroup, WhatsAppWebMessage};
use App\Services\{C5iResponseTimeService, C5iRouteService, C5iSiniestrosRecommendationService, WhatsAppCloudService, WhatsAppSendGuard};
use Carbon\Carbon;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\{DB, Schema, Route};
use Tests\TestCase;

class C5iRouteRegressionTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:',
            'database.connections.sqlite.url' => null, 'database.connections.sqlite.foreign_key_constraints' => false,
            'services.whatsapp.c5i_response_time.enabled' => true,
            'services.whatsapp.c5i_response_time.dry_run' => true,
            'services.whatsapp.c5i_response_time.group_ids' => 'test@g.us',
            'services.whatsapp.c5i_response_time.source_author_ids' => 'source@c.us',
            'services.whatsapp.c5i_response_time.dispatch_author_ids' => 'dispatch@c.us',
            'services.whatsapp.c5i_response_time.unit_slug' => 'siniestros']);
        DB::purge('sqlite');
        Schema::create('unidades', function (Blueprint $t) { $t->id(); $t->string('slug'); });
        Schema::create('patrullas', function (Blueprint $t) {
            $t->id(); $t->integer('unidad_id'); $t->string('numero_economico'); $t->boolean('activa'); $t->timestamps();
        });
        Schema::create('users', function (Blueprint $t) {
            $t->id(); $t->integer('unidad_id'); $t->integer('patrulla_id')->nullable();
            $t->string('telefono_whatsapp_operativo')->nullable(); $t->string('telefono_whatsapp_operativo_secundario')->nullable();
        });
        Schema::create('personals', function (Blueprint $t) {
            $t->id(); $t->integer('user_id'); $t->integer('unidad_id'); $t->integer('patrulla_id')->nullable(); $t->softDeletes();
        });
        $migrations = [
            '2026_07_15_231500_create_whatsapp_web_reader_tables.php' => 'CreateWhatsappWebReaderTables',
            '2026_07_17_180000_create_c5i_service_responses_table.php' => 'CreateC5iServiceResponsesTable',
            '2026_07_20_180000_add_audio_transcription_to_c5i_response_time.php' => 'AddAudioTranscriptionToC5iResponseTime',
            '2026_09_15_180000_create_c5i_route_points_table.php' => 'CreateC5iRoutePointsTable',
        ];
        foreach ($migrations as $file => $class) {
            $staged = dirname(__DIR__, 2).'/database/migrations/'.$file;
            require_once is_file($staged) ? $staged : database_path('migrations/'.$file);
            (new $class)->up();
        }
        DB::table('unidades')->insert(['id' => 1, 'slug' => 'siniestros']);
        DB::table('patrullas')->insert([
            ['id' => 174, 'unidad_id' => 1, 'numero_economico' => '174', 'activa' => 1],
            ['id' => 256, 'unidad_id' => 1, 'numero_economico' => '256', 'activa' => 1],
        ]);
        DB::table('users')->insert(['id' => 7, 'unidad_id' => 1, 'patrulla_id' => null,
            'telefono_whatsapp_operativo' => '5214431234567']);
        DB::table('personals')->insert(['id' => 9, 'user_id' => 7, 'unidad_id' => 1, 'patrulla_id' => 174]);
        Route::get('/test-c5i/{response}', function () {})->name('c5i.responses.show');
        Route::getRoutes()->refreshNameLookups();
        Carbon::setTestNow(Carbon::parse('2026-09-15 15:00:00'));
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function service(): C5iResponseTimeService
    {
        $cloud = $this->createMock(WhatsAppCloudService::class);
        $cloud->expects($this->never())->method('sendTemplate');
        $guard = $this->createMock(WhatsAppSendGuard::class);
        return new C5iResponseTimeService(new C5iSiniestrosRecommendationService($cloud, $guard), $cloud, $guard);
    }

    private function message(string $body, string $at, string $author): WhatsAppWebMessage
    {
        $group = WhatsAppWebGroup::firstOrCreate(['whatsapp_id' => 'test@g.us']);
        return WhatsAppWebMessage::create(['whatsapp_web_group_id' => $group->id,
            'whatsapp_message_id' => bin2hex(random_bytes(8)), 'body' => $body,
            'sent_at' => Carbon::parse('2026-09-15 '.$at), 'author_whatsapp_id' => $author,
            'message_type' => 'chat', 'has_media' => false]);
    }

    private function incident(): WhatsAppWebMessage
    {
        return $this->message('98 L5 AVENIDA MORELOS LATITUD:19.7062424 LONGITUD:-101.1912914', '13:41:00', 'source@c.us');
    }

    public function test_174_arrives_from_author_personal_not_external_pm256(): void
    {
        $service = $this->service();
        $incident = $this->incident();
        $this->assertSame('incident_recorded', $service->processMessage($incident)['status']);
        $assignment = $this->message('174 al 40', '13:41:20', 'dispatch@c.us');
        $this->assertSame('assigned', $service->processMessage($assignment)['status']);
        $arrival = $this->message('Policía morelia en el lugar PM256 a cargo ulises Ramirez Alvarez', '14:05:00', '5214431234567@c.us');
        $this->assertSame('complete', $service->processMessage($arrival)['status']);
        $response = C5iServiceResponse::firstOrFail();
        $this->assertSame(174, (int) $response->patrulla_id);
        $this->assertSame($arrival->id, $response->arrival_message_id);
        $this->assertSame('14:05:00', $response->arrival_reported_at->format('H:i:s'));
        $this->assertStringContainsString('C5i → mensaje:', $response->notification_meta['template_params'][9]);
        $this->assertStringNotContainsString('permanencia', $response->notification_meta['template_params'][9]);
        $service->processMessage($incident);
        $service->processMessage($assignment);
        $service->processMessage($arrival);
        $this->assertSame('complete', $response->fresh()->status);
        $this->assertFalse($service->isArrivalMessage('R10 gracias por el K8 174'));
    }

    public function test_missing_assignment_uses_30_minutes_before_arrival(): void
    {
        $service = $this->service();
        $service->processMessage($this->incident());
        $arrival = $this->message('Policía morelia en el lugar PM256 a cargo ulises Ramirez Alvarez', '14:05:00', '5214431234567@c.us');
        $this->assertSame('complete', $service->processMessage($arrival)['status']);
        $response = C5iServiceResponse::firstOrFail();
        $this->assertNull($response->assigned_at);
        $summary = (new C5iRouteService)->summary($response);
        $this->assertTrue($summary['fallback']);
        $this->assertSame('13:35:00', Carbon::parse($summary['start'])->format('H:i:s'));
        $this->assertSame('14:05:00', Carbon::parse($summary['end'])->format('H:i:s'));
    }

    public function test_delayed_points_recover_arrival_without_replacing_current_location(): void
    {
        $service = $this->service();
        $service->processMessage($this->incident());
        $service->processMessage($this->message('174 al 40', '13:42:00', 'dispatch@c.us'));
        $service->processMessage($this->message('en el lugar PM256', '14:05:00', '5214431234567@c.us'));
        $user = User::findOrFail(7);
        $routes = new C5iRouteService;
        foreach (['13:55:00', '13:52:00', '13:52:00', '13:40:00'] as $time) {
            $location = $routes->record($user, ['lat' => 19.7062424, 'lng' => -101.1912914,
                'accuracy' => 10, 'captured_at' => '2026-09-15 '.$time, 'patrulla_id' => 174]);
            $service->processLocation($user, $location);
        }
        $response = C5iServiceResponse::firstOrFail();
        $this->assertSame('13:52:00', $response->gps_arrived_at->format('H:i:s'));
        $this->assertSame(600, $response->assignment_to_gps_seconds);
        $this->assertSame(3, DB::table('c5i_route_points')->count());
        $summary = $routes->summary($response);
        $this->assertSame(2, $summary['point_count']);
        $this->assertSame(1, $summary['gaps']);
        $this->assertCount(2, $summary['segments']);
    }

    public function test_route_excludes_other_units_and_changed_patrol(): void
    {
        $routes = new C5iRouteService;
        $user = User::findOrFail(7);
        $point = ['lat' => 19.7, 'lng' => -101.2, 'accuracy' => 8,
            'captured_at' => '2026-09-15 13:45:00', 'patrulla_id' => 256];
        $this->assertNull($routes->record($user, $point));
        $this->assertNull(DB::table('c5i_route_points')->first()->patrulla_id);
        $user->unidad_id = 2;
        $this->assertNull($routes->record($user, $point));
        $this->assertSame(1, DB::table('c5i_route_points')->count());
    }

    public function test_route_already_stored_is_used_when_message_arrives(): void
    {
        $service = $this->service();
        $service->processMessage($this->incident());
        $service->processMessage($this->message('174 al 40', '13:42:00', 'dispatch@c.us'));
        (new C5iRouteService)->record(User::findOrFail(7), [
            'lat' => 19.7062424, 'lng' => -101.1912914, 'accuracy' => 10,
            'captured_at' => '2026-09-15 13:52:00', 'patrulla_id' => 174]);
        $service->processMessage($this->message('Policía morelia en el lugar PM256 a cargo ulises Ramirez Alvarez', '14:05:00', '5214431234567@c.us'));
        $response = C5iServiceResponse::firstOrFail();
        $this->assertSame('13:52:00', $response->gps_arrived_at->format('H:i:s'));
        $this->assertStringContainsString('13:52:00', $response->notification_meta['template_params'][5]);
    }

    public function test_prefixed_economic_number_accepts_unambiguous_short_174(): void
    {
        DB::table('patrullas')->where('id', 174)->update(['numero_economico' => '22-174']);
        $service = $this->service();
        $service->processMessage($this->incident());
        $this->assertSame('assigned', $service->processMessage($this->message('174 al 40', '13:42:00', 'dispatch@c.us'))['status']);
    }

    public function test_report_view_renders_route_and_fallback_without_dwell(): void
    {
        $service = $this->service();
        $service->processMessage($this->incident());
        $service->processMessage($this->message('en el lugar PM256', '14:05:00', '5214431234567@c.us'));
        $response = C5iServiceResponse::with('patrulla')->firstOrFail();
        $routeData = (new C5iRouteService)->summary($response);
        $path = dirname(__DIR__, 2).'/resources/views/c5i/response-report.blade.php';
        $compiled = app('blade.compiler')->compileString(file_get_contents($path));
        $__env = app('view');
        ob_start();
        try { eval('?>'.$compiled); $html = ob_get_contents(); }
        finally { ob_end_clean(); }
        $this->assertStringContainsString('13:35:00', $html);
        $this->assertStringContainsString('const incident = [19.7062424,-101.1912914]', $html);
        $this->assertStringContainsString('No hay recorrido GPS guardado', $html);
        $this->assertStringNotContainsString('Permanencia', $html);
    }

    public function test_v2_uses_dynamic_route_button_instead_of_long_body_url(): void
    {
        config([
            'services.whatsapp.c5i_response_time.route_button' => true,
            'services.whatsapp.c5i_response_time.template' => 'alerta_tiempo_reaccion_siniestros_v2',
        ]);
        $service = $this->service();
        $service->processMessage($this->incident());
        $service->processMessage($this->message('174 al 40', '13:42:00', 'dispatch@c.us'));
        $service->processMessage($this->message(
            'Policía morelia en el lugar PM256 a cargo ulises Ramirez Alvarez',
            '14:05:00',
            '5214431234567@c.us'
        ));

        $response = C5iServiceResponse::firstOrFail();
        $this->assertTrue($response->notification_meta['route_button']);
        $this->assertSame((string) $response->id, $response->notification_meta['route_button_param']);
        $this->assertStringNotContainsString(
            '/c5i/tiempos/',
            $response->notification_meta['template_params'][9]
        );
    }
}
