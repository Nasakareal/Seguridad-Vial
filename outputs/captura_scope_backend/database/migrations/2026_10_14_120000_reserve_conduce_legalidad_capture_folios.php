<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('conduce_legalidad_folio_reservas', function (Blueprint $table) {
            $table->id();
            $table->foreignId('operativo_id')
                ->constrained('conduce_legalidad_operativos')
                ->cascadeOnDelete();
            $table->uuid('client_uuid');
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['operativo_id', 'client_uuid'], 'cl_folio_reserva_operativo_uuid_unique');
        });

        Schema::table('conduce_legalidad_capturas', function (Blueprint $table) {
            $table->unsignedBigInteger('folio_numero')->nullable()->unique()->after('client_uuid');
        });
    }

    public function down(): void
    {
        Schema::table('conduce_legalidad_capturas', function (Blueprint $table) {
            $table->dropUnique(['folio_numero']);
            $table->dropColumn('folio_numero');
        });
        Schema::dropIfExists('conduce_legalidad_folio_reservas');
    }
};
