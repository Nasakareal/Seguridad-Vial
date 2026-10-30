<?php

namespace Tests\Unit;

use App\Http\Controllers\Api\ConduceLegalidadController;
use App\Models\ConduceLegalidadCaptura;
use App\Models\ConduceLegalidadOperativo;
use App\Models\ConduceLegalidadVehiculo;
use App\Models\Grua;
use Carbon\CarbonImmutable;
use ReflectionMethod;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tests\TestCase;

class ConduceLegalidadOperativoAccessTest extends TestCase
{
    public function test_delegaciones_delegate_can_create_operatives(): void
    {
        $this->assertTrue($this->canCreate($this->user('Delegado')));
    }

    public function test_delegaciones_police_cannot_create_operatives(): void
    {
        $this->assertFalse($this->canCreate($this->user('Policia')));
    }

    public function test_low_vialidades_roles_cannot_create_even_with_permission(): void
    {
        foreach (['Agente Vial', 'Fenix', 'Fénix', 'Motociclista'] as $role) {
            $user = $this->user($role, 5, null, 10, ['crear conduce legalidad']);
            $this->assertFalse($this->canCreate($user), $role);
        }
    }

    public function test_only_authorized_vialidades_roles_can_create(): void
    {
        foreach ([
            'Responsable de Turno',
            'RT',
            'Subdirector',
            'Administrador',
            'Administrativo',
        ] as $role) {
            $this->assertTrue(
                $this->canCreate($this->user($role, 5, null)),
                $role
            );
        }
    }

    public function test_only_superadmin_can_create_globally_outside_vialidades(): void
    {
        $this->assertFalse(
            $this->canCreate($this->user('Administrador', 1, null))
        );
        $this->assertTrue(
            $this->canCreate($this->user('Superadmin', 1, null))
        );
    }

    public function test_only_superadmin_can_reactivate_operatives(): void
    {
        $this->assertTrue($this->canReactivate($this->user('Superadmin')));
        $this->assertFalse($this->canReactivate($this->user('Administrador')));
    }

    public function test_only_user_id_one_can_put_operatives_in_standby(): void
    {
        $this->assertTrue($this->canDeleteOperativo($this->user('Superadmin', 1, null, 1)));
        $this->assertFalse($this->canDeleteOperativo($this->user('Superadmin', 1, null, 2)));
        $this->assertFalse($this->canDeleteOperativo($this->user('Administrador', 1, null, 3)));
    }

    public function test_standby_cannot_bypass_the_password_endpoint_through_update(): void
    {
        try {
            $this->assertStandbyTransition('activo', 'standby');
            $this->fail('The direct standby transition should have been rejected.');
        } catch (HttpException $exception) {
            $this->assertSame(422, $exception->getStatusCode());
        }

        $this->assertStandbyTransition('standby', 'standby');
        $this->addToAssertionCount(1);
    }

    public function test_low_vialidades_role_cannot_manage_other_users_captures(): void
    {
        $user = $this->user('Agente Vial', 5, null, 10);
        $own = new ConduceLegalidadCaptura(['created_by' => 10]);
        $other = new ConduceLegalidadCaptura(['created_by' => 11]);

        $this->assertFalse($this->canManage($user));
        $this->assertTrue($this->canEditCaptura($user, $own));
        $this->assertFalse($this->canEditCaptura($user, $other));
        $this->assertArrayHasKey('fecha', $this->scheduleRules($user));
        $this->assertArrayHasKey('hora_inicio', $this->scheduleRules($user));
    }

    public function test_high_vialidades_role_can_edit_other_users_captures(): void
    {
        $user = $this->user('Responsable de Turno', 5, null, 10);
        $other = new ConduceLegalidadCaptura(['created_by' => 11]);

        $this->assertTrue($this->canManage($user));
        $this->assertTrue($this->canEditCaptura($user, $other));
    }

    public function test_schedule_fields_are_removed_from_delegate_validation(): void
    {
        $delegateRules = $this->scheduleRules($this->user('Delegado'));
        $administratorRules = $this->scheduleRules($this->user('Administrador'));

        $this->assertArrayNotHasKey('fecha', $delegateRules);
        $this->assertArrayNotHasKey('hora_inicio', $delegateRules);
        $this->assertArrayHasKey('fecha', $administratorRules);
        $this->assertArrayHasKey('hora_inicio', $administratorRules);
    }

    public function test_only_superadmin_receives_scope_validation_rules(): void
    {
        $delegateRules = $this->scheduleRules($this->user('Delegado'));
        $administratorRules = $this->scheduleRules($this->user('Administrador'));
        $superadminRules = $this->scheduleRules($this->user('Superadmin'));

        $this->assertArrayNotHasKey('unidad_id', $delegateRules);
        $this->assertArrayNotHasKey('delegacion_id', $delegateRules);
        $this->assertArrayNotHasKey('unidad_id', $administratorRules);
        $this->assertArrayHasKey('unidad_id', $superadminRules);
        $this->assertArrayHasKey('delegacion_id', $superadminRules);
    }

    public function test_delegate_schedule_ignores_client_date_and_time(): void
    {
        $now = CarbonImmutable::parse('2026-07-30 18:45:10');

        $schedule = $this->resolveSchedule(
            $this->user('Delegado'),
            ['fecha' => '2020-01-02', 'hora_inicio' => '01:02'],
            $now
        );

        $this->assertSame('2026-07-30', $schedule['fecha']);
        $this->assertSame('18:45:10', $schedule['hora_inicio']);
    }

    public function test_administrator_schedule_accepts_client_date_and_time(): void
    {
        $now = CarbonImmutable::parse('2026-07-30 18:45:10');

        $schedule = $this->resolveSchedule(
            $this->user('Administrador'),
            ['fecha' => '2026-08-01', 'hora_inicio' => '07:30'],
            $now
        );

        $this->assertSame('2026-08-01', $schedule['fecha']);
        $this->assertSame('07:30', $schedule['hora_inicio']);
    }

    public function test_delegaciones_operatives_are_visible_across_delegations(): void
    {
        $operativo = new ConduceLegalidadOperativo();
        $operativo->forceFill([
            'unidad_id' => 2,
            'delegacion_id' => 15,
        ]);
        $operativo->setRelation('creador', null);

        $this->assertTrue($this->canView($this->user('Delegado', 2, 15), $operativo));
        $this->assertTrue($this->canView($this->user('Delegado', 2, 16), $operativo));
        $this->assertTrue($this->canView($this->user('Subdirector', 2, 16), $operativo));
        $this->assertFalse($this->canView($this->user('Responsable de Turno', 5), $operativo));
        $this->assertTrue($this->canView($this->user('Superadmin', 5), $operativo));
    }

    public function test_delegation_roles_can_feed_active_operatives_across_delegations(): void
    {
        $own = new ConduceLegalidadOperativo();
        $own->forceFill([
            'unidad_id' => 2,
            'delegacion_id' => 15,
            'estado' => 'activo',
            'tipo_operativo' => 'conduce_legalidad',
        ]);
        $own->setRelation('creador', null);

        $other = new ConduceLegalidadOperativo();
        $other->forceFill([
            'unidad_id' => 2,
            'delegacion_id' => 16,
            'estado' => 'activo',
            'tipo_operativo' => 'conduce_legalidad',
        ]);
        $other->setRelation('creador', null);

        foreach (['Delegado', 'Policia', 'Administrativo', 'Subdirector'] as $role) {
            $user = $this->user($role, 2, 15);

            $this->assertTrue($this->canView($user, $own), $role);
            $this->assertTrue($this->canFeed($user, $own), $role);
            $this->assertTrue($this->canView($user, $other), $role);
            $this->assertTrue($this->canFeed($user, $other), $role);
        }
    }

    public function test_support_from_another_delegation_keeps_operational_delegation(): void
    {
        $operativo = new ConduceLegalidadOperativo();
        $operativo->forceFill([
            'unidad_id' => 2,
            'delegacion_id' => 15,
            'estado' => 'activo',
            'tipo_operativo' => 'conduce_legalidad',
        ]);
        $operativo->setRelation('creador', null);
        $supportUser = $this->user('Policia', 2, 16);

        $this->assertTrue($this->canView($supportUser, $operativo));
        $this->assertTrue($this->canFeed($supportUser, $operativo));

        $scope = $this->resolveCaptureScope($operativo, $supportUser);
        $this->assertSame(2, $scope['unidad_id']);
        $this->assertSame(15, $scope['delegacion_id']);
    }

    public function test_all_units_can_support_any_active_conduce_operativo(): void
    {
        $operativo = new ConduceLegalidadOperativo();
        $operativo->forceFill([
            'unidad_id' => 2,
            'delegacion_id' => 15,
            'estado' => 'activo',
            'tipo_operativo' => 'conduce_legalidad',
        ]);
        $operativo->setRelation('creador', null);

        foreach ([
            $this->user('Policia', 1, null),
            $this->user('Policia', 2, 16),
            $this->user('Administrativo', 3, null),
            $this->user('Responsable de Turno', 5, null),
            $this->user('Instructor', 6, null),
        ] as $supportUser) {
            $this->assertTrue($this->canView($supportUser, $operativo));
            $this->assertTrue($this->canFeed($supportUser, $operativo));
        }
    }

    public function test_cross_unit_support_does_not_open_closed_or_alcoholimetria_operatives(): void
    {
        $supportUser = $this->user('Responsable de Turno', 5, null);

        foreach ([
            ['estado' => 'cerrado', 'tipo_operativo' => 'conduce_legalidad'],
            ['estado' => 'activo', 'tipo_operativo' => 'alcoholimetria'],
        ] as $data) {
            $operativo = new ConduceLegalidadOperativo();
            $operativo->forceFill([
                'unidad_id' => 2,
                'delegacion_id' => 15,
                ...$data,
            ]);
            $operativo->setRelation('creador', null);

            $this->assertFalse($this->canView($supportUser, $operativo));
        }
    }

    public function test_delegate_sees_all_captures_only_for_operatives_in_own_delegation(): void
    {
        $delegate = $this->user('Delegado', 2, 15);

        $own = new ConduceLegalidadOperativo();
        $own->forceFill(['unidad_id' => 2, 'delegacion_id' => 15]);

        $other = new ConduceLegalidadOperativo();
        $other->forceFill(['unidad_id' => 2, 'delegacion_id' => 16]);

        $this->assertTrue($this->canViewAllCaptures($delegate, $own));
        $this->assertFalse($this->canViewAllCaptures($delegate, $other));
        $this->assertFalse(
            $this->canViewAllCaptures($this->user('Policia', 2, 15), $own)
        );
    }

    public function test_vehicle_payload_exposes_corralon_address_and_phone_not_internal_id_as_number(): void
    {
        $vehiculo = new ConduceLegalidadVehiculo([
            'corralon_id' => 101,
            'corralon' => 'TRANSITO MUNICIPAL URUAPAN',
        ]);
        $vehiculo->setRelation('corralonRelacion', new Grua([
            'nombre' => 'TRANSITO MUNICIPAL URUAPAN',
            'direccion' => 'DIRECCION ADMINISTRATIVA',
            'ubicacion_corralon' => 'LIBRAMIENTO ORIENTE 450, URUAPAN',
            'telefono' => '4521234567',
        ]));

        $method = new ReflectionMethod(ConduceLegalidadController::class, 'vehiculoPayload');
        $method->setAccessible(true);
        $payload = $method->invoke(new ConduceLegalidadController(), $vehiculo);

        $this->assertSame('LIBRAMIENTO ORIENTE 450, URUAPAN', $payload['corralon_direccion']);
        $this->assertSame('4521234567', $payload['corralon_telefono']);
        $this->assertSame(101, $payload['corralon_id']);
        $this->assertArrayNotHasKey('numero_corralon', $payload);
    }

    public function test_superadmin_can_view_and_feed_operatives_from_any_delegation(): void
    {
        foreach ([15, 16] as $delegacionId) {
            $operativo = new ConduceLegalidadOperativo();
            $operativo->forceFill([
                'unidad_id' => 2,
                'delegacion_id' => $delegacionId,
                'estado' => 'activo',
                'tipo_operativo' => 'conduce_legalidad',
            ]);
            $operativo->setRelation('creador', null);

            $superadmin = $this->user('Superadmin', 5, null);
            $this->assertTrue($this->canView($superadmin, $operativo));
            $this->assertTrue($this->canFeed($superadmin, $operativo));
        }
    }

    public function test_fomento_can_view_and_feed_active_vialidades_operatives_as_support(): void
    {
        $operativo = new ConduceLegalidadOperativo();
        $operativo->forceFill([
            'unidad_id' => 5,
            'delegacion_id' => null,
            'estado' => 'activo',
            'tipo_operativo' => 'conduce_legalidad',
        ]);
        $operativo->setRelation('creador', null);
        $fomento = $this->user('Instructor', 6, null);

        $this->assertTrue($this->canView($fomento, $operativo));
        $this->assertTrue($this->canFeed($fomento, $operativo));

        $scope = $this->resolveCaptureScope($operativo, $fomento);
        $this->assertSame(5, $scope['unidad_id']);
        $this->assertNull($scope['delegacion_id']);
    }

    public function test_fomento_support_opens_active_conduce_operatives_from_other_units(): void
    {
        $fomento = $this->user('Instructor', 6, null);

        foreach ([1, 2, 3] as $unidadId) {
            $operativo = new ConduceLegalidadOperativo();
            $operativo->forceFill([
                'unidad_id' => $unidadId,
                'delegacion_id' => $unidadId === 2 ? 15 : null,
                'estado' => 'activo',
                'tipo_operativo' => 'conduce_legalidad',
            ]);
            $operativo->setRelation('creador', null);

            $this->assertTrue($this->canView($fomento, $operativo));
            $this->assertTrue($this->canFeed($fomento, $operativo));
        }
    }

    public function test_fomento_support_does_not_open_vialidades_alcoholimetria(): void
    {
        $operativo = new ConduceLegalidadOperativo();
        $operativo->forceFill([
            'unidad_id' => 5,
            'delegacion_id' => null,
            'estado' => 'activo',
            'tipo_operativo' => 'alcoholimetria',
        ]);
        $operativo->setRelation('creador', null);

        $this->assertFalse($this->canView($this->user('Instructor', 6, null), $operativo));
    }

    public function test_operativo_list_scope_includes_global_active_conduce_and_own_unit(): void
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'scopeOperativos');
        $method->setAccessible(true);
        $query = ConduceLegalidadOperativo::query();

        $method->invoke(new ConduceLegalidadController(), $query, $this->user('Instructor', 6, null));

        $this->assertSame(['activo', 'conduce_legalidad', 6, 6], $query->getBindings());
    }

    public function test_superadmin_can_assign_delegaciones_scope(): void
    {
        $scope = $this->resolveScope(
            $this->user('Superadmin', 5, null),
            ['unidad_id' => 2, 'delegacion_id' => 23]
        );

        $this->assertSame(2, $scope['unidad_id']);
        $this->assertSame(23, $scope['delegacion_id']);
    }

    public function test_delegation_is_cleared_when_superadmin_assigns_another_unit(): void
    {
        $scope = $this->resolveScope(
            $this->user('Superadmin', 2, 15),
            ['unidad_id' => 5, 'delegacion_id' => 15]
        );

        $this->assertSame(5, $scope['unidad_id']);
        $this->assertNull($scope['delegacion_id']);
    }

    public function test_non_superadmin_scope_is_taken_from_session_and_payload_is_ignored(): void
    {
        $scope = $this->resolveScope(
            $this->user('Delegado', 2, 15),
            ['unidad_id' => 5, 'delegacion_id' => 99]
        );

        $this->assertSame(2, $scope['unidad_id']);
        $this->assertSame(15, $scope['delegacion_id']);
    }

    public function test_non_delegaciones_scope_clears_delegation_from_session(): void
    {
        $scope = $this->resolveScope(
            $this->user('Responsable de Turno', 5, 15),
            []
        );

        $this->assertSame(5, $scope['unidad_id']);
        $this->assertNull($scope['delegacion_id']);
    }

    public function test_non_superadmin_edit_preserves_existing_scope(): void
    {
        $operativo = new ConduceLegalidadOperativo();
        $operativo->forceFill(['unidad_id' => 5, 'delegacion_id' => null]);

        $scope = $this->resolveScope(
            $this->user('Administrador', 3, null),
            ['unidad_id' => 2, 'delegacion_id' => 15],
            $operativo
        );

        $this->assertSame(5, $scope['unidad_id']);
        $this->assertNull($scope['delegacion_id']);
    }

    public function test_capture_inherits_operational_unit_instead_of_actor_unit(): void
    {
        $operativo = new ConduceLegalidadOperativo();
        $operativo->forceFill(['unidad_id' => 5, 'delegacion_id' => null]);

        $scope = $this->resolveCaptureScope(
            $operativo,
            $this->user('Administrador', 1, null)
        );

        $this->assertSame(5, $scope['unidad_id']);
        $this->assertNull($scope['delegacion_id']);
    }

    public function test_capture_inherits_operational_delegation(): void
    {
        $operativo = new ConduceLegalidadOperativo();
        $operativo->forceFill(['unidad_id' => 2, 'delegacion_id' => 15]);

        $scope = $this->resolveCaptureScope(
            $operativo,
            $this->user('Superadmin', 1, null)
        );

        $this->assertSame(2, $scope['unidad_id']);
        $this->assertSame(15, $scope['delegacion_id']);
    }

    private function scheduleRules($user): array
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'operativoRulesForUser');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $user);
    }

    private function resolveSchedule($user, array $validated, CarbonImmutable $now): array
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'resolveOperativoSchedule');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $user, $validated, $now);
    }

    private function resolveScope(
        $user,
        array $validated,
        ?ConduceLegalidadOperativo $operativo = null
    ): array {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'resolveOperativoScope');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $user, $validated, $operativo);
    }

    private function resolveCaptureScope(ConduceLegalidadOperativo $operativo, $user): array
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'adscripcionCaptura');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $operativo, $user);
    }

    private function canView($user, ConduceLegalidadOperativo $operativo): bool
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'canViewOperativo');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $user, $operativo);
    }

    private function canCreate($user): bool
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'canCreateOperativo');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $user);
    }

    private function canFeed($user, ConduceLegalidadOperativo $operativo): bool
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'puedeAlimentarOperativo');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $operativo, $user);
    }

    private function canReactivate($user): bool
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'canReactivateOperativo');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $user);
    }

    private function canDeleteOperativo($user): bool
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'canDeleteOperativo');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $user);
    }

    private function assertStandbyTransition(?string $oldEstado, string $requestedEstado): void
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'assertStandbyUsesProtectedEndpoint');
        $method->setAccessible(true);
        $method->invoke(new ConduceLegalidadController(), $oldEstado, $requestedEstado);
    }

    private function canManage($user): bool
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'canManage');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $user);
    }

    private function canEditCaptura($user, ConduceLegalidadCaptura $captura): bool
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'canEditCaptura');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $user, $captura);
    }

    private function canViewAllCaptures($user, ConduceLegalidadOperativo $operativo): bool
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'isDelegateOfOperativo');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $user, $operativo);
    }

    private function user(string $role, int $unidadId = 2, ?int $delegacionId = 15, int $id = 1, array $permissions = [])
    {
        return new class ($role, $unidadId, $delegacionId, $id, $permissions) {
            public int $id;
            public int $unidad_id;
            public ?int $delegacion_id;
            public object $unidad;
            private string $role;
            private array $permissions;

            public function __construct(string $role, int $unidadId, ?int $delegacionId, int $id, array $permissions)
            {
                $this->id = $id;
                $this->role = $role;
                $this->permissions = $permissions;
                $this->unidad_id = $unidadId;
                $this->delegacion_id = $delegacionId;
                $this->unidad = (object) ['slug' => $unidadId === 2 ? 'delegaciones' : 'otra'];
            }

            public function hasRole(string $role): bool
            {
                return $this->role === $role;
            }

            public function hasAnyRole(array $roles): bool
            {
                return in_array($this->role, $roles, true);
            }

            public function can(string $permission): bool
            {
                return in_array($permission, $this->permissions, true);
            }
        };
    }
}
