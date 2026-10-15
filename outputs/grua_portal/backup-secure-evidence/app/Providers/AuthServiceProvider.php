<?php

namespace App\Providers;

use App\Models\GruaUsuario;
use App\Services\FomentoCulturaVialDetalleManager;
use App\Support\HechoAccess;
use Illuminate\Foundation\Support\Providers\AuthServiceProvider as ServiceProvider;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class AuthServiceProvider extends ServiceProvider
{
    protected $policies = [
    ];

    public function boot()
    {
        $this->registerPolicies();

        Gate::before(function ($user, $ability) {
            if ($user instanceof GruaUsuario) {
                return $this->normalizeAbility($ability) === 'ver portal grua';
            }

            if ($user->hasRole('Superadmin')) {
                return true;
            }

            if ($this->isLicenciaPuntosAbility($ability)) {
                return $this->resolveLicenciaPuntosAbility($user, $ability);
            }

            if ($this->isOficiosAbility($ability) && !empty($user->unidad_id)) {
                return true;
            }

            if (
                in_array($this->normalizeAbility($ability), ['ver actividades', 'crear actividades'], true)
                && (
                    $this->isMotociclistaVialidadesUser($user)
                    || $this->isEvaluadorTeoricoSiniestrosUser($user)
                )
            ) {
                return true;
            }

            if ($this->isSeguridadVialUser($user)) {
                if ($ability === 'crear usuarios') {
                    return true;
                }

                if ($this->isReadAbility($ability)) {
                    return true;
                }

                if ($this->isWriteAbility($ability)) {
                    return false;
                }
            }

            if (HechoAccess::shouldResolvePermissionDirectly($ability)) {
                if (!HechoAccess::canUseHechosModule($user)) {
                    return false;
                }

                return HechoAccess::hasAssignedPermission($user, $ability);
            }

            $carreterasAbilities = [
                'ver operativos carreteras',
                'crear operativos carreteras',
                'editar operativos carreteras',
                'eliminar operativos carreteras',
                'ver estadisticas carreteras',
            ];

            if (in_array($ability, $carreterasAbilities, true)) {
                $carreterasCapturaRoles = ['Agente Upec', 'Agente UPEC'];
                $carreterasRevisionRoles = ['RT', 'Encargado de Destacamento'];
                $carreterasGestionRoles = ['Administrador', 'Subdirector', 'Administrativo'];
                $carreterasTodosRoles = array_merge(
                    $carreterasGestionRoles,
                    $carreterasCapturaRoles,
                    $carreterasRevisionRoles
                );

                $unidadId = (int) ($user->unidad_id ?? 0);
                $tieneRolExclusivoCarreteras = $user->hasAnyRole(array_merge($carreterasCapturaRoles, $carreterasRevisionRoles));
                $unidadOk = $user->perteneceAUnidad('carreteras')
                    || in_array($unidadId, [3, 4], true)
                    || $tieneRolExclusivoCarreteras;

                if (!$unidadOk) {
                    return false;
                }

                if (
                    $ability === 'ver operativos carreteras'
                    && $user->hasAnyRole($carreterasTodosRoles)
                ) {
                    return true;
                }

                if (
                    $ability === 'crear operativos carreteras'
                    && $user->hasAnyRole(array_merge(['Administrador'], $carreterasCapturaRoles))
                ) {
                    return true;
                }

                if (
                    in_array($ability, ['editar operativos carreteras', 'ver estadisticas carreteras'], true)
                    && $user->hasAnyRole(array_merge($carreterasGestionRoles, $carreterasRevisionRoles))
                ) {
                    return true;
                }

                if (
                    $ability === 'eliminar operativos carreteras'
                    && $user->hasRole('Administrador')
                ) {
                    return true;
                }
            }

            $vialidadesAbilities = [
                'ver operativos vialidades',
                'crear operativos vialidades',
                'editar operativos vialidades',
                'eliminar operativos vialidades',
                'ver estadisticas actividades',
            ];

            if (in_array($ability, $vialidadesAbilities, true)) {
                $unidadId = (int) ($user->unidad_id ?? 0);
                $unidadOk = $user->perteneceAUnidad('vialidades-urbanas')
                    || in_array($unidadId, [3, 5], true);

                if (!$unidadOk) {
                    return false;
                }

                if (in_array($ability, ['ver operativos vialidades', 'ver estadisticas actividades'], true)) {
                    return true;
                }

                if ($ability === 'crear operativos vialidades') {
                    return $user->hasAnyRole(['Agente Vial', 'Responsable de Turno', 'Administrador', 'Subdirector', 'Administrativo']);
                }

                if ($ability === 'editar operativos vialidades') {
                    return $user->hasAnyRole(['Responsable de Turno', 'Administrador', 'Subdirector', 'Administrativo']);
                }

                if ($ability === 'eliminar operativos vialidades') {
                    return $user->hasAnyRole(['Administrador']);
                }
            }

            if (
                in_array($ability, ['ver puestas a disposicion', 'crear puestas a disposicion'], true)
                && !empty($user->unidad_id)
            ) {
                return true;
            }

            return null;
        });

        Gate::define('menu-dictamenes', function ($user) {
            return $user->can('ver dictamenes')
                && (
                    $user->perteneceAUnidad('siniestros')
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-dictamenes-crear', function ($user) {
            return $user->can('crear dictamenes')
                && $user->perteneceAUnidad('siniestros');
        });

        Gate::define('menu-puestas-disposicion', function ($user) {
            return $user->can('ver puestas a disposicion')
                || (
                    $user->can('ver dictamenes')
                    && $user->perteneceAUnidad('siniestros')
                );
        });

        Gate::define('menu-puestas-disposicion-crear', function ($user) {
            return $user->can('crear puestas a disposicion');
        });

        Gate::define('menu-delegaciones', function ($user) {
            return $user->can('ver delegaciones')
                && (
                    $user->perteneceAUnidad('delegaciones')
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-delegaciones-crear', function ($user) {
            return $user->can('crear delegaciones')
                && (
                    $user->perteneceAUnidad('delegaciones')
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-modulo-examenes', function ($user) {
            return $user->can('ver modulo examenes')
                && (
                    $user->perteneceAAlgunaUnidad(['siniestros', 'delegaciones'])
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-modulo-examenes-crear', function ($user) {
            return $user->can('crear modulo examenes')
                && (
                    $user->perteneceAAlgunaUnidad(['siniestros', 'delegaciones'])
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-estadisticas-globales', function ($user) {
            return $user->can('ver estadisticas globales')
                && (
                    $user->perteneceAUnidad('siniestros')
                    || $user->perteneceAUnidad('delegaciones')
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-estadisticas-carreteras', function ($user) {
            return $user->can('ver estadisticas carreteras')
                && (
                    $user->perteneceAUnidad('carreteras')
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-estadisticas-delegaciones', function ($user) {
            return $user->can('ver estadisticas')
                && (
                    $user->perteneceAUnidad('delegaciones')
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-estadisticas-siniestros', function ($user) {
            return (
                $user->perteneceAUnidad('siniestros')
                || (int) $user->unidad_id === 1
                || (int) $user->unidad_id === 3
            ) && (
                $user->can('ver estadisticas globales')
                || $user->can('ver estadisticas')
                || $user->can('ver estadisticas actividades')
                || $user->can('ver mapa')
            );
        });

        Gate::define('menu-estadisticas-actividades-siniestros', function ($user) {
            return $user->can('ver estadisticas actividades')
                && (
                    $user->perteneceAUnidad('siniestros')
                    || (int) $user->unidad_id === 1
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-estadisticas-actividades-delegaciones', function ($user) {
            return $user->can('ver estadisticas actividades')
                && (
                    $user->perteneceAUnidad('delegaciones')
                    || (int) $user->unidad_id === 2
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-estadisticas-actividades-fomento', function ($user) {
            return $user->can('ver estadisticas actividades')
                && (
                    $this->isFomentoCulturaVialUser($user)
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-estadisticas-actividades-vialidades', function ($user) {
            return $user->can('ver estadisticas actividades')
                && (
                    $user->perteneceAUnidad('vialidades-urbanas')
                    || (int) $user->unidad_id === 5
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-estadisticas-generales', function ($user) {
            return (
                $user->can('ver estadisticas globales')
                && (
                    $user->perteneceAUnidad('siniestros')
                    || $user->perteneceAUnidad('delegaciones')
                    || (int) $user->unidad_id === 3
                )
            ) || (
                $user->can('ver estadisticas carreteras')
                && (
                    $user->perteneceAUnidad('carreteras')
                    || (int) $user->unidad_id === 3
                )
            ) || (
                $user->can('menu-estadisticas-actividades-siniestros')
                || $user->can('menu-estadisticas-actividades-delegaciones')
                || $user->can('menu-estadisticas-actividades-fomento')
                || $user->can('menu-estadisticas-actividades-vialidades')
            );
        });

        Gate::define('menu-guardianes-camino', function ($user) {
            return $user->can('ver operativos carreteras')
                && (
                    $user->perteneceAUnidad('carreteras')
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-guardianes-camino-crear', function ($user) {
            return $user->can('crear operativos carreteras')
                && (
                    $user->perteneceAUnidad('carreteras')
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-hechos-pendientes-revision', function ($user) {
            return $user->can('ver hechos')
                && (
                    (int) $user->unidad_id === 1
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-pendientes-cortes-siniestros', function ($user) {
            return $user->can('ver hechos')
                && (
                    $user->perteneceAUnidad('siniestros')
                    || (int) $user->unidad_id === 1
                    || (int) $user->unidad_id === 3
                    || $user->hasAnyRole(['Perito', 'Jefe de Grupo'])
                );
        });

        Gate::define('menu-pendientes-cortes-delegaciones', function ($user) {
            return $user->can('ver hechos')
                && (
                    $user->perteneceAUnidad('delegaciones')
                    || (int) $user->unidad_id === 2
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-guardianes-pendientes-revision', function ($user) {
            return $user->isSuperadmin()
                || (
                    (int) $user->unidad_id === 4
                    && $user->can('editar operativos carreteras')
                    && $user->hasAnyRole(['RT', 'Encargado de Destacamento'])
                );
        });

        Gate::define('menu-vialidades-urbanas', function ($user) {
            return $user->can('ver operativos vialidades')
                && (
                    $user->perteneceAUnidad('vialidades-urbanas')
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-vialidades-urbanas-crear', function ($user) {
            return $user->can('crear operativos vialidades')
                && (
                    $user->perteneceAUnidad('vialidades-urbanas')
                    || (int) $user->unidad_id === 3
                );
        });

        Gate::define('menu-actividades', function ($user) {
            return !(
                $user->perteneceAUnidad('carreteras')
                && (int) $user->unidad_id !== 3
            );
        });


    }

    private function isSeguridadVialUser($user): bool
    {
        return (int) ($user->unidad_id ?? 0) === 3
            || optional($user->unidad)->slug === 'seguridad-vial';
    }

    private function isFomentoCulturaVialUser($user): bool
    {
        return app(FomentoCulturaVialDetalleManager::class)->usuarioEsFomento($user);
    }

    private function isMotociclistaVialidadesUser($user): bool
    {
        return (int) ($user->unidad_id ?? 0) === 5
            && $user->hasRole('Motociclista');
    }

    private function isEvaluadorTeoricoSiniestrosUser($user): bool
    {
        return (int) ($user->unidad_id ?? 0) === 1
            && $user->hasAnyRole([
                'Evaluador Teórico',
                'Evaluador Teorico',
            ]);
    }

    private function isOficiosAbility($ability): bool
    {
        return in_array($this->normalizeAbility($ability), [
            'ver oficios',
            'crear oficios',
            'editar oficios',
        ], true);
    }

    private function isLicenciaPuntosAbility($ability): bool
    {
        return in_array($this->normalizeAbility($ability), [
            'ver puntos licencias',
            'ver cursos puntos licencias',
            'crear puntos licencias',
            'registrar infracciones puntos licencias',
            'acreditar capacitacion puntos licencias',
            'ver catalogo infracciones puntos licencias',
            'crear catalogo infracciones puntos licencias',
            'editar catalogo infracciones puntos licencias',
        ], true);
    }

    private function resolveLicenciaPuntosAbility($user, $ability): bool
    {
        $ability = $this->normalizeAbility($ability);
        $tieneUnidad = !empty($user->unidad_id);
        $esFomento = $this->isFomentoCulturaVialUser($user);
        $esSeguridadVial = $this->isSeguridadVialUser($user);

        if ($ability === 'ver puntos licencias') {
            return $tieneUnidad;
        }

        if ($ability === 'ver cursos puntos licencias') {
            return $esFomento || $esSeguridadVial;
        }

        if (in_array($ability, [
            'crear puntos licencias',
            'registrar infracciones puntos licencias',
        ], true)) {
            return $tieneUnidad
                && !$esFomento
                && $this->hasAssignedPermission($user, $ability);
        }

        if ($ability === 'acreditar capacitacion puntos licencias') {
            return $tieneUnidad
                && $esFomento
                && $this->isFomentoInstructor($user)
                && $this->hasAssignedPermission($user, $ability);
        }

        if (in_array($ability, [
            'ver catalogo infracciones puntos licencias',
            'crear catalogo infracciones puntos licencias',
            'editar catalogo infracciones puntos licencias',
        ], true)) {
            return $tieneUnidad
                && !$esFomento
                && $this->hasAssignedPermission($user, $ability);
        }

        return false;
    }

    private function isFomentoInstructor($user): bool
    {
        if ($user->hasAnyRole([
            'Instructor',
        ])) {
            return true;
        }

        $personal = $user->personal;

        if (!$personal) {
            return false;
        }

        return DB::table('personal_rols as personal_rol')
            ->join('rol_servicios as rol_servicio', 'rol_servicio.id', '=', 'personal_rol.rol_servicio_id')
            ->where('personal_rol.personal_id', $personal->id)
            ->where('personal_rol.activo', true)
            ->where('rol_servicio.nombre', 'like', '%Instructor%')
            ->exists();
    }

    private function hasAssignedPermission($user, string $ability): bool
    {
        return method_exists($user, 'hasPermissionTo')
            && $user->hasPermissionTo($ability, $user->guard_name ?? 'web');
    }

    private function isReadAbility($ability): bool
    {
        $ability = $this->normalizeAbility($ability);

        return str_starts_with($ability, 'ver ');
    }

    private function isWriteAbility($ability): bool
    {
        $ability = $this->normalizeAbility($ability);

        foreach ([
            'crear ',
            'editar ',
            'eliminar ',
            'borrar ',
            'subir ',
            'gestionar ',
            'registrar ',
            'acreditar ',
            'asignar ',
            'quitar ',
            'mover ',
            'cerrar ',
            'capturar ',
            'generar ',
            'guardar ',
            'aprobar ',
            'rechazar ',
            'activar ',
            'cancelar ',
            'marcar ',
            'desmarcar ',
        ] as $prefix) {
            if (str_starts_with($ability, $prefix)) {
                return true;
            }
        }

        return false;
    }

    private function normalizeAbility($ability): string
    {
        return mb_strtolower(trim((string) $ability), 'UTF-8');
    }
}
