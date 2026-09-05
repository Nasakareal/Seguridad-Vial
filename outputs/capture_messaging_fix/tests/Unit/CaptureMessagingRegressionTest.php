<?php

namespace Tests\Unit;

use App\Models\User;
use App\Services\ComunicacionConversationAccess;
use App\Services\ComunicacionPushService;
use App\Services\HechoDuplicateGuard;
use App\Services\PushService;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class CaptureMessagingRegressionTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:']);
        DB::purge('sqlite');
        Schema::create('users', function (Blueprint $t) {
            $t->id(); $t->string('name'); $t->string('estado'); $t->integer('unidad_id')->nullable();
            $t->string('nombres')->nullable(); $t->string('apellido_paterno')->nullable();
            $t->string('apellido_materno')->nullable();
            $t->integer('turno_id')->nullable();
        });
        foreach (['unidades', 'turnos'] as $table) {
            Schema::create($table, function (Blueprint $t) { $t->id(); $t->string('nombre'); });
        }
        Schema::create('roles', function (Blueprint $t) {
            $t->id(); $t->string('name'); $t->string('guard_name')->default('web');
        });
        Schema::create('model_has_roles', function (Blueprint $t) {
            $t->integer('role_id'); $t->string('model_type'); $t->integer('model_id');
        });
        Schema::create('comunicaciones', function (Blueprint $t) {
            $t->id(); $t->integer('remitente_user_id'); $t->integer('destinatario_user_id');
            $t->string('tipo'); $t->string('alcance'); $t->string('contenido')->nullable();
            $t->string('asunto')->nullable();
        });
        Schema::create('comunicacion_destinatarios', function (Blueprint $t) {
            $t->id(); $t->integer('comunicacion_id'); $t->integer('user_id');
            $t->timestamp('leido_at')->nullable(); $t->timestamp('enterado_at')->nullable(); $t->timestamps();
        });
        Schema::create('comunicacion_adjuntos', function (Blueprint $t) {
            $t->id(); $t->integer('comunicacion_id'); $t->integer('orden')->default(0);
        });
        Schema::create('device_tokens', function (Blueprint $t) {
            $t->id(); $t->integer('user_id'); $t->string('token');
        });
        DB::table('users')->insert([
            ['id' => 1, 'name' => 'Admin', 'estado' => 'Activo', 'unidad_id' => 1],
            ['id' => 2, 'name' => 'Policia', 'estado' => 'Activo', 'unidad_id' => 2],
            ['id' => 3, 'name' => 'Otra unidad', 'estado' => 'Activo', 'unidad_id' => 3],
        ]);
        DB::table('roles')->insert(['id' => 1, 'name' => 'Superadmin']);
        DB::table('model_has_roles')->insert(['role_id' => 1, 'model_type' => User::class, 'model_id' => 1]);
    }

    private function incoming(): void
    {
        DB::table('comunicaciones')->insert([
            'id' => 10, 'remitente_user_id' => 1, 'destinatario_user_id' => 2,
            'tipo' => 'mensaje', 'alcance' => 'usuario', 'contenido' => 'Mensaje de prueba',
        ]);
    }

    public function test_recipient_can_reply_to_incoming_superadmin_but_not_unrelated_users(): void
    {
        $actor = User::findOrFail(2);
        $this->assertFalse(ComunicacionConversationAccess::recipients($actor, false)->whereKey(1)->exists());
        $this->incoming();
        $this->assertTrue(ComunicacionConversationAccess::recipients($actor, false)->whereKey(1)->exists());
        $this->assertFalse(ComunicacionConversationAccess::recipients($actor, false)->whereKey(3)->exists());
        DB::table('users')->where('id', 1)->update(['estado' => 'Inactivo']);
        $this->assertFalse(ComunicacionConversationAccess::recipients($actor, false)->whereKey(1)->exists());
    }

    public function test_push_targets_only_recipients_and_contains_chat_navigation(): void
    {
        $this->incoming();
        DB::table('comunicacion_destinatarios')->insert(['comunicacion_id' => 10, 'user_id' => 2]);
        DB::table('device_tokens')->insert([
            ['user_id' => 1, 'token' => 'sender'], ['user_id' => 2, 'token' => 'recipient'],
            ['user_id' => 3, 'token' => 'unrelated'],
        ]);
        $push = \Mockery::mock(PushService::class);
        $push->shouldReceive('sendToTokens')->once()->withArgs(function ($tokens, $title, $body, $data) {
            return $tokens === ['recipient'] && $data['comunicacion_id'] === '10'
                && $data['remitente_user_id'] === '1' && $data['modulo'] === 'comunicaciones';
        })->andReturn(true);
        $this->app->instance(PushService::class, $push);
        (new ComunicacionPushService())->send(10);
    }

    public function test_incoming_superadmin_conversation_opens_and_marks_only_recipient_read(): void
    {
        $this->incoming();
        DB::table('comunicacion_destinatarios')->insert(['comunicacion_id' => 10, 'user_id' => 2]);
        $request = \Illuminate\Http\Request::create('/comunicaciones/conversacion/1');
        $request->setUserResolver(fn () => User::findOrFail(2));
        $response = (new \App\Http\Controllers\Api\ComunicacionController())->conversacion($request, User::findOrFail(1));
        $data = $response->getData(true);
        $this->assertSame(200, $response->getStatusCode());
        $this->assertSame(1, $data['usuario']['id']);
        $this->assertCount(1, $data['mensajes']);
        $this->assertNotNull(DB::table('comunicacion_destinatarios')->where('user_id', 2)->value('leido_at'));
    }

    public function test_communication_push_has_audible_android_and_apple_options(): void
    {
        $options = PushService::platformOptions(['modulo' => 'comunicaciones', 'comunicacion_id' => '10']);
        $this->assertSame('comunicaciones_v3', $options['android']['notification']['channel_id']);
        $this->assertSame('message_received', $options['android']['notification']['sound']);
        $this->assertSame('default', $options['apns']['payload']['aps']['sound']);
        $this->assertSame([], PushService::platformOptions(['modulo' => 'hechos']));
    }

    public function test_reusing_a_submitted_uuid_with_other_data_never_overwrites_old_hecho(): void
    {
        Schema::create('hechos', function (Blueprint $t) {
            $t->id(); $t->string('client_uuid')->unique();
            $t->string('submission_fingerprint')->nullable()->unique(); $t->string('calle');
        });
        DB::table('hechos')->insert([
            'id' => 99, 'client_uuid' => '11111111-1111-4111-a111-111111111111',
            'submission_fingerprint' => str_repeat('a', 64), 'calle' => 'HECHO VIEJO',
        ]);
        $request = \Illuminate\Http\Request::create('/hechos', 'POST', [
            'client_uuid' => '11111111-1111-4111-a111-111111111111', 'calle' => 'OTRO EVENTO',
        ]);
        $request->setUserResolver(fn () => User::findOrFail(2));
        $response = (new \App\Http\Controllers\Api\HechoController())->store($request);
        $this->assertSame(409, $response->getStatusCode());
        $this->assertSame('HECHO VIEJO', DB::table('hechos')->where('id', 99)->value('calle'));
        $this->assertSame(1, DB::table('hechos')->count());
        DB::table('hechos')->where('id', 99)->update(['submission_fingerprint' => null]);
        $legacyResponse = (new \App\Http\Controllers\Api\HechoController())->store($request);
        $this->assertSame(409, $legacyResponse->getStatusCode());
        $this->assertSame('HECHO VIEJO', DB::table('hechos')->where('id', 99)->value('calle'));
    }

    public function test_same_event_retries_match_but_other_dates_places_photos_and_owners_do_not(): void
    {
        $guard = new HechoDuplicateGuard();
        $payload = ['fecha' => '2026-09-04', 'calle' => 'MORELOS', 'municipio' => 'MORELIA'];
        $hash = $guard->fingerprint(2, $payload, ['photo']);
        $this->assertSame($hash, $guard->fingerprint(2, $payload + ['client_uuid' => 'new-id', 'hora' => '12:50'], ['photo']));
        foreach ([['fecha' => '2026-09-05'], ['calle' => 'OTRA CALLE']] as $change) {
            $this->assertNotSame($hash, $guard->fingerprint(2, array_merge($payload, $change), ['photo']));
        }
        $this->assertNotSame($hash, $guard->fingerprint(3, $payload, ['photo']));
        $this->assertNotSame($hash, $guard->fingerprint(2, $payload, ['another-photo']));
        $this->assertNotSame(
            $guard->fingerprint(2, $payload + ['hora' => '08:00'], []),
            $guard->fingerprint(2, $payload + ['hora' => '12:00'], [])
        );
    }
}
