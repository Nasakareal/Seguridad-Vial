<?php
require 'C:/wamp64/www/sistemaEstadistico/vendor/autoload.php';
$app = require 'C:/wamp64/www/sistemaEstadistico/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$connection = config('database.default');
$host = config('database.connections.'.$connection.'.host');
echo json_encode([
    'database_driver' => $connection,
    'database_is_local' => in_array($host, ['localhost', '127.0.0.1', '::1'], true),
    'firebase_project_configured' => (bool) config('services.firebase.project_id'),
    'firebase_credentials_exist' => is_file((string) config('services.firebase.service_account')),
    'hechos_fingerprint_column' => Illuminate\Support\Facades\Schema::hasColumn('hechos', 'submission_fingerprint'),
], JSON_PRETTY_PRINT);
