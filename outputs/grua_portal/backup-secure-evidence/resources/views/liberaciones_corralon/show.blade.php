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
                <div class="table-wrap mt-3">
                    <table>
                        <tbody>
                            <tr><th>Persona que recibió</th><td>{{ $liberacion->persona_recibe ?: 'N/A' }}</td></tr>
                            <tr><th>Identificación</th><td>{{ $liberacion->identificacion_recibe ?: 'N/A' }}</td></tr>
                            <tr><th>Folio SIERSE</th><td>{{ $liberacion->sierse_folio ?: 'Registro anterior sin folio' }}</td></tr>
                            <tr>
                                <th>Condición al entregar</th>
                                <td>{{ $liberacion->condicion_entrega === 'CONFORME_INVENTARIO' ? 'Conforme al inventario' : ($liberacion->condicion_entrega === 'CON_OBSERVACIONES' ? 'Con observaciones' : 'No capturada') }}</td>
                            </tr>
                            <tr><th>Observaciones</th><td>{{ $liberacion->observaciones ?: 'Sin observaciones' }}</td></tr>
                        </tbody>
                    </table>
                </div>
                <div class="actions mt-3">
                    @foreach([
                        'foto_entrega' => 'Foto de entrega',
                        'foto_identificacion' => 'Identificación',
                        'documento_liberacion' => 'Oficio de liberación',
                        'memoria_descriptiva' => 'Memoria descriptiva',
                        'comprobante_pago' => 'Comprobante de pago',
                        'firma_recibe' => 'Firma',
                    ] as $campo => $etiqueta)
                        @if($liberacion->{$campo})
                            <a class="btn btn-ghost" target="_blank" rel="noopener" href="{{ ($portal ?? false)
                                ? route('grua.corralon.evidencia', [$liberacion, $campo])
                                : route('liberaciones_corralon.evidencia', [$liberacion, $campo]) }}">
                                {{ $etiqueta }}
                            </a>
                        @endif
                    @endforeach
                </div>
            </div>
        </div>
    @else
        <div class="{{ ($portal ?? false) ? 'panel' : 'card card-outline card-primary' }}">
            <div class="{{ ($portal ?? false) ? 'panel-body' : 'card-body' }}">
                <div class="alert alert-success">
                    Este registro documenta la entrega. La memoria descriptiva oficial debe cerrarse en SIERSE y entregarse a la persona que recibe el vehículo.
                </div>
                <form
                    method="POST"
                    action="{{ ($portal ?? false) ? route('grua.corralon.store', $vehiculo) : route('liberaciones_corralon.store', $vehiculo) }}"
                    enctype="multipart/form-data">
                    @csrf

                    <div class="{{ ($portal ?? false) ? 'form-grid' : 'row' }}">
                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Persona que recibe *</label>
                            <input required type="text" name="persona_recibe" value="{{ old('persona_recibe') }}" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Tipo y folio de identificación *</label>
                            <input required type="text" name="identificacion_recibe" value="{{ old('identificacion_recibe') }}" class="form-control" placeholder="Ej. INE 1234567890">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Telefono</label>
                            <input type="text" name="telefono_recibe" value="{{ old('telefono_recibe') }}" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Folio de la memoria en SIERSE *</label>
                            <input required type="text" name="sierse_folio" value="{{ old('sierse_folio') }}" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Condición del vehículo al entregar *</label>
                            <select required name="condicion_entrega" class="form-control">
                                <option value="">Selecciona</option>
                                <option value="CONFORME_INVENTARIO" {{ old('condicion_entrega') === 'CONFORME_INVENTARIO' ? 'selected' : '' }}>Conforme al inventario</option>
                                <option value="CON_OBSERVACIONES" {{ old('condicion_entrega') === 'CON_OBSERVACIONES' ? 'selected' : '' }}>Con daños, faltantes u observaciones</option>
                            </select>
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Oficio de liberación *</label>
                            <input required type="file" name="documento_liberacion" accept="application/pdf,image/*" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Memoria descriptiva generada en SIERSE *</label>
                            <input required type="file" name="memoria_descriptiva" accept="application/pdf,image/*" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Comprobante de pago *</label>
                            <input required type="file" name="comprobante_pago" accept="application/pdf,image/*" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Foto de identificación *</label>
                            <input required type="file" name="foto_identificacion" accept="image/*" capture="environment" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Foto del vehículo al momento de la entrega *</label>
                            <input required type="file" name="foto_entrega" accept="image/*" capture="environment" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row' : 'form-group col-md-6' }}">
                            <label>Foto de firma autógrafa (opcional)</label>
                            <input type="file" name="firma_recibe" accept="image/*" capture="environment" class="form-control">
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row full' : 'form-group col-md-12' }}">
                            <label>Observaciones</label>
                            <textarea name="observaciones" class="form-control">{{ old('observaciones') }}</textarea>
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row full' : 'form-group col-md-12' }}">
                            <label>
                                <input required type="checkbox" name="conformidad_memoria" value="1" {{ old('conformidad_memoria') ? 'checked' : '' }}>
                                La persona que recibe manifiesta su conformidad con la memoria descriptiva y la condición del vehículo.
                            </label>
                        </div>

                        <div class="{{ ($portal ?? false) ? 'form-row full' : 'form-group col-md-12' }}">
                            <label>
                                <input required type="checkbox" name="confirmar_entrega" value="1" {{ old('confirmar_entrega') ? 'checked' : '' }}>
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
