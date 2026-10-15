<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GruaUsuario;
use App\Services\LocationTrackingEligibilityService;
use App\Services\LicenciaPuntosTurnoAccessService;
use App\Support\HechoAccess;
use App\Support\MapaPatrullasAccess;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\URL;
use Illuminate\Validation\ValidationException;
use Spatie\Permission\PermissionRegistrar;

class AuthController extends Controller
{
    public function __construct()
    {
        $this->middleware('throttle:login')->only('login');
    }

    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required'],
        ]);

        $credentials['email'] = mb_strtolower(trim((string) $credentials['email']));

        if (Auth::attempt($credentials)) {
            $user = Auth::user();
            $token = $user->createToken('mobile')->plainTextToken;

            return response()->json($this->buildAuthResponse($user, $token));
        }

        $gruaUsuario = GruaUsuario::query()
            ->whereRaw('LOWER(TRIM(email)) = ?', [$credentials['email']])
            ->where('activo', true)
            ->first();

        if (!$gruaUsuario || !Hash::check($credentials['password'], $gruaUsuario->password)) {
            return response()->json(['message' => 'Credenciales incorrectas'], 401);
        }

        $token = $gruaUsuario->createToken('mobile-grua', ['grua'])->plainTextToken;

        return response()->json($this->buildGruaAuthResponse($gruaUsuario, $token));
    }

    public function me(Request $request)
    {
        $user = $request->user();

        return response()->json($user instanceof GruaUsuario
            ? $this->buildGruaAuthResponse($user)
            : $this->buildAuthResponse($user));
    }

    public function profile(Request $request)
    {
        $user = $request->user();

        return response()->json($user instanceof GruaUsuario
            ? $this->buildGruaAuthResponse($user)
            : $this->buildAuthResponse($user));
    }

    public function changePassword(Request $request)
    {
        $validated = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
        ]);

        $user = $request->user();

        if (!Hash::check($validated['current_password'], $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['La contraseña actual no coincide.'],
            ]);
        }

        if (Hash::check($validated['password'], $user->password)) {
            throw ValidationException::withMessages([
                'password' => ['La nueva contraseña debe ser diferente a la actual.'],
            ]);
        }

        $user->forceFill([
            'password' => Hash::make($validated['password']),
        ])->save();

        return response()->json([
            'message' => 'Contraseña actualizada correctamente.',
        ]);
    }

    public function permissions(Request $request)
    {
        $user = $request->user();

        if ($user instanceof GruaUsuario) {
            return response()->json(['ver portal grua']);
        }

        app(PermissionRegistrar::class)->forgetCachedPermissions();

        return response()->json($this->permissionsForUser($user));
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Sesión cerrada']);
    }

    private function buildAuthResponse($user, ?string $token = null): array
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $user->loadMissing([
            'unidad',
            'delegacion',
            'destacamento',
            'turno',
            'patrulla',
            'personal.fotoPrincipal',
            'roles.permissions',
            'permissions',
        ]);

        $primaryRole = $this->primaryRoleForUser($user);
        $assignedRoles = $user->roles->values();
        $permissions = $this->permissionsForUser($user)->values();
        $rolesMeta = $assignedRoles->map(fn ($role) => [
            'id' => $role->id,
            'name' => $role->name,
        ])->values()->all();
        $unidadMeta = $user->unidad ? [
            'id' => $user->unidad->id,
            'nombre' => $user->unidad->nombre,
            'slug' => $user->unidad->slug,
        ] : null;
        $unidadesMeta = $unidadMeta ? [$unidadMeta] : [];
        $delegacionMeta = $user->delegacion ? [
            'id' => $user->delegacion->id,
            'nombre' => $user->delegacion->nombre,
            'lat' => $user->delegacion->lat,
            'lng' => $user->delegacion->lng,
        ] : null;
        $destacamentoMeta = $user->destacamento ? [
            'id' => $user->destacamento->id,
            'nombre' => $user->destacamento->nombre,
            'lat' => $user->destacamento->lat,
            'lng' => $user->destacamento->lng,
        ] : null;
        $turnoMeta = $user->turno ? [
            'id' => $user->turno->id,
            'nombre' => $user->turno->nombre,
        ] : null;
        $patrullaMeta = $user->patrulla ? [
            'id' => $user->patrulla->id,
            'numero_economico' => $user->patrulla->numero_economico,
        ] : null;
        $fotoPersonalUrl = $this->fotoPersonalUrl($user->personal);

        $isSubdirector = $this->userHasRole($user, 'Subdirector');
        $isJefeGrupo = MapaPatrullasAccess::isSiniestrosGroupLead($user);
        $locationTracking = app(LocationTrackingEligibilityService::class)
            ->statusForUser($user);
        $licenciasPuntosTurno = app(LicenciaPuntosTurnoAccessService::class)
            ->statusForUser($user);

        $legacyUser = $user->toArray();
        unset($legacyUser['personal']);
        $legacyUser['role'] = $primaryRole ? $primaryRole->name : null;
        $legacyUser['role_id'] = $primaryRole ? $primaryRole->id : null;
        $legacyUser['permissions'] = $permissions->all();
        $legacyUser['location_tracking'] = $locationTracking;
        $legacyUser['location_tracking_allowed'] = (bool)($locationTracking['allowed'] ?? false);
        $legacyUser['licencias_puntos_turno'] = $licenciasPuntosTurno;
        $legacyUser['licencias_puntos_turno_permitido'] = (bool)($licenciasPuntosTurno['allowed'] ?? false);
        $legacyUser['turno_en_servicio'] = $licenciasPuntosTurno['turno_en_servicio'] ?? null;
        $legacyUser['foto_personal_url'] = $fotoPersonalUrl;

        $response = [
            // Duplicate the most-used identity keys at the root for older clients.
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'telefono' => $user->telefono,
            'area' => $user->area,
            'estado' => $user->estado,
            'unidad_id' => $user->unidad_id,
            'delegacion_id' => $user->delegacion_id,
            'destacamento_id' => $user->destacamento_id,
            'turno_id' => $user->turno_id,
            'patrulla_id' => $user->patrulla_id,
            'compartir_ubicacion' => (int) ($user->compartir_ubicacion ?? 0),
            'receive_waze_alerts' => (bool) ($user->receive_waze_alerts ?? true),
            'location_tracking' => $locationTracking,
            'location_tracking_allowed' => (bool)($locationTracking['allowed'] ?? false),
            'licencias_puntos_turno' => $licenciasPuntosTurno,
            'licencias_puntos_turno_permitido' => (bool)($licenciasPuntosTurno['allowed'] ?? false),
            'foto_personal_url' => $fotoPersonalUrl,
            // Keep the legacy string shape so existing clients don't hide modules.
            'role' => $primaryRole ? $primaryRole->name : null,
            'role_id' => $primaryRole ? $primaryRole->id : null,
            'role_meta' => $primaryRole ? [
                'id' => $primaryRole->id,
                'name' => $primaryRole->name,
            ] : null,
            'roles' => $rolesMeta,
            'permissions' => $permissions->all(),
            'unidad' => $unidadMeta,
            'unidades' => $unidadesMeta,
            'delegacion' => $delegacionMeta,
            'destacamento' => $destacamentoMeta,
            'turno' => $turnoMeta,
            'patrulla' => $patrullaMeta,
            'flags' => [
                'is_subdirector' => $isSubdirector,
                'is_jefe_grupo' => $isJefeGrupo,
                'can_receive_disconnected_alerts' => false,
            ],
            'user' => $legacyUser,
            'user_meta' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'telefono' => $user->telefono,
                'area' => $user->area,
                'estado' => $user->estado,
                'unidad_id' => $user->unidad_id,
                'delegacion_id' => $user->delegacion_id,
                'destacamento_id' => $user->destacamento_id,
                'turno_id' => $user->turno_id,
                'patrulla_id' => $user->patrulla_id,
                'compartir_ubicacion' => (int) ($user->compartir_ubicacion ?? 0),
                'location_tracking' => $locationTracking,
                'location_tracking_allowed' => (bool)($locationTracking['allowed'] ?? false),
                'licencias_puntos_turno' => $licenciasPuntosTurno,
                'licencias_puntos_turno_permitido' => (bool)($licenciasPuntosTurno['allowed'] ?? false),
                'turno_en_servicio' => $licenciasPuntosTurno['turno_en_servicio'] ?? null,
                'foto_personal_url' => $fotoPersonalUrl,
                'role' => $primaryRole ? $primaryRole->name : null,
                'role_id' => $primaryRole ? $primaryRole->id : null,
                'role_meta' => $primaryRole ? [
                    'id' => $primaryRole->id,
                    'name' => $primaryRole->name,
                ] : null,
                'roles' => $rolesMeta,
                'permissions' => $permissions->all(),
                'unidad' => $unidadMeta,
                'unidades' => $unidadesMeta,
                'delegacion' => $delegacionMeta,
                'destacamento' => $destacamentoMeta,
                'turno' => $turnoMeta,
                'patrulla' => $patrullaMeta,
            ],
        ];

        if ($token !== null && trim($token) !== '') {
            $response['token'] = $token;
        }

        return $response;
    }

    private function buildGruaAuthResponse(GruaUsuario $user, ?string $token = null): array
    {
        $user->loadMissing('grua');

        $grua = $user->grua ? [
            'id' => $user->grua->id,
            'nombre' => $user->grua->nombre,
        ] : null;

        $legacyUser = [
            'id' => $user->id,
            'name' => $user->nombre,
            'nombre' => $user->nombre,
            'email' => $user->email,
            'telefono' => $user->telefono,
            'estado' => 'ACTIVO',
            'account_type' => 'grua',
            'grua_id' => $user->grua_id,
            'grua' => $grua,
            'role' => 'GRUA',
            'role_id' => null,
            'roles' => [['id' => null, 'name' => 'GRUA']],
            'permissions' => ['ver portal grua'],
        ];

        $response = array_merge($legacyUser, [
            'permissions' => ['ver portal grua'],
            'user' => $legacyUser,
            'user_meta' => $legacyUser,
        ]);

        if ($token !== null && trim($token) !== '') {
            $response['token'] = $token;
        }

        return $response;
    }

    private function fotoPersonalUrl($personal): ?string
    {
        if (!$personal) {
            return null;
        }

        $foto = $personal->fotoPrincipal;
        if ($foto && $foto->id && $foto->ruta) {
            return URL::temporarySignedRoute(
                'personal.fotos.signed',
                now()->addMinutes(30),
                ['foto' => $foto->id]
            );
        }

        if ($personal->foto) {
            return URL::temporarySignedRoute(
                'personal.fotos.principal.signed',
                now()->addMinutes(30),
                ['personal' => $personal->id]
            );
        }

        return null;
    }

    private function permissionsForUser($user)
    {
        $user->loadMissing(['roles.permissions', 'permissions']);

        $permissions = $user->roles
            ->flatMap(fn ($role) => $role->permissions->pluck('name'))
            ->merge($user->permissions->pluck('name'))
            ->unique(function ($permission) {
                return mb_strtolower(trim((string) $permission), 'UTF-8');
            })
            ->values();

        return HechoAccess::filterPermissionsForUser($permissions, $user);
    }

    private function primaryRoleForUser($user)
    {
        $user->loadMissing('roles');

        return $user->roles->first();
    }

    private function userHasRole($user, string $roleName): bool
    {
        $user->loadMissing('roles');

        return $user->roles->contains(fn ($role) => $role->name === $roleName);
    }
}
