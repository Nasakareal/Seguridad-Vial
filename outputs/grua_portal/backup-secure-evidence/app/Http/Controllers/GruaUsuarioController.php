<?php

namespace App\Http\Controllers;

use App\Models\Grua;
use App\Models\GruaUsuario;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class GruaUsuarioController extends Controller
{
    public function index()
    {
        $usuarios = GruaUsuario::with('grua')
            ->orderBy('nombre')
            ->get();

        return view('admin.settings.grua_usuarios.index', compact('usuarios'));
    }

    public function create()
    {
        $gruas = Grua::orderBy('nombre')->get();

        return view('admin.settings.grua_usuarios.create', compact('gruas'));
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'grua_id' => 'required|exists:gruas,id',
            'nombre' => 'required|string|max:255',
            'telefono' => 'nullable|string|max:30',
            'email' => 'required|email|max:255|unique:grua_usuarios,email',
            'password' => 'required|string|min:6|confirmed',
            'activo' => 'nullable|boolean',
        ]);

        $validated['telefono'] = $this->normalizarTelefonoMx($validated['telefono'] ?? null);
        $validated['password'] = Hash::make($validated['password']);
        $validated['activo'] = $request->boolean('activo');

        GruaUsuario::create($validated);

        return redirect()
            ->route('grua_usuarios.index')
            ->with('success', 'Usuario de grúa creado correctamente.');
    }

    public function edit(GruaUsuario $gruaUsuario)
    {
        $gruas = Grua::orderBy('nombre')->get();

        return view('admin.settings.grua_usuarios.edit', compact('gruaUsuario', 'gruas'));
    }

    public function update(Request $request, GruaUsuario $gruaUsuario)
    {
        $validated = $request->validate([
            'grua_id' => 'required|exists:gruas,id',
            'nombre' => 'required|string|max:255',
            'telefono' => 'nullable|string|max:30',
            'email' => [
                'required',
                'email',
                'max:255',
                Rule::unique('grua_usuarios', 'email')->ignore($gruaUsuario->id),
            ],
            'password' => 'nullable|string|min:6|confirmed',
            'activo' => 'nullable|boolean',
        ]);

        $validated['telefono'] = $this->normalizarTelefonoMx($validated['telefono'] ?? null);
        $validated['activo'] = $request->boolean('activo');

        if (!empty($validated['password'])) {
            $validated['password'] = Hash::make($validated['password']);
        } else {
            unset($validated['password']);
        }

        $gruaUsuario->update($validated);

        return redirect()
            ->route('grua_usuarios.index')
            ->with('success', 'Usuario de grúa actualizado correctamente.');
    }

    public function destroy(GruaUsuario $gruaUsuario)
    {
        $gruaUsuario->delete();

        return redirect()
            ->route('grua_usuarios.index')
            ->with('success', 'Usuario de grúa eliminado correctamente.');
    }

    private function normalizarTelefonoMx(?string $telefono): ?string
    {
        if (is_null($telefono) || trim($telefono) === '') {
            return null;
        }

        $telefono = preg_replace('/\D+/', '', $telefono);

        if ($telefono === '') {
            return null;
        }

        if (strlen($telefono) === 10) {
            return '521' . $telefono;
        }

        if (strlen($telefono) === 12 && str_starts_with($telefono, '52')) {
            return '521' . substr($telefono, 2);
        }

        if (strlen($telefono) === 13 && str_starts_with($telefono, '521')) {
            return $telefono;
        }

        return $telefono;
    }
}
