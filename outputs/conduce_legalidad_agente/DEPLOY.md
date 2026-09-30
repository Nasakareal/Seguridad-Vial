# Agente actuante en Conduce con Legalidad

Este paquete conserva `created_by` como usuario auditor y guarda por separado la
identidad escrita del agente actuante en campos separados para nombre(s),
apellido paterno y apellido materno. Incluye el modelo, controlador, generador
del IPH, migración y pruebas unitarias.

Después de copiar los archivos respetando sus rutas:

```powershell
php artisan migrate --force
php artisan test tests/Unit/ConduceLegalidadIphMappingTest.php tests/Unit/ConduceLegalidadBoletaWhatsappTest.php
```

La API mantiene compatibilidad con clientes anteriores: si todavía no envían los
campos del agente, usa temporalmente los datos del usuario que captura. La app
nueva exige nombre y número de placa en el formulario.
