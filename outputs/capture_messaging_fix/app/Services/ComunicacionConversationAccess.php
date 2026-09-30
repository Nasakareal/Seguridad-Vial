<?php

namespace App\Services;

use App\Models\User;

class ComunicacionConversationAccess
{
    /**
     * Users the actor may discover to start a new direct conversation.
     */
    public static function discoverableRecipients(User $actor, bool $global)
    {
        $query = User::query()
            ->visibleFor($actor)
            ->where('estado', 'Activo')
            ->where('users.id', '!=', $actor->id);

        if (!$global) {
            $actor->unidad_id
                ? $query->where('unidad_id', $actor->unidad_id)
                : $query->whereRaw('1 = 0');
        }

        return $query;
    }

    /**
     * Users the actor may message. Existing direct conversations remain
     * replyable even when the other participant is outside the directory.
     */
    public static function messageableRecipients(User $actor, bool $global)
    {
        $discoverable = self::discoverableRecipients($actor, $global)
            ->select('users.id');

        return User::query()->where('estado', 'Activo')
            ->where('users.id', '!=', $actor->id)
            ->where(function ($query) use ($discoverable, $actor) {
                $query->whereIn('users.id', $discoverable)
                    ->orWhereExists(function ($conversation) use ($actor) {
                        $conversation->selectRaw('1')
                            ->from('comunicaciones')
                            ->where('comunicaciones.tipo', 'mensaje')
                            ->where('comunicaciones.alcance', 'usuario')
                            ->where(function ($participants) use ($actor) {
                                $participants
                                    ->where(function ($incoming) use ($actor) {
                                        $incoming
                                            ->whereColumn('comunicaciones.remitente_user_id', 'users.id')
                                            ->where('comunicaciones.destinatario_user_id', $actor->id);
                                    })
                                    ->orWhere(function ($outgoing) use ($actor) {
                                        $outgoing
                                            ->where('comunicaciones.remitente_user_id', $actor->id)
                                            ->whereColumn('comunicaciones.destinatario_user_id', 'users.id');
                                    });
                            });
                    });
            });
    }
}
