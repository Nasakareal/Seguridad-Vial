<?php

return [

    'mailgun' => [
        'domain' => env('MAILGUN_DOMAIN'),
        'secret' => env('MAILGUN_SECRET'),
        'endpoint' => env('MAILGUN_ENDPOINT', 'api.mailgun.net'),
    ],

    'postmark' => [
        'token' => env('POSTMARK_TOKEN'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'inegi_choques' => [
        'mail_to' => env('INEGI_CHOQUES_MAIL_TO', ''),
        'mail_cc' => env('INEGI_CHOQUES_MAIL_CC', ''),
        'mail_bcc' => env('INEGI_CHOQUES_MAIL_BCC', ''),
        'schedule_time' => env('INEGI_CHOQUES_SCHEDULE_TIME', '04:30'),
        'template_path' => env('INEGI_CHOQUES_TEMPLATE_PATH', ''),
    ],

    'alcoholimetria_mensual' => [
        'required_mail_to' => [
            'michpreviene@gmail.com',
            'dr.bernier26@hotmail.com',
        ],
        'mail_to' => env('ALCOHOLIMETRIA_MENSUAL_MAIL_TO', ''),
        'start_month' => env('ALCOHOLIMETRIA_MENSUAL_START_MONTH', '2026-07'),
        'schedule_time' => env('ALCOHOLIMETRIA_MENSUAL_SCHEDULE_TIME', '05:00'),
        'template_path' => env('ALCOHOLIMETRIA_MENSUAL_TEMPLATE_PATH', ''),
        'municipio_sin_registros' => env('ALCOHOLIMETRIA_MUNICIPIO_SIN_REGISTROS', 'MORELIA'),
    ],

    'waze' => [
        'feed_url' => env('WAZE_FEED_URL'),
        'morelia_user_ids' => array_values(array_filter(array_map('intval', explode(',', env('WAZE_MORELIA_USER_IDS', ''))))),
        'morelia_polygon' => [],
        'notify_radius_km' => (float) env('WAZE_NOTIFY_RADIUS_KM', 75),
        'notify_location_max_age_minutes' => (int) env('WAZE_NOTIFY_LOCATION_MAX_AGE_MINUTES', 720),
        'dedup_radius_km' => (float) env('WAZE_DEDUP_RADIUS_KM', 2),
        'dedup_window_minutes' => (int) env('WAZE_DEDUP_WINDOW_MINUTES', 120),
    ],

    'firebase' => [
        'project_id' => env('FIREBASE_PROJECT_ID'),
        'service_account' => env('FIREBASE_SERVICE_ACCOUNT'),
    ],

    'whatsapp' => [
        'graph_version' => env('WHATSAPP_GRAPH_VERSION', 'v25.0'),
        'token' => env('WHATSAPP_ACCESS_TOKEN'),
        'phone_number_id' => env('WHATSAPP_PHONE_NUMBER_ID'),
        'verify_token' => env('WHATSAPP_VERIFY_TOKEN', 'seguridadvial_token'),
        'default_to' => env('WHATSAPP_DEFAULT_TO'),

        'web_reader' => [
            'secret' => env('WHATSAPP_WEB_READER_SECRET'),
            'allowed_group_ids' => env('WHATSAPP_WEB_READER_ALLOWED_GROUP_IDS', ''),
            'allowed_author_ids' => env('WHATSAPP_WEB_READER_ALLOWED_AUTHOR_IDS', ''),
            'allow_operational_authors' => filter_var(env('WHATSAPP_WEB_READER_ALLOW_OPERATIONAL_AUTHORS', false), FILTER_VALIDATE_BOOLEAN),
        ],

        'c5i_recommendation' => [
            'enabled' => filter_var(env('WHATSAPP_C5I_RECOMMENDATION_ENABLED', false), FILTER_VALIDATE_BOOLEAN),
            'dry_run' => filter_var(env('WHATSAPP_C5I_RECOMMENDATION_DRY_RUN', true), FILTER_VALIDATE_BOOLEAN),
            'to' => env('WHATSAPP_C5I_RECOMMENDATION_TO', ''),
            'group_ids' => env('WHATSAPP_C5I_RECOMMENDATION_GROUP_IDS', ''),
            'source_author_ids' => env('WHATSAPP_C5I_RECOMMENDATION_SOURCE_AUTHOR_IDS', ''),
            'template' => env('WHATSAPP_C5I_RECOMMENDATION_TEMPLATE', 'recomendacion_unidad_siniestros_c5i_v1'),
            'template_language' => env('WHATSAPP_C5I_RECOMMENDATION_TEMPLATE_LANGUAGE', 'es_MX'),
            'unit_slug' => env('WHATSAPP_C5I_RECOMMENDATION_UNIT_SLUG', 'siniestros'),
            'location_max_age_minutes' => (int) env('WHATSAPP_C5I_RECOMMENDATION_LOCATION_MAX_AGE_MINUTES', 10),
            'max_accuracy_meters' => (int) env('WHATSAPP_C5I_RECOMMENDATION_MAX_ACCURACY_METERS', 200),
        ],

        'c5i_response_time' => [
            'enabled' => filter_var(env('WHATSAPP_C5I_RESPONSE_TIME_ENABLED', false), FILTER_VALIDATE_BOOLEAN),
            'dry_run' => filter_var(env('WHATSAPP_C5I_RESPONSE_TIME_DRY_RUN', true), FILTER_VALIDATE_BOOLEAN),
            'to' => env('WHATSAPP_C5I_RESPONSE_TIME_TO', ''),
            'group_ids' => env('WHATSAPP_C5I_RESPONSE_TIME_GROUP_IDS', ''),
            'source_author_ids' => env('WHATSAPP_C5I_RESPONSE_TIME_SOURCE_AUTHOR_IDS', env('WHATSAPP_C5I_RECOMMENDATION_SOURCE_AUTHOR_IDS', '')),
            'dispatch_author_ids' => env('WHATSAPP_C5I_RESPONSE_TIME_DISPATCH_AUTHOR_IDS', ''),
            'template' => env('WHATSAPP_C5I_RESPONSE_TIME_TEMPLATE', 'alerta_tiempo_reaccion_siniestros_v1'),
            'template_language' => env('WHATSAPP_C5I_RESPONSE_TIME_TEMPLATE_LANGUAGE', 'es_MX'),
            'route_button' => filter_var(env('WHATSAPP_C5I_RESPONSE_TIME_ROUTE_BUTTON', false), FILTER_VALIDATE_BOOLEAN),
            'unit_slug' => env('WHATSAPP_C5I_RESPONSE_TIME_UNIT_SLUG', 'siniestros'),
            'arrival_radius_meters' => (int) env('WHATSAPP_C5I_RESPONSE_TIME_ARRIVAL_RADIUS_METERS', 200),
            'max_accuracy_meters' => (int) env('WHATSAPP_C5I_RESPONSE_TIME_MAX_ACCURACY_METERS', 100),
            'open_service_minutes' => (int) env('WHATSAPP_C5I_RESPONSE_TIME_OPEN_SERVICE_MINUTES', 240),
            'transcribe_audio' => filter_var(env('WHATSAPP_C5I_RESPONSE_TIME_TRANSCRIBE_AUDIO', true), FILTER_VALIDATE_BOOLEAN),
            'transcription_model' => env('WHATSAPP_C5I_RESPONSE_TIME_TRANSCRIPTION_MODEL', 'gpt-4o-mini-transcribe'),
            'transcription_prompt' => env('WHATSAPP_C5I_RESPONSE_TIME_TRANSCRIPTION_PROMPT', 'Radio policial en español. Transcribe literalmente números de unidad, claves, kilómetros y códigos usando dígitos y guiones.'),
            'transcription_timeout' => (int) env('WHATSAPP_C5I_RESPONSE_TIME_TRANSCRIPTION_TIMEOUT', 60),
            'audio_max_bytes' => (int) env('WHATSAPP_C5I_RESPONSE_TIME_AUDIO_MAX_BYTES', 5242880),
        ],

        'suspicious_place' => [
            'enabled' => filter_var(env('WHATSAPP_SUSPICIOUS_PLACE_ENABLED', false), FILTER_VALIDATE_BOOLEAN),
            'dry_run' => filter_var(env('WHATSAPP_SUSPICIOUS_PLACE_DRY_RUN', true), FILTER_VALIDATE_BOOLEAN),
            'to' => env('WHATSAPP_SUSPICIOUS_PLACE_TO', env('WHATSAPP_SINIESTROS_RESUMEN_TO', '')),
            'unit_id' => (int) env('WHATSAPP_SUSPICIOUS_PLACE_UNIT_ID', 1),
            'place_key' => env('WHATSAPP_SUSPICIOUS_PLACE_KEY', 'gruas-munoz'),
            'place_name' => env('WHATSAPP_SUSPICIOUS_PLACE_NAME', 'Grúas Muñoz'),
            'latitude' => (float) env('WHATSAPP_SUSPICIOUS_PLACE_LATITUDE', 19.6603522),
            'longitude' => (float) env('WHATSAPP_SUSPICIOUS_PLACE_LONGITUDE', -101.2373983),
            'entry_radius_meters' => (int) env('WHATSAPP_SUSPICIOUS_PLACE_ENTRY_RADIUS_METERS', 120),
            'exit_radius_meters' => (int) env('WHATSAPP_SUSPICIOUS_PLACE_EXIT_RADIUS_METERS', 180),
            'dwell_minutes' => (int) env('WHATSAPP_SUSPICIOUS_PLACE_DWELL_MINUTES', 5),
            'max_accuracy_meters' => (int) env('WHATSAPP_SUSPICIOUS_PLACE_MAX_ACCURACY_METERS', 100),
            'location_max_age_minutes' => (int) env('WHATSAPP_SUSPICIOUS_PLACE_LOCATION_MAX_AGE_MINUTES', 3),
            'max_sample_gap_minutes' => (int) env('WHATSAPP_SUSPICIOUS_PLACE_MAX_SAMPLE_GAP_MINUTES', 3),
            'client_event_max_age_hours' => (int) env('WHATSAPP_SUSPICIOUS_PLACE_CLIENT_EVENT_MAX_AGE_HOURS', 24),
            'entry_template' => env('WHATSAPP_SUSPICIOUS_PLACE_ENTRY_TEMPLATE', 'alerta_permanencia_siniestros_v1'),
            'exit_template' => env('WHATSAPP_SUSPICIOUS_PLACE_EXIT_TEMPLATE', 'alerta_salida_permanencia_siniestros_v1'),
            'template_language' => env('WHATSAPP_SUSPICIOUS_PLACE_TEMPLATE_LANGUAGE', 'es_MX'),
        ],

        'conduce_legalidad' => [
            'rnd_chatbot_to' => env('WHATSAPP_CONDUCE_LEGALIDAD_RND_CHATBOT_TO', '5214433163728'),
            'rnd_chatbot_template' => env('WHATSAPP_CONDUCE_LEGALIDAD_RND_CHATBOT_TEMPLATE', 'solicitud_rnd_faltas_administrativas'),
            'rnd_chatbot_template_language' => env('WHATSAPP_CONDUCE_LEGALIDAD_RND_CHATBOT_TEMPLATE_LANGUAGE', 'es_MX'),
        ],

        'equinos_bridge' => [
            'enabled' => filter_var(env('WHATSAPP_EQUINOS_BRIDGE_ENABLED', false), FILTER_VALIDATE_BOOLEAN),
            'url' => env('WHATSAPP_EQUINOS_BRIDGE_URL', 'https://equinosycaninos.com/api/whatsapp/webhook'),
            'phones' => array_values(array_filter(array_map('trim', explode(',', env('WHATSAPP_EQUINOS_BRIDGE_PHONES', ''))))),
            'timeout' => (int) env('WHATSAPP_EQUINOS_BRIDGE_TIMEOUT', 60),
        ],

        'siniestros' => [
            'to' => env('WHATSAPP_SINIESTROS_TO'),
            'firma' => env('WHATSAPP_SINIESTROS_FIRMA', 'SUBDIRECTOR DE LA UNIDAD DE ATENCIÓN A SINIESTROS LIC. JULIO ERNESTO BAUTISTA JIMÉNEZ'),
            'resumen_to' => env('WHATSAPP_SINIESTROS_RESUMEN_TO'),
            'tarjeta_hechos_to' => env('WHATSAPP_SINIESTROS_TARJETA_HECHOS_TO'),
            'actividades_to' => env('WHATSAPP_SINIESTROS_ACTIVIDADES_TO'),
            'vialidades_urbanas_alertas_to' => env('WHATSAPP_SINIESTROS_VIALIDADES_URBANAS_ALERTAS_TO'),
            'resumen_template' => env('WHATSAPP_SINIESTROS_RESUMEN_TEMPLATE'),
            'tarjeta_hechos_template' => env('WHATSAPP_SINIESTROS_TARJETA_HECHOS_TEMPLATE'),
            'actividades_template' => env('WHATSAPP_SINIESTROS_ACTIVIDADES_TEMPLATE'),
            'actividades_template_language' => env('WHATSAPP_SINIESTROS_ACTIVIDADES_TEMPLATE_LANGUAGE', 'es_MX'),
            'vialidades_urbanas_alertas_template' => env('WHATSAPP_SINIESTROS_VIALIDADES_URBANAS_ALERTAS_TEMPLATE', 'alerta_vialidades_urbanas_siniestros'),
            'vialidades_urbanas_alertas_template_language' => env('WHATSAPP_SINIESTROS_VIALIDADES_URBANAS_ALERTAS_TEMPLATE_LANGUAGE', 'es_MX'),
        ],

        'vialidades_urbanas' => [
            'to' => env('WHATSAPP_VIALIDADES_URBANAS_TO'),
            'template' => env('WHATSAPP_VIALIDADES_URBANAS_TEMPLATE', 'reporte_vialidades_urbanas_bloque'),
            'template_language' => env('WHATSAPP_VIALIDADES_URBANAS_TEMPLATE_LANGUAGE', 'es_MX'),
            'template_layout' => env('WHATSAPP_VIALIDADES_URBANAS_TEMPLATE_LAYOUT', 'diario'),
            'template_chunk_chars' => (int) env('WHATSAPP_VIALIDADES_URBANAS_TEMPLATE_CHUNK_CHARS', 850),
            'text_chunk_chars' => (int) env('WHATSAPP_VIALIDADES_URBANAS_TEXT_CHUNK_CHARS', 3900),
            'incluir_novedades' => filter_var(env('WHATSAPP_VIALIDADES_URBANAS_INCLUIR_NOVEDADES', false), FILTER_VALIDATE_BOOLEAN),
            'firma_cargo' => env('WHATSAPP_VIALIDADES_URBANAS_FIRMA_CARGO', 'SUBDIRECTOR DE PROTECCIÓN EN VIALIDADES URBANAS'),
            'firma_nombre' => env('WHATSAPP_VIALIDADES_URBANAS_FIRMA_NOMBRE'),
        ],

        'carreteras_guardianes' => [
            'to' => env('WHATSAPP_CARRETERAS_GUARDIANES_TO'),
            'template_layout' => env('WHATSAPP_CARRETERAS_GUARDIANES_TEMPLATE_LAYOUT', 'tres_partes'),
            'template_part_1' => env('WHATSAPP_CARRETERAS_GUARDIANES_TEMPLATE_PARTE_1', 'carreteras_guardianes_consolidado_p1'),
            'template_part_2' => env('WHATSAPP_CARRETERAS_GUARDIANES_TEMPLATE_PARTE_2', 'carreteras_guardianes_consolidado_p2'),
            'template_part_3' => env('WHATSAPP_CARRETERAS_GUARDIANES_TEMPLATE_PARTE_3', 'carreteras_guardianes_consolidado_p3'),
            'block_template' => env('WHATSAPP_CARRETERAS_GUARDIANES_BLOCK_TEMPLATE', env('WHATSAPP_CARRETERAS_GUARDIANES_TEMPLATE', 'carreteras_guardianes_consolidado_bloque')),
            'template_language' => env('WHATSAPP_CARRETERAS_GUARDIANES_TEMPLATE_LANGUAGE', 'es_MX'),
            'template_chunk_chars' => (int) env('WHATSAPP_CARRETERAS_GUARDIANES_TEMPLATE_CHUNK_CHARS', 850),
            'text_chunk_chars' => (int) env('WHATSAPP_CARRETERAS_GUARDIANES_TEXT_CHUNK_CHARS', 3900),
            'unidad_id' => (int) env('WHATSAPP_CARRETERAS_GUARDIANES_UNIDAD_ID', 4),
            'rango_campo' => env('WHATSAPP_CARRETERAS_GUARDIANES_RANGO_CAMPO', 'created_at'),
            'destacamento' => env('WHATSAPP_CARRETERAS_GUARDIANES_DESTACAMENTO', 'MORELIA'),
            'descripcion_general' => env('WHATSAPP_CARRETERAS_GUARDIANES_DESCRIPCION_GENERAL', 'EN TRAMOS CARRETEROS DE LOS MUNICIPIOS: (Aeropuerto, Zinapécuaro, Queréndaro, Indaparapeo, Charo y Morelia La Cinta Texticuitzeo).'),
        ],

        'oficios' => [
            'terminos_to' => env('WHATSAPP_OFICIOS_TERMINOS_TO', env('WHATSAPP_SINIESTROS_TO')),
            'terminos_template' => env('WHATSAPP_OFICIOS_TERMINOS_TEMPLATE'),
            'terminos_template_language' => env('WHATSAPP_OFICIOS_TERMINOS_TEMPLATE_LANGUAGE', 'es_MX'),
        ],

        'licencias_puntos' => [
            'enabled' => filter_var(env('WHATSAPP_LICENCIAS_PUNTOS_ENABLED', false), FILTER_VALIDATE_BOOLEAN),
            'notify_deduccion' => filter_var(env('WHATSAPP_LICENCIAS_PUNTOS_NOTIFY_DEDUCCION', true), FILTER_VALIDATE_BOOLEAN),
            'notify_agotamiento' => filter_var(env('WHATSAPP_LICENCIAS_PUNTOS_NOTIFY_AGOTAMIENTO', true), FILTER_VALIDATE_BOOLEAN),
            'deduccion_template' => env('WHATSAPP_LICENCIAS_PUNTOS_DEDUCCION_TEMPLATE', 'licencia_puntos_descuento'),
            'agotamiento_template' => env('WHATSAPP_LICENCIAS_PUNTOS_AGOTAMIENTO_TEMPLATE', 'licencia_puntos_agotamiento'),
            'template_language' => env('WHATSAPP_LICENCIAS_PUNTOS_TEMPLATE_LANGUAGE', 'es_MX'),
        ],

        'todas_unidades' => [
            'to' => env('WHATSAPP_TODAS_UNIDADES_TO'),
            'template' => env('WHATSAPP_TODAS_UNIDADES_TEMPLATE', 'reporte_todas_unidades_diario'),
            'two_part_template_1' => env('WHATSAPP_TODAS_UNIDADES_TEMPLATE_PARTE_1', 'reporte_todas_unidades_parte_1'),
            'two_part_template_2' => env('WHATSAPP_TODAS_UNIDADES_TEMPLATE_PARTE_2', 'reporte_todas_unidades_parte_2'),
            'block_template' => env('WHATSAPP_TODAS_UNIDADES_BLOCK_TEMPLATE', 'reporte_todas_unidades_bloque'),
            'template_layout' => env('WHATSAPP_TODAS_UNIDADES_TEMPLATE_LAYOUT', 'dos_partes'),
            'template_language' => env('WHATSAPP_TODAS_UNIDADES_TEMPLATE_LANGUAGE', 'es_MX'),
            'template_body_max_chars' => (int) env('WHATSAPP_TODAS_UNIDADES_TEMPLATE_BODY_MAX_CHARS', 1024),
            'template_chunk_chars' => (int) env('WHATSAPP_TODAS_UNIDADES_TEMPLATE_CHUNK_CHARS', 850),
            'text_chunk_chars' => (int) env('WHATSAPP_TODAS_UNIDADES_TEXT_CHUNK_CHARS', 3900),
            'two_part_send_delay_seconds' => (int) env('WHATSAPP_TODAS_UNIDADES_TWO_PART_SEND_DELAY_SECONDS', 2),
        ],

        'delegaciones' => [
            'alertas_to' => env('WHATSAPP_DELEGACIONES_ALERTAS_TO'),
            'cortes_to' => env('WHATSAPP_DELEGACIONES_CORTES_TO', env('WHATSAPP_DELEGACIONES_ALERTAS_TO')),
            'cortes_template' => env('WHATSAPP_DELEGACIONES_CORTES_TEMPLATE', 'delegaciones_corte_aseguramientos_v1'),
            'cortes_template_language' => env('WHATSAPP_DELEGACIONES_CORTES_TEMPLATE_LANGUAGE', 'es_MX'),
            'cortes_schedule_times' => array_values(array_filter(array_map('trim', explode(',', env('WHATSAPP_DELEGACIONES_CORTES_SCHEDULE_TIMES', '15:00,20:00,22:00'))))),
            'incompletos_template' => env('WHATSAPP_DELEGACIONES_INCOMPLETOS_TEMPLATE', 'alerta_hecho_incompleto_delegaciones'),
            'incompletos_min_hours' => (int) env('WHATSAPP_DELEGACIONES_INCOMPLETOS_MIN_HOURS', 3),
            'incompletos_lookback_days' => (int) env('WHATSAPP_DELEGACIONES_INCOMPLETOS_LOOKBACK_DAYS', 3),
            'incompletos_notify_delegados' => filter_var(env('WHATSAPP_DELEGACIONES_INCOMPLETOS_NOTIFY_DELEGADOS', true), FILTER_VALIDATE_BOOLEAN),
            'incompletos_delegados_from_users' => filter_var(env('WHATSAPP_DELEGACIONES_INCOMPLETOS_DELEGADOS_FROM_USERS', true), FILTER_VALIDATE_BOOLEAN),
            'incompletos_delegado_roles' => env('WHATSAPP_DELEGACIONES_INCOMPLETOS_DELEGADO_ROLES', 'Delegado'),
            'incompletos_delegados_to' => env('WHATSAPP_DELEGACIONES_INCOMPLETOS_DELEGADOS_TO'),
        ],
    ],

    'openai' => [
        'key' => env('OPENAI_API_KEY'),
    ],

    'bigbluebutton' => [
        'enabled' => filter_var(env('BIGBLUEBUTTON_ENABLED', false), FILTER_VALIDATE_BOOLEAN),
        'url' => env('BIGBLUEBUTTON_URL'),
        'secret' => env('BIGBLUEBUTTON_SECRET'),
        'timeout' => (int) env('BIGBLUEBUTTON_TIMEOUT', 15),
    ],

    'azure_storage' => [
        'account_name' => env('AZURE_STORAGE_NAME'),
        'account_key' => env('AZURE_STORAGE_KEY'),
        'url' => env('AZURE_STORAGE_URL'),
        'oficios_container' => env('AZURE_STORAGE_OFICIOS_CONTAINER', 'oficios'),
        'oficios_enabled' => env('AZURE_STORAGE_OFICIOS_ENABLED',
            env('FILESYSTEM_DISK') === 'azure' || env('FILESYSTEM_DRIVER') === 'azure'
        ),
        'documentos_container' => env('AZURE_STORAGE_DOCUMENTOS_CONTAINER', 'documentos'),
        'documentos_enabled' => env('AZURE_STORAGE_DOCUMENTOS_ENABLED',
            env('AZURE_STORAGE_OFICIOS_ENABLED',
                env('FILESYSTEM_DISK') === 'azure' || env('FILESYSTEM_DRIVER') === 'azure'
            )
        ),
        'croquis_container' => env('AZURE_STORAGE_CROQUIS_CONTAINER', 'croquis'),
        'croquis_enabled' => env('AZURE_STORAGE_CROQUIS_ENABLED',
            env('FILESYSTEM_DISK') === 'azure' || env('FILESYSTEM_DRIVER') === 'azure'
        ),
        'fotos_container' => env('AZURE_STORAGE_FOTOS_CONTAINER', 'fotos'),
        'fotos_enabled' => env('AZURE_STORAGE_FOTOS_ENABLED',
            env('FILESYSTEM_DISK') === 'azure' || env('FILESYSTEM_DRIVER') === 'azure'
        ),
        'hechos_fotos_container' => env('AZURE_STORAGE_HECHOS_FOTOS_CONTAINER', 'hechos-fotos'),
        'hechos_fotos_enabled' => env('AZURE_STORAGE_HECHOS_FOTOS_ENABLED',
            env('AZURE_STORAGE_FOTOS_ENABLED',
                env('FILESYSTEM_DISK') === 'azure' || env('FILESYSTEM_DRIVER') === 'azure'
            )
        ),
    ],
];
