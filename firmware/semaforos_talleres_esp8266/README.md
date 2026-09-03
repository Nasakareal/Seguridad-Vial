# Controlador semafórico ESP8266 (dos nodos)

Este firmware usa un ESP8266 **maestro** y otro **secundario**. El teléfono se
conecta al punto de acceso del maestro (`192.168.4.1`) y los dos controladores
se sincronizan por ESP-NOW en el canal 1.

## Antes de energizar lámparas

1. Prueba únicamente con LEDs o cargas de banco. Nunca pruebes por primera vez
   en vía pública.
2. El aislamiento del optoacoplador no conmuta por sí solo una lámpara de
   potencia: usa contactores/SSR apropiados, fusible, puesta a tierra y un
   enclavamiento eléctrico que impida verdes simultáneos aun si el software
   falla.
3. Confirma si el módulo optoacoplador es activo en bajo. Si no lo es, cambia
   `OUTPUT_ACTIVE_LOW` en `include/controller_config.h`.
4. Confirma las entradas conectadas a rojo, ámbar y verde. La plantilla usa D1,
   D2 y D5; no conectes potencia hasta verificar cada canal.

## Preparación y carga

1. Copia `include/controller_secrets.example.h` como
   `include/controller_secrets.h` y cambia la contraseña del AP, la clave de
   la API y los 16 bytes de ESP-NOW. El archivo real está ignorado por Git.
2. Carga primero cada perfil por USB y abre el monitor serial para anotar la
   MAC STA que imprime cada placa:

   ```text
   pio run -e master -t upload
   pio run -e follower -t upload
   ```

3. Escribe ambas MAC en `MASTER_MAC` y `FOLLOWER_MAC`, recompila y vuelve a
   cargar cada perfil.
4. Con ambos encendidos, conecta el teléfono al AP del maestro. En la app abre
   **Controlador semafórico → conexión**, usa `http://192.168.4.1` y la misma
   `API_ACCESS_KEY`.

El maestro se niega a iniciar con claves/MAC de plantilla. Puede ejecutar su
ciclo de forma autónoma cuando el secundario no está presente y continúa
enviando sincronización por ESP-NOW por si el secundario aparece. El secundario
conserva la protección de ponerse en rojo si pasa 1.5 s sin sincronización.

## Secuencia permitida

La app sólo cambia nombres y duraciones. El firmware conserva este orden:

1. A verde / B rojo
2. A ámbar / B rojo
3. ambos rojo
4. A rojo / B verde
5. A rojo / B ámbar
6. ambos rojo

Límites: verdes 5–180 s, ámbar 2–10 s y todo rojo 1–10 s.
