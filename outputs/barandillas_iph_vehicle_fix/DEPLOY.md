# IPH automático de Barandillas solo vehículo

El envío automático al teléfono configurado para Barandillas usa exclusivamente
`IPH_BARANDILLAS_VEHICULO.docx`, aun cuando la captura incluya una persona
conductora. El nombre de quien firma se toma de los tres campos capturados al
activar el operativo.

Ejecutar `apply.ps1` y después validar:

```powershell
php artisan test tests/Unit/ConduceLegalidadBarandillasWhatsappTest.php tests/Unit/IphPuestaDisposicionDocxServiceTest.php tests/Unit/ConduceLegalidadIphMappingTest.php
```

El script crea un respaldo recuperable bajo `tmp/barandillas-iph-vehicle-backup`.
