@extends(($portal ?? false) ? 'layouts.grua' : 'adminlte::page')

@section('title', 'Entrega de Corralon')

@section('content_header')
    <h1>Entrega de corralon</h1>
    <p>{{ $vehiculo->placas ?: 'Sin placas' }} · {{ $vehiculo->marca }} {{ $vehiculo->linea }}</p>
@stop

@section('content')
    @php
        $nombreGrua = $vehiculo->gruaAsignada->nombre
            ?? optional(optional($vehiculo->servicio)->grua)->nombre
            ?? $vehiculo->grua
            ?? 'N/A';

        if (($portal ?? false) && $gruaUsuario && $gruaUsuario->grua) {
            $nombreGrua = $gruaUsuario->grua->nombre;
        }
    @endphp

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

    <div class="{{ ($portal ?? false) ? 'panel' : 'card card-outline card-info' }} mb-3">
        <div class="{{ ($portal ?? false) ? 'panel-body' : 'card-body' }}">
            <div class="{{ ($portal ?? false) ? 'table-wrap' : 'table-responsive' }}">
                <table class="{{ ($portal ?? false) ? '' : 'table table-bordered table-sm' }}">
                    <tbody>
                        <tr>
                            <th>Vehiculo</th>
                            <td>{{ $vehiculo->marca }} {{ $vehiculo->linea }} {{ $vehiculo->modelo }}</td>
                        </tr>
                        <tr>
                            <th>Placas / serie</th>
                            <td>{{ $vehiculo->placas ?: 'S/P' }} / {{ $vehiculo->serie ?: 'N/A' }}</td>
                        </tr>
                        <tr>
                            <th>Grua</th>
                            <td>{{ $nombreGrua }}</td>
                        </tr>
                        <tr>
                            <th>Corralon</th>
                            <td>{{ $vehiculo->corralon && !in_array(strtoupper(trim($vehiculo->corralon)), ['N/A', 'NA']) ? $vehiculo->corralon : 'Servicio registrado' }}</td>
                        </tr>
                        <tr>
                            <th>Inventario</th>
                            <td>{{ $vehiculo->numero_inventario_grua ?: 'N/A' }}</td>
                        </tr>
                        <tr>
                            <th>Siniestro</th>
                            <td>
                                @forelse($vehiculo->hechos as $hecho)
                                    #{{ $hecho->id }} {{ $hecho->fecha ?? '' }} {{ $hecho->calle ?? '' }} {{ $hecho->colonia ?? '' }}<br>
                                @empty
                                    N/A
                                @endforelse
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    @if($liberacion && $liberacion->estado === 'ENTREGADO')
        <div class="{{ ($portal ?? false) ? 'panel' : 'card card-outline card-success' }}">
            <div class="{{ ($portal ?? false) ? 'panel-body' : 'card-body' }}">
                <span class="badge badge-ok">ENTREGADO</span>
                <p class="mt-2 mb-0">
                    Este vehiculo fue marcado fuera de corralon el
                    {{ $liberacion->fecha_entrega ?: $liberacion->updated_at }}.
                </p>
            </div>
        </div>
    @else
        <div class="{{ ($portal ?? false) ? 'panel' : 'card card-outline card-primary' }}">
            <div class="{{ ($portal ?? false) ? 'panel-body' : 'card-body' }}">
                <form
                    method="POST"
                    action="{{ ($portal ?? false) ? route('grua.corralon.store', $vehiculo) : route('liberaciones_corralon.store', $vehiculo) }}"
                    enctype="multipart/form-data">
                    @csrf

                    <div class="{{ ($portal ?? false) ? 'form-grid' : 'row' }}">
                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Persona que recibe</label>
                            <input type="text" name="persona_recibe" value="{{ old('persona_recibe') }}" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Identificacion</label>
                            <input type="text" name="identificacion_recibe" value="{{ old('identificacion_recibe') }}" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Telefono</label>
                            <input type="text" name="telefono_recibe" value="{{ old('telefono_recibe') }}" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Documento de liberacion</label>
                            <input type="file" name="documento_liberacion" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Foto de identificacion</label>
                            <input type="file" name="foto_identificacion" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Foto de entrega</label>
                            <input type="file" name="foto_entrega" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row full' : 'form-group col-md-12' }}">
                            <label>Observaciones</label>
                            <textarea name="observaciones" class="form-control">{{ old('observaciones') }}</textarea>
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row full' : 'form-group col-md-12' }}">
                            <label>
                                <input type="checkbox" name="confirmar_entrega" value="1">
                                Confirmo que este vehiculo ya no esta en corralon.
                            </label>
                        </div>
                    </div>

                    <div class="actions mt-3">
                        <button type="submit" class="btn btn-danger">Marcar fuera de corralon</button>
                        <a class="btn btn-ghost" href="{{ ($portal ?? false) ? route('grua.corralon.index') : route('liberaciones_corralon.index') }}">
                            Volver
                        </a>
                    </div>
                </form>
            </div>
        </div>
    @endif
@stop
