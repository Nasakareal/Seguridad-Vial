<?php

namespace Tests\Unit;

use App\Http\Controllers\Api\ConduceLegalidadController;
use App\Models\ConduceLegalidadCaptura;
use App\Models\ConduceLegalidadOperativo;
use App\Models\Delegacion;
use App\Models\User;
use ReflectionMethod;
use Tests\TestCase;

class ConduceLegalidadTicketSupervisorTest extends TestCase
{
    public function test_delegaciones_ticket_uses_delegate_from_specific_delegation(): void
    {
        $controller = $this->controllerWithDelegate();
        $lines = $this->appendSupervisor($controller, 2, 6);

        $this->assertContains('Supervisión operativa: Ángel Peralta Hernández', $lines);
        $this->assertContains('Delegado de la Delegación de Pátzcuaro', $lines);
        $this->assertNotContains('Supervisión operativa: Luis Eduardo Lugo Ordorica', $lines);
        $this->assertCoordinatorPrecedesSupervisor(
            $lines,
            'Supervisión operativa: Ángel Peralta Hernández'
        );
    }

    public function test_vialidades_ticket_keeps_subdirector_signature(): void
    {
        $controller = $this->controllerWithDelegate();
        $lines = $this->appendSupervisor($controller, 5, null);

        $this->assertContains('Supervisión operativa: Luis Eduardo Lugo Ordorica', $lines);
        $this->assertContains('Subdirector de la Unidad de Protección en Vialidades Urbanas', $lines);
        $this->assertCoordinatorPrecedesSupervisor(
            $lines,
            'Supervisión operativa: Luis Eduardo Lugo Ordorica'
        );
    }

    public function test_supervisor_payload_uses_delegate_from_specific_delegation(): void
    {
        $controller = $this->controllerWithDelegate();
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'supervisorTicket');
        $method->setAccessible(true);

        $supervisor = $method->invoke($controller, 2, 6);

        $this->assertSame('Ángel Peralta Hernández', $supervisor['nombre']);
        $this->assertSame('Delegado de la Delegación de Pátzcuaro', $supervisor['cargo']);
        $this->assertStringNotContainsString('Lugo', $supervisor['nombre']);
    }

    public function test_ticket_uses_operativo_scope_before_sharing_user_or_capture(): void
    {
        $operativo = new ConduceLegalidadOperativo();
        $operativo->forceFill([
            'unidad_id' => 2,
            'delegacion_id' => 6,
        ]);
        $captura = new ConduceLegalidadCaptura();
        $captura->forceFill([
            'unidad_id' => 5,
            'delegacion_id' => null,
        ]);
        $sharingUser = (object) [
            'unidad_id' => 5,
            'delegacion_id' => null,
        ];

        $method = new ReflectionMethod(ConduceLegalidadController::class, 'adscripcionTicket');
        $method->setAccessible(true);
        $scope = $method->invoke(
            new ConduceLegalidadController(),
            $operativo,
            $sharingUser,
            $captura
        );

        $this->assertSame(2, $scope['unidad_id']);
        $this->assertSame(6, $scope['delegacion_id']);
    }

    public function test_legacy_prevention_name_prints_as_operativo_de_alcoholimetria(): void
    {
        $operativo = new ConduceLegalidadOperativo();
        $operativo->forceFill([
            'tipo_operativo' => null,
            'nombre' => 'Operativo de Prevención de Accidentes',
            'objetivo' => null,
        ]);

        $method = new ReflectionMethod(
            ConduceLegalidadController::class,
            'nombreTicketOperativo'
        );
        $method->setAccessible(true);
        $nombre = $method->invoke(new ConduceLegalidadController(), $operativo);

        $this->assertSame('Operativo de Alcoholimetría', $nombre);
        $this->assertStringNotContainsString('Prevención', $nombre);
    }

    public function test_delegation_reference_exposes_its_full_address_for_tickets(): void
    {
        $delegacion = new Delegacion();
        $delegacion->forceFill([
            'id' => 6,
            'nombre' => 'Pátzcuaro',
            'direccion_completa' => 'Av. Lázaro Cárdenas 120, Centro, Pátzcuaro, Mich.',
        ]);

        $method = new ReflectionMethod(
            ConduceLegalidadController::class,
            'refPayload'
        );
        $method->setAccessible(true);
        $payload = $method->invoke(
            new ConduceLegalidadController(),
            $delegacion
        );

        $this->assertSame(6, $payload['id']);
        $this->assertSame('Pátzcuaro', $payload['nombre']);
        $this->assertSame($delegacion->direccion_completa, $payload['direccion_completa']);
    }

    private function appendSupervisor(
        ConduceLegalidadController $controller,
        int $unidadId,
        ?int $delegacionId
    ): array {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'appendSupervisorTicket');
        $method->setAccessible(true);
        $lines = [];
        $arguments = [&$lines, $unidadId, $delegacionId];
        $method->invokeArgs($controller, $arguments);

        return $lines;
    }

    private function assertCoordinatorPrecedesSupervisor(
        array $lines,
        string $supervisorLine
    ): void {
        $cargoIndex = array_search(
            'Coordinador del Agrupamiento de Seguridad Vial',
            $lines,
            true
        );
        $nombreIndex = array_search(
            'Lic. Luis Roberto Rosiles Soberanis',
            $lines,
            true
        );
        $supervisorIndex = array_search($supervisorLine, $lines, true);

        $this->assertIsInt($cargoIndex);
        $this->assertIsInt($nombreIndex);
        $this->assertIsInt($supervisorIndex);
        $this->assertContains('RESPONSABLES DEL OPERATIVO:', $lines);
        $this->assertLessThan($nombreIndex, $cargoIndex);
        $this->assertLessThan($supervisorIndex, $nombreIndex);
    }

    private function controllerWithDelegate(): ConduceLegalidadController
    {
        return new class extends ConduceLegalidadController {
            protected function delegadoSupervisor(int $delegacionId): ?User
            {
                if ($delegacionId !== 6) {
                    return null;
                }

                $user = new User();
                $user->forceFill(['name' => 'Ángel Peralta Hernández']);

                return $user;
            }

            protected function nombreDelegacionTicket(int $delegacionId): ?string
            {
                return $delegacionId === 6 ? 'Pátzcuaro' : null;
            }
        };
    }
}
