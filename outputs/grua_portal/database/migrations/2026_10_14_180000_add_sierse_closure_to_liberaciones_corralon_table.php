<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class AddSierseClosureToLiberacionesCorralonTable extends Migration
{
    public function up()
    {
        Schema::table('liberaciones_corralon', function (Blueprint $table) {
            $table->string('sierse_folio', 120)->nullable()->after('telefono_recibe');
            $table->string('condicion_entrega', 40)->nullable()->after('sierse_folio');
            $table->string('memoria_descriptiva')->nullable()->after('documento_liberacion');
            $table->string('comprobante_pago')->nullable()->after('memoria_descriptiva');
            $table->string('firma_recibe')->nullable()->after('comprobante_pago');
            $table->boolean('conformidad_memoria')->default(false)->after('firma_recibe');
            $table->dateTime('fecha_conformidad')->nullable()->after('conformidad_memoria');
            $table->string('ip_entrega', 45)->nullable()->after('fecha_conformidad');
            $table->string('user_agent_entrega', 500)->nullable()->after('ip_entrega');
        });
    }

    public function down()
    {
        Schema::table('liberaciones_corralon', function (Blueprint $table) {
            $table->dropColumn([
                'sierse_folio',
                'condicion_entrega',
                'memoria_descriptiva',
                'comprobante_pago',
                'firma_recibe',
                'conformidad_memoria',
                'fecha_conformidad',
                'ip_entrega',
                'user_agent_entrega',
            ]);
        });
    }
}
