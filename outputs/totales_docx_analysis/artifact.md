# Contrato de plantilla para totales de Conduce con Legalidad

## Referencia

- Archivo retenido: `C:\wamp64\www\sistemaEstadistico\public\TOTALES.docx`
- SHA-256: `d539b3076b568538fce6aaee3ac4421b8d6f7f71a4602a2f07090ed67aa7ff5f`
- Tamaño: 724218 bytes
- Páginas de plantilla sin llenar: 2
- Secciones: 3
- Render visual: `C:\Users\naasa\seguridad_vial_app\outputs\totales_docx_analysis\template-render`
- Evidencia de estilos: `C:\Users\naasa\seguridad_vial_app\outputs\totales_docx_analysis\template-style-evidence.json`
- Documento de ejemplo: `C:\Users\naasa\Downloads\SUB.OP.P.-CASV-5109-2026 INFORME OP CONDUCE CON LEGALIDAD 08 10 2026.docx`
- SHA-256 del ejemplo: `bb3975e054153c51c65511c25259b970680c5da9bf495dde39737d5cbbdb6920`
- Páginas del ejemplo: 6

## Sistema de página

- Carta vertical, 8.5 x 11 pulgadas en las tres secciones.
- Sección 1: márgenes izquierdo 1.18, derecho 0.82, superior 0.98 e inferior 0.59 pulgadas; inicio en página nueva; una columna.
- Sección 2: inicio continuo, mismos márgenes laterales y superior, margen inferior 0.30 pulgadas; dos columnas con separación de 708 twips.
- Sección 3: inicio continuo, mismos márgenes que la sección 2; una columna.
- Encabezados de primera, pares e impares definidos en la sección inicial; las secciones posteriores están vinculadas.
- Distancias de encabezado y pie cercanas a 0.49 pulgadas.

## Tipografía y componentes

- Fuente predominante: Arial.
- La plantilla usa formato directo para encabezados institucionales, cuerpo justificado, listas y títulos; esos estilos y propiedades deben preservarse.
- Ocho imágenes institucionales se distribuyen entre el cuerpo y los encabezados; seis son flotantes. Todos sus anclajes, relaciones y tamaños son de preservación obligatoria.
- No hay campos Word ni controles de contenido.
- La sección de vehículos debe fluir en dos columnas como en el documento de ejemplo.

## Flujo y espacios editables

- El contenido institucional, destinatario, fundamento, objetivo, autoridades, resultados, firma y copias se conserva.
- Los marcadores editables están únicamente en `word/document.xml`:
  - `$dia`: día de la fecha del operativo, dos dígitos.
  - `$mesletra`: mes de la fecha del operativo en español y minúsculas, conforme al ejemplo.
  - `$year`: año de cuatro dígitos.
  - `$mesnumero`: mes de dos dígitos.
  - `$hora`: hora de inicio del operativo en formato HH:mm.
  - `$lugar`: lugar completo del operativo.
  - `$totalvehiculo`: total de vehículos registrados en todas las capturas.
  - `$totales`: bloque repetido de vehículos, uno por registro, con número, placas, vehículo, tipo, color, seguro, folio Conduce, inventario, corralón y fecha/hora.
  - `$horatermino`: hora de cierre del operativo; si no existe, última hora registrada en las capturas.
- El párrafo de `$totales` es sustituible por una secuencia de párrafos dentro de la sección de dos columnas. Los demás marcadores se reemplazan en su propio texto sin reconstruir el formato.

## Preservación del paquete

- Se preservan todos los componentes y relaciones salvo `word/document.xml`, que es el único componente editable.
- Deben conservarse estilos, numeración, temas, configuración, encabezados, imágenes, pies, relaciones, propiedades y todos los componentes opacos.
- La plantilla original debe permanecer sin cambios y conservar el SHA-256 registrado.

## Puertas de fidelidad

- Ningún marcador `$...` puede quedar en el resultado.
- Las tres secciones, tamaños, márgenes y configuración de columnas deben permanecer iguales.
- Los encabezados, fondos, logotipos, firmas y texto institucional no deben moverse fuera de las diferencias causadas por la expansión del bloque de vehículos.
- El resultado debe renderizarse y revisarse en todas sus páginas, comprobando texto cortado, superpuesto, desbordado o columnas rotas.
