# Plantilla WhatsApp: tiempo de reacción con recorrido

## Datos generales

- Nombre: `alerta_tiempo_reaccion_siniestros_v2`
- Categoría: `Utilidad`
- Idioma: `Spanish (MEX)` / `es_MX`

## Encabezado

- Tipo: `Texto`
- Contenido: `🚨 TIEMPO DE REACCIÓN 🚨`
- No agregar variables al encabezado.

## Cuerpo

```text
🚓 Servicio C5i: {{1}}
👮 Unidad: {{2}}
📍 Lugar: {{3}}

📞 Reporte C5i: {{4}}
📝 Asignación: {{5}}
🏁 Arribo detectado por GPS: {{6}}
💬 Mensaje de arribo: {{7}}

🛰️ C5i → GPS: {{8}}
📍 Asignación → GPS: {{9}}
📏 Comparación: {{10}}

🗺️ Consulta el recorrido registrado con el botón.
✅ Fin del reporte.
```

## Ejemplos de las variables del cuerpo

1. `C5i WA-21261`
2. `174`
3. `98 L5 AVENIDA GUADALUPE VICTORIA, MORELIA`
4. `15/09/2026 12:14:33`
5. `15/09/2026 12:15:04`
6. `15/09/2026 12:31:40`
7. `15/09/2026 12:47:03`
8. `17 min 7 s`
9. `16 min 36 s`
10. `El mensaje se envió 15 min 23 s después del arribo GPS; GPS a 35 m del punto; precisión 12 m`

## Pie de página

`Coordinación de Agrupamiento de Seguridad Vial`

## Botón

- Tipo: `Visitar sitio web`
- Texto: `Ver recorrido`
- Tipo de URL: `Dinámica`
- URL: `https://seguridadvial-mich.com/c5i/tiempos/{{1}}`
- Ejemplo para la variable del botón: `123`

La variable del botón es independiente de las variables del cuerpo. El backend
envía el identificador interno del reporte como sufijo dinámico.

## Activación después de que Meta la apruebe

Cambiar en `.env`:

```dotenv
WHATSAPP_C5I_RESPONSE_TIME_TEMPLATE=alerta_tiempo_reaccion_siniestros_v2
WHATSAPP_C5I_RESPONSE_TIME_TEMPLATE_LANGUAGE=es_MX
WHATSAPP_C5I_RESPONSE_TIME_ROUTE_BUTTON=true
```

Después, limpiar la caché de configuración:

```shell
php artisan config:clear
```

No activar `ROUTE_BUTTON` con la plantilla v1, porque esa plantilla no contiene
el componente de botón y Meta rechazará el envío.
