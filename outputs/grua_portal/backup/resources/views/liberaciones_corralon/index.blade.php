@extends(($portal ?? false) ? 'layouts.grua' : 'adminlte::page')

@section('title', 'Vehiculos en Corralon')

@section('content_header')
    <h1>Vehiculos en corralon</h1>
    <p>Listado de unidades actualmente registradas a resguardo.</p>
@stop

@section('content')
    @if(!($portal ?? false) && session('success'))
        <div class="alert alert-success">{{ session('success') }}</div>
    @endif

    @if(!($portal ?? false) && $errors->any())
        <div class="alert alert-danger">
            @foreach($errors->all() as $error)
                <div>{{ $error }}</div>
            @endforeach
        </div>
    @endif

    <div class="{{ ($portal ?? false) ? 'panel' : 'card card-outline card-primary' }}">
        <div class="{{ ($portal ?? false) ? 'panel-body' : 'card-body' }}">
            <form method="GET" action="{{ ($portal ?? false) ? route('grua.corralon.index') : route('liberaciones_corralon.index') }}" class="mb-3">
                <div class="row">
                    <div class="col-md-{{ ($portal ?? false) ? '9' : '6' }} mb-2">
                        <input
                            type="text"
                            name="q"
                            value="{{ $busqueda ?? '' }}"
                            class="form-control"
                            placeholder="Buscar por placas, serie, marca o inventario">
                    </div>

                    @if(!($portal ?? false))
                        <div class="col-md-4 mb-2">
                            <select name="grua_id" class="form-control">
                                <option value="">Todas las gruas</option>
                                @foreach($gruas as $grua)
                                    <option value="{{ $grua->id }}" {{ (string)($gruaId ?? '') === (string)$grua->id ? 'selected' : '' }}>
                                        {{ $grua->nombre }}
                                    </option>
                                @endforeach
                            </select>
                        </div>
                    @endif

                    <div class="col-md-2 mb-2">
                        <button type="submit" class="btn btn-primary btn-block">Buscar</button>
                    </div>
                </div>
            </form>

            @if($vehiculos->count())
                <div class="{{ ($portal ?? false) ? 'table-wrap' : 'table-responsive' }}">
                    <table class="{{ ($portal ?? false) ? '' : 'table table-striped table-bordered table-hover table-sm' }}">
                        <thead>
                            <tr>
                                <th>Placas</th>
                                <th>Vehiculo</th>
                                <th>Grua</th>
                                <th>Corralon</th>
                                <th>Inventario</th>
                                <th>Fecha</th>
                                <th>Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach($vehiculos as $vehiculo)
                                @php
                                    $nombreGrua = $vehiculo->gruaAsignada->nombre
                                        ?? optional(optional($vehiculo->servicio)->grua)->nombre
                                        ?? $vehiculo->grua
                                        ?? 'N/A';

                                    if (($portal ?? false) && $gruaUsuario && $gruaUsuario->grua) {
                                        $nombreGrua = $gruaUsuario->grua->nombre;
                                    } elseif (!($portal ?? false) && !empty($gruaId)) {
                                        $nombreGrua = optional($gruas->firstWhere('id', (int) $gruaId))->nombre ?? $nombreGrua;
                                    }
                                @endphp
                                <tr>
                                    <td>{{ $vehiculo->placas ?: 'S/P' }}</td>
                                    <td>
                                        <strong>{{ $vehiculo->marca }} {{ $vehiculo->linea }}</strong><br>
                                        <span class="muted">{{ $vehiculo->tipo }} · Serie: {{ $vehiculo->serie ?: 'N/A' }}</span>
                                    </td>
                                    <td>{{ $nombreGrua }}</td>
                                    <td>{{ $vehiculo->corralon && !in_array(strtoupper(trim($vehiculo->corralon)), ['N/A', 'NA']) ? $vehiculo->corralon : 'Servicio registrado' }}</td>
                                    <td>{{ $vehiculo->numero_inventario_grua ?: 'N/A' }}</td>
                                    <td>{{ $vehiculo->fecha_inventario_grua ?: optional(optional($vehiculo->servicio)->created_at)->format('Y-m-d H:i') ?: optional($vehiculo->updated_at)->format('Y-m-d H:i') }}</td>
                                    <td>
                                        <a
                                            class="btn btn-primary btn-sm"
                                            href="{{ ($portal ?? false) ? route('grua.corralon.show', $vehiculo) : route('liberaciones_corralon.show', $vehiculo) }}">
                                            Ver / entregar
                                        </a>
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>

                <div class="{{ ($portal ?? false) ? 'pager' : 'mt-3' }}">
                    {{ $vehiculos->links() }}
                </div>
            @else
                <div class="empty">
                    No hay vehiculos activos en corralon para esta grua.
                </div>
            @endif
        </div>
    </div>
@stop
