@extends('adminlte::page')

@section('title', 'Editar Usuario de Grúa')

@section('content_header')
    <h1>Editar Usuario de Grúa</h1>
@stop

@section('content')
<div class="row">
    <div class="col-md-12">
        <div class="card card-outline card-dark">
            <div class="card-header">
                <h3 class="card-title">Actualizar Datos</h3>
            </div>

            <div class="card-body">
                <form action="{{ route('grua_usuarios.update', $gruaUsuario->id) }}" method="POST">
                    @csrf
                    @method('PUT')

                    <div class="row">

                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Nombre</label>
                                <input type="text" name="nombre"
                                       class="form-control @error('nombre') is-invalid @enderror"
                                       value="{{ old('nombre', $gruaUsuario->nombre) }}" required>

                                @error('nombre')
                                    <span class="invalid-feedback">{{ $message }}</span>
                                @enderror
                            </div>
                        </div>

                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Email *</label>
                                <input type="email" name="email"
                                       class="form-control @error('email') is-invalid @enderror"
                                       value="{{ old('email', $gruaUsuario->email) }}" required>

                                @error('email')
                                    <span class="invalid-feedback">{{ $message }}</span>
                                @enderror
                            </div>
                        </div>

                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Teléfono</label>
                                <input type="text" name="telefono"
                                       class="form-control @error('telefono') is-invalid @enderror"
                                       value="{{ old('telefono', $gruaUsuario->telefono) }}">

                                @error('telefono')
                                    <span class="invalid-feedback">{{ $message }}</span>
                                @enderror
                            </div>
                        </div>

                    </div>

                    <div class="row">

                        <div class="col-md-6">
                            <div class="form-group">
                                <label>Grúa</label>
                                <select name="grua_id"
                                        class="form-control @error('grua_id') is-invalid @enderror"
                                        required>

                                    <option value="">Seleccione una grúa</option>

                                    @foreach ($gruas as $grua)
                                        <option value="{{ $grua->id }}"
                                            {{ old('grua_id', $gruaUsuario->grua_id) == $grua->id ? 'selected' : '' }}>
                                            {{ $grua->nombre }}
                                        </option>
                                    @endforeach

                                </select>

                                @error('grua_id')
                                    <span class="invalid-feedback">{{ $message }}</span>
                                @enderror
                            </div>
                        </div>

                        <div class="col-md-3">
                            <div class="form-group">
                                <label>Nueva Contraseña</label>
                                <input type="password" name="password"
                                       class="form-control @error('password') is-invalid @enderror"
                                       placeholder="Opcional">

                                @error('password')
                                    <span class="invalid-feedback">{{ $message }}</span>
                                @enderror
                            </div>
                        </div>

                        <div class="col-md-3">
                            <div class="form-group">
                                <label>Confirmar</label>
                                <input type="password" name="password_confirmation"
                                       class="form-control"
                                       placeholder="Repetir contraseña">
                            </div>
                        </div>

                    </div>

                    <div class="row">

                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Estado</label>
                                <select name="activo" class="form-control">
                                    <option value="1" {{ old('activo', $gruaUsuario->activo) == 1 ? 'selected' : '' }}>
                                        ACTIVO
                                    </option>
                                    <option value="0" {{ old('activo', $gruaUsuario->activo) == 0 ? 'selected' : '' }}>
                                        INACTIVO
                                    </option>
                                </select>
                            </div>
                        </div>

                    </div>

                    <hr>

                    <div class="form-group">
                        <button class="btn btn-primary">
                            <i class="fa-solid fa-check"></i> Actualizar
                        </button>

                        <a href="{{ route('grua_usuarios.index') }}" class="btn btn-secondary">
                            Cancelar
                        </a>
                    </div>

                </form>
            </div>
        </div>
    </div>
</div>
@stop

@section('css')
<style>
.form-group label {
    font-weight: bold;
}
</style>
@stop

@section('js')
<script>
@if ($errors->any())
    Swal.fire({
        icon: 'error',
        title: 'Errores en el formulario',
        html: `
            <ul style="text-align:left;">
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        `,
        confirmButtonText: 'Aceptar'
    });
@endif
</script>
@stop
