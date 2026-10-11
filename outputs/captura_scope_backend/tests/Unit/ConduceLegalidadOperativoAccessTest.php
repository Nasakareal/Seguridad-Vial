<?php

namespace Tests\Unit;

use App\Http\Controllers\Api\ConduceLegalidadController;
use App\Models\ConduceLegalidadCaptura;
use App\Models\ConduceLegalidadOperativo;
use Carbon\CarbonImmutable;
use ReflectionMethod;
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

    public function test_operatives_are_visible_only_in_same_unit_and_delegation(): void
    {
        $operativo = new ConduceLegalidadOperativo();
        $operativo->forceFill([
            'unidad_id' => 2,
            'delegacion_id' => 15,
        ]);
        $operativo->setRelation('creador', null);

        $this->assertTrue($this->canView($this->user('Delegado', 2, 15), $operativo));
        $this->assertFalse($this->canView($this->user('Delegado', 2, 16), $operativo));
        $this->assertFalse($this->canView($this->user('Responsable de Turno', 5), $operativo));
        $this->assertTrue($this->canView($this->user('Superadmin', 5), $operativo));
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

    private function canReactivate($user): bool
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'canReactivateOperativo');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $user);
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
