<?php

namespace App\Services;

use App\Models\User;

class ComunicacionConversationAccess
{
    public static function recipients(User $actor, bool $global)
    {
        $ordinary = User::query()->visibleFor($actor)->select('users.id');
        if (!$global) {
            $actor->unidad_id
                ? $ordinary->where('unidad_id', $actor->unidad_id)
                : $ordinary->whereRaw('1 = 0');
        }

        return User::query()->where('estado', 'Activo')
            ->where('users.id', '!=', $actor->id)
            ->where(function ($query) use ($ordinary, $actor) {
                $query->whereIn('users.id', $ordinary)
                    // An existing incoming direct message authorizes a reply,
                    // even if the sender is outside the recipient's directory.
                    ->orWhereExists(function ($incoming) use ($actor) {
                        $incoming->selectRaw('1')->from('comunicaciones')
                            ->whereColumn('comunicaciones.remitente_user_id', 'users.id')
                            ->where('comunicaciones.destinatario_user_id', $actor->id)
                            ->where('comunicaciones.tipo', 'mensaje')
                            ->where('comunicaciones.alcance', 'usuario');
                    });
            });
    }
}
