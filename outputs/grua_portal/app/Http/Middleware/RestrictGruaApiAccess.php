<?php

namespace App\Http\Middleware;

use App\Models\GruaUsuario;
use Closure;
use Illuminate\Http\Request;

class RestrictGruaApiAccess
{
    public function handle(Request $request, Closure $next)
    {
        if (!$request->user() instanceof GruaUsuario) {
            return $next($request);
        }

        $allowed = $request->is(
            'api/grua/corralon',
            'api/grua/corralon/*',
            'api/me',
            'api/profile',
            'api/profile/password',
            'api/permissions',
            'api/logout'
        );

        abort_unless($allowed, 403, 'Esta cuenta solamente puede utilizar el portal de grúa.');

        return $next($request);
    }
}
