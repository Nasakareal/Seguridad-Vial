<?php
require 'C:/wamp64/www/sistemaEstadistico/vendor/autoload.php';
$app = require 'C:/wamp64/www/sistemaEstadistico/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$connection = config('database.default');
$settings = config('database.connections.'.$connection);
$local = in_array($settings['host'] ?? '', ['localhost', '127.0.0.1', '::1'], true);
echo json_encode(['local_database' => $local, 'driver' => $connection]).PHP_EOL;
if (!$local) exit;
try {
    echo json_encode(['route_table_exists' => Illuminate\Support\Facades\Schema::hasTable('c5i_route_points')]).PHP_EOL;
    $matches = App\Models\WhatsAppWebMessage::query()
        ->whereBetween('sent_at', ['2026-09-15 13:30:00', '2026-09-15 14:15:00'])
        ->where('body', 'like', '%PM256%')->limit(10)->get(['id', 'sent_at']);
    echo json_encode(['local_example_messages' => $matches]).PHP_EOL;
} catch (Throwable $e) { echo 'No se pudo consultar la base local.'.PHP_EOL; }
