<?php

namespace Tests\Feature;

use App\Models\Grua;
use App\Models\GruaUsuario;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class GruaApiLoginTest extends TestCase
{
    use DatabaseTransactions;

    public function test_active_grua_user_can_login_through_mobile_api(): void
    {
        $grua = Grua::query()->first() ?: Grua::create(['nombre' => 'GRUA PRUEBA API']);
        $password = 'PruebaGrua_2026';

        $user = GruaUsuario::create([
            'grua_id' => $grua->id,
            'nombre' => 'Usuario Grua API',
            'email' => 'grua-api-' . uniqid() . '@example.test',
            'password' => Hash::make($password),
            'activo' => true,
        ]);

        $login = $this->postJson('http://localhost/api/login', [
            'email' => $user->email,
            'password' => $password,
        ]);

        $login->assertOk()
            ->assertJsonPath('account_type', 'grua')
            ->assertJsonPath('grua_id', $grua->id)
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonPath('user.role', 'GRUA')
            ->assertJsonFragment(['ver portal grua']);

        $token = (string) $login->json('token');
        $this->assertNotSame('', $token);

        $this->withToken($token)
            ->getJson('http://localhost/api/me')
            ->assertOk()
            ->assertJsonPath('account_type', 'grua')
            ->assertJsonPath('grua.id', $grua->id);

        $this->withToken($token)
            ->getJson('http://localhost/api/permissions')
            ->assertOk()
            ->assertExactJson(['ver portal grua']);

        $this->withToken($token)
            ->getJson('http://localhost/api/grua/corralon')
            ->assertOk()
            ->assertJsonPath('grua.id', $grua->id)
            ->assertJsonStructure(['items', 'meta']);

        $this->withToken($token)
            ->getJson('http://localhost/api/conduce-legalidad/operativos')
            ->assertForbidden();
    }

    public function test_inactive_grua_user_cannot_login_through_mobile_api(): void
    {
        $grua = Grua::query()->first() ?: Grua::create(['nombre' => 'GRUA PRUEBA API']);
        $password = 'PruebaGrua_2026';

        $user = GruaUsuario::create([
            'grua_id' => $grua->id,
            'nombre' => 'Usuario Grua Inactivo',
            'email' => 'grua-inactiva-' . uniqid() . '@example.test',
            'password' => Hash::make($password),
            'activo' => false,
        ]);

        $this->postJson('http://localhost/api/login', [
            'email' => $user->email,
            'password' => $password,
        ])->assertUnauthorized();
    }
}
