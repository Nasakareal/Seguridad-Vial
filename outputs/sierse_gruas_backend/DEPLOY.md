# Inicio SIERSE para grúas

Incluye la reserva concurrente de folio para capturas de operativo. El folio que la app muestra antes de capturar es el mismo que se guarda y se imprime en boleta e IPH.

Aplicación local:

```powershell
.\outputs\sierse_gruas_backend\apply.ps1
```

El script ejecuta la migración y, si falla, restaura controlador, modelo y rutas para no dejar el backend a medias. También debe publicarse la app Flutter actualizada.
