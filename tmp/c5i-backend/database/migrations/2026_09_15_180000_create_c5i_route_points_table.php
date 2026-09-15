<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateC5iRoutePointsTable extends Migration
{
    public function up()
    {
        Schema::create('c5i_route_points', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('user_id');
            $table->unsignedBigInteger('patrulla_id')->nullable();
            $table->decimal('lat', 10, 7);
            $table->decimal('lng', 10, 7);
            $table->float('accuracy');
            $table->dateTime('captured_at');
            $table->dateTime('received_at');
            $table->unique(['user_id', 'captured_at']);
            $table->index(['patrulla_id', 'captured_at']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('c5i_route_points');
    }
}
