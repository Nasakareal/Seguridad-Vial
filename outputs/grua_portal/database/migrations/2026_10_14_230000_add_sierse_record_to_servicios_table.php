<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class AddSierseRecordToServiciosTable extends Migration
{
    public function up()
    {
        Schema::table('servicios', function (Blueprint $table) {
            $table->string('modalidad_servicio', 40)->nullable()->after('descripcion');
            $table->string('folio_sierse', 120)->nullable()->after('modalidad_servicio');
            $table->dateTime('fecha_solicitud')->nullable()->after('folio_sierse');
            $table->dateTime('fecha_arribo')->nullable()->after('fecha_solicitud');
            $table->dateTime('fecha_inicio')->nullable()->after('fecha_arribo');
            $table->dateTime('fecha_fin')->nullable()->after('fecha_inicio');
            $table->string('lugar_origen')->nullable()->after('fecha_fin');
            $table->string('lugar_destino')->nullable()->after('lugar_origen');
            $table->string('autoridad_solicitante')->nullable()->after('lugar_destino');
            $table->string('agente_solicitante')->nullable()->after('autoridad_solicitante');
            $table->string('persona_solicitante')->nullable()->after('agente_solicitante');
            $table->string('operador_nombre')->nullable()->after('persona_solicitante');
            $table->string('unidad_grua')->nullable()->after('operador_nombre');
            $table->decimal('kilometros_recorridos', 10, 2)->nullable()->after('unidad_grua');
            $table->decimal('importe_total', 12, 2)->nullable()->after('kilometros_recorridos');
            $table->string('forma_pago', 40)->nullable()->after('importe_total');
            $table->string('memoria_descriptiva_path')->nullable()->after('forma_pago');
            $table->string('memoria_descriptiva_nombre')->nullable()->after('memoria_descriptiva_path');
            $table->string('memoria_descriptiva_mime', 100)->nullable()->after('memoria_descriptiva_nombre');
            $table->string('memoria_descriptiva_sha256', 64)->nullable()->after('memoria_descriptiva_mime');
            $table->foreignId('memoria_subida_por_grua_usuario_id')->nullable()
                ->after('memoria_descriptiva_sha256')->constrained('grua_usuarios')->nullOnDelete();
            $table->dateTime('memoria_subida_at')->nullable()->after('memoria_subida_por_grua_usuario_id');
        });
    }

    public function down()
    {
        Schema::table('servicios', function (Blueprint $table) {
            $table->dropForeign(['memoria_subida_por_grua_usuario_id']);
            $table->dropColumn([
                'modalidad_servicio', 'folio_sierse', 'fecha_solicitud', 'fecha_arribo',
                'fecha_inicio', 'fecha_fin', 'lugar_origen', 'lugar_destino',
                'autoridad_solicitante', 'agente_solicitante', 'persona_solicitante',
                'operador_nombre', 'unidad_grua', 'kilometros_recorridos', 'importe_total',
                'forma_pago', 'memoria_descriptiva_path', 'memoria_descriptiva_nombre',
                'memoria_descriptiva_mime', 'memoria_descriptiva_sha256',
                'memoria_subida_por_grua_usuario_id', 'memoria_subida_at',
            ]);
        });
    }
}
