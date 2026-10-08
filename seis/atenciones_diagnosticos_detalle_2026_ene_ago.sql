-- =============================================================================
-- DETALLE DE ATENCIONES CON TODOS SUS DIAGNÓSTICOS · ENERO - AGOSTO 2026
-- Base: bdseis_agosto26 (SEIS)
--
-- Salida: 1 fila por (atención, diagnóstico). Una atención con 3 diagnósticos
-- sale en 3 filas, con DX_SECUENCIA 1, 2 y 3.
--
-- A diferencia de morbilidad_general_2026_ene_ago.sql (solo diagnóstico
-- principal definitivo, sin códigos Z), aquí van TODOS los diagnósticos de la
-- atención, de cualquier tipo (presuntivo, definitivo, repetido o sin tipo) e
-- incluidos los Z. Sirve para comparar números de documento contra SIGESAPOL
-- y para contar atenciones y atendidos.
--
-- Cómo contar sobre el resultado:
--   - ATENCIONES = COUNT(DISTINCT ID_ATENCION), o las filas con
--                  DX_SECUENCIA = 1 (cada atención tiene exactamente una).
--   - ATENDIDOS  = COUNT(DISTINCT NRO_DOCUMENTO). Hay personas registradas dos
--                  veces con el mismo documento y distinto NUMHIJO; contar por
--                  documento las une. Si se cuenta por PACIENTE_ID sale algo
--                  más alto.
--
-- Criterios:
--   - Tipos de atención AM (ambulatoria), EM (emergencia) y HO
--     (hospitalización), ESTADO = 'A'.
--   - Fecha de atención entre 2026-01-01 y 2026-08-31. Se filtra también por
--     ID_PERIODO para usar el índice atencion_idx_01. Hay 18 atenciones con
--     periodo 2026-01..08 pero fecha fuera del rango, que quedan fuera.
--   - Solo diagnósticos (ID_TIPO_DETALLE = 'DIA'); los procedimientos
--     ('PRO'/'QUI') no se traen.
--   - Solo IPRESS de nivel I y II: se excluye el HOSPITAL NACIONAL PNP LUIS N.
--     SAENZ (00013591, nivel III). Nivel II = 00011794 Arequipa, 00014718
--     Geriátrico San José, 00016094 Augusto B. Leguía, 00011833 Chiclayo; el
--     resto es nivel I. No se usa ac_sucursal.nivel porque está vacío en la
--     mayoría de IPRESS.
--
-- Médico responsable (atencion_responsable):
--   - AM y HO tienen un responsable 'RESP'.
--   - EM no tiene 'RESP': se toma el médico de ingreso 'INGR'.
--   - TIPO_RESPONSABLE indica cuál se usó.
--
-- Campos del paciente:
--   - TIPO_BENEFICIARIO (titular, cónyuge, hijo, padre...) sale de
--     personamast.ID_BENEFICIARIO, es decir, el dato actual del paciente, no
--     una foto a la fecha de la atención.
--   - EDAD, SITUACION y FINANCIADOR sí son los registrados en la atención.
--   - CONDICION_ESTABLECIMIENTO / CONDICION_SERVICIO: nuevo, continuador o
--     reingresante, como lo calcula SEIS.
--
-- Validado (2026-10-07) contra bdseis_agosto26 (~17 s):
--   172,405 filas | 127,751 atenciones | 43,273 atendidos por documento
--   (43,689 por PACIENTE_ID) | 71 IPRESS.
--   AM 114,231 | EM 11,323 | HO 2,197.  Nivel I 39,573 | Nivel II 88,178.
--   Diagnósticos: definitivo 153,078 | presuntivo 12,590 | repetido 6,733 |
--   sin tipo 4; 24,065 son códigos Z.
--   Todas las atenciones tienen médico y al menos un diagnóstico. 35 pacientes
--   sin tipo de beneficiario. Mayo-agosto llega con menos volumen (14.8k a
--   8.6k atenciones/mes vs ~20k de ene-abr) por la migración a SIGESAPOL.
-- =============================================================================

SELECT
    a.id_atencion                                   AS ID_ATENCION,
    a.ID_PERIODO                                    AS PERIODO,
    DATE(a.FECHA_ATENCION)                          AS FECHA_ATENCION,
    a.ID_TIPO_ATENCION                              AS ID_TIPO_ATENCION,
    CASE a.ID_TIPO_ATENCION
        WHEN 'AM' THEN 'AMBULATORIA'
        WHEN 'EM' THEN 'EMERGENCIA'
        WHEN 'HO' THEN 'HOSPITALIZACIÓN'
    END                                             AS TIPO_ATENCION,

    -- IPRESS y UPS
    a.ID_IPRESS                                     AS ID_IPRESS,
    TRIM(s.DESCRIPCIONLOCAL)                        AS IPRESS,
    CASE
        WHEN a.ID_IPRESS IN ('00011794','00014718','00016094','00011833') THEN 'II'
        ELSE 'I'
    END                                             AS NIVEL_IPRESS,
    a.ID_UPS                                        AS ID_UPS,
    u.NOMBRE                                        AS UPS,

    -- Paciente
    a.PACIENTE_ID                                   AS PACIENTE_ID,
    p.TIPODOCUMENTO                                 AS TIPO_DOCUMENTO,
    p.documento                                     AS NRO_DOCUMENTO,
    p.NOMBRECOMPLETO                                AS PACIENTE,
    p.SEXO                                          AS SEXO,
    a.PACIENTE_EDAD                                 AS EDAD,
    ge.DESCRIPCIONLOCAL                             AS GRUPO_EDAD,
    p.ID_BENEFICIARIO                               AS ID_TIPO_BENEFICIARIO,
    be.DESCRIPCIONLOCAL                             AS TIPO_BENEFICIARIO,
    si.DESCRIPCIONLOCAL                             AS SITUACION,
    fi.DESCRIPCIONLOCAL                             AS FINANCIADOR,
    ce.DESCRIPCIONLOCAL                             AS CONDICION_ESTABLECIMIENTO,
    cs.DESCRIPCIONLOCAL                             AS CONDICION_SERVICIO,

    -- Médico responsable
    CASE WHEN rr.ID_EMPLEADO IS NOT NULL THEN 'RESP'
         WHEN ri.ID_EMPLEADO IS NOT NULL THEN 'INGR'
    END                                             AS TIPO_RESPONSABLE,
    m.documento                                     AS DNI_MEDICO,
    m.NOMBRECOMPLETO                                AS MEDICO,
    pr.DESCRIPCIONLOCAL                             AS PROFESION_MEDICO,
    es.DESCRIPCIONLOCAL                             AS ESPECIALIDAD_MEDICO,
    m.NUMERO_COLEGIATURA                            AS COLEGIATURA,

    -- Diagnóstico
    ad.ID_SECUENCIA                                 AS DX_SECUENCIA,
    dx.CodigoDiagnostico                            AS CIE10,
    dx.Nombre                                       AS DESCRIPCION_CIE10,
    CASE ad.ID_TIPO_DIAGNOSTICO
        WHEN '01' THEN 'PRESUNTIVO'
        WHEN '02' THEN 'DEFINITIVO'
        WHEN '03' THEN 'REPETIDO'
        ELSE 'SIN TIPO'
    END                                             AS TIPO_DIAGNOSTICO

FROM atencion a

INNER JOIN atencion_diagnostico ad
    ON  ad.ID_ATENCION     = a.id_atencion
    AND ad.ID_TIPO_DETALLE = 'DIA'

INNER JOIN ss_ge_diagnostico dx
    ON dx.IdDiagnostico = ad.ID_DIAGNOSTICO

INNER JOIN personamast p
    ON p.PERSONA = a.PACIENTE_ID

LEFT JOIN ac_sucursal s
    ON s.SUCURSAL = a.ID_IPRESS

LEFT JOIN ups u
    ON u.CODIGOUPS = a.ID_UPS

-- Médico: RESP (AM, HO) o, si no hay, INGR (EM)
LEFT JOIN atencion_responsable rr
    ON  rr.ID_ATENCION         = a.id_atencion
    AND rr.ID_TIPO_RESPONSABLE = 'RESP'
LEFT JOIN atencion_responsable ri
    ON  ri.ID_ATENCION         = a.id_atencion
    AND ri.ID_TIPO_RESPONSABLE = 'INGR'
LEFT JOIN personamast m
    ON m.PERSONA = COALESCE(rr.ID_EMPLEADO, ri.ID_EMPLEADO)

-- Catálogos (ma_miscelaneosdetalle es único por CODIGOTABLA + CODIGOELEMENTO)
LEFT JOIN ma_miscelaneosdetalle be
    ON be.CODIGOTABLA = 'BENEFIC'    AND be.CODIGOELEMENTO = p.ID_BENEFICIARIO
LEFT JOIN ma_miscelaneosdetalle si
    ON si.CODIGOTABLA = 'SITUACION'  AND si.CODIGOELEMENTO = a.PACIENTE_ID_SITUACION
LEFT JOIN ma_miscelaneosdetalle fi
    ON fi.CODIGOTABLA = 'FINAN'      AND fi.CODIGOELEMENTO = a.PACIENTE_ID_FINANCIADOR
LEFT JOIN ma_miscelaneosdetalle ge
    ON ge.CODIGOTABLA = 'GRUPOEDAD'  AND ge.CODIGOELEMENTO = a.codigo_edad
LEFT JOIN ma_miscelaneosdetalle ce
    ON ce.CODIGOTABLA = 'CONDESTAB'  AND ce.CODIGOELEMENTO = a.PACIENTE_CONDICION_ESTABLECIMIENTO
LEFT JOIN ma_miscelaneosdetalle cs
    ON cs.CODIGOTABLA = 'CONDSERVI'  AND cs.CODIGOELEMENTO = a.PACIENTE_CONDICION_SERVICIO
LEFT JOIN ma_miscelaneosdetalle pr
    ON pr.CODIGOTABLA = 'PROFE-PNP'  AND pr.CODIGOELEMENTO = m.ID_PROFESION
LEFT JOIN ma_miscelaneosdetalle es
    ON es.CODIGOTABLA = 'ESPEC-PNP'  AND es.CODIGOELEMENTO = m.ID_ESPECIALIDAD

WHERE a.ID_TIPO_ATENCION IN ('AM', 'EM', 'HO')
  AND a.ID_PERIODO BETWEEN '202601' AND '202608'
  AND a.FECHA_ATENCION >= '2026-01-01'
  AND a.FECHA_ATENCION <  '2026-09-01'
  AND a.ESTADO = 'A'
  AND a.ID_IPRESS <> '00013591'  -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ (nivel III)

ORDER BY a.FECHA_ATENCION, a.id_atencion, ad.ID_SECUENCIA;
