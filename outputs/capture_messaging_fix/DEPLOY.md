# Corrección de capturas y comunicaciones — 1.30.97 (146)

Los archivos del backend de este paquete ya están aplicados en el entorno local
`C:\wamp64\www\sistemaEstadistico`. La migración se ejecutó solo en la base local.
No se cambiaron credenciales de Firebase ni se enviaron mensajes de prueba reales.

## Publicación en producción

1. Publicar la migración incluida y ejecutarla antes de activar el controlador nuevo:

   `php artisan migrate --path=database/migrations/2026_09_04_120000_add_submission_fingerprint_to_hechos_table.php --force`

2. Publicar los archivos de `app/` incluidos conservando las rutas. Mantener la
   configuración actual de Firebase que usa Waze. No reemplazar `.env`.
3. Distribuir la app 1.30.97 (146).
4. Comprobar con dos cuentas de prueba: mensaje del superadmin, apertura y respuesta
   del destinatario, sonido con la app abierta y en segundo plano.

## Comportamiento

- Al encontrar un borrador se pregunta si se continúa, mostrando fecha y lugar.
- Continuar/reintentar conserva el UUID; otra captura empieza con otra identidad.
- El UUID se guarda antes de enviar. Se guarda al pasar a segundo plano.
- No se restaura ni reescribe un borrador mientras se decide si recuperarlo.
- Un UUID enviado con datos de otro hecho se rechaza; no modifica el hecho original.
- Las repeticiones coincidentes se devuelven como existentes, con aviso explícito
  en la app antes de continuar vehículos o lesionados.
- Los mensajes web/API disparan push mediante el mismo servicio que Waze, tras
  responder al envío, para que una falla push no provoque repetir el mensaje.
- Los destinatarios pueden abrir y responder al superadmin que les escribió.

La detección por contenido evita coincidencias exactas; no intenta decidir que dos
eventos con datos diferentes sean el mismo. Los registros históricos no se borran
ni se corrigen automáticamente.
