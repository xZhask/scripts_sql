-- =============================================================================
-- FUENTE 1 · SEIS · EGRESOS HOSPITALARIOS · OCTUBRE 2026
-- Base: SEIS actualizada (la copia local bdseis_agosto26 corta el 2026-09-03
--       y NO sirve para octubre; correr en Adminer sobre la base vigente).
--
-- Salida: 1 fila por atención de hospitalización con alta. Columnas IDÉNTICAS
-- a 02_sigesapol_egresos_oct_2026.sql para cruzarlas con 03_cruce_egresos.py.
-- Exportar desde Adminer como CSV (con cabecera) a:
--   datos/extraccion_seis_egresos_oct_2026.csv
--
-- Criterio (replica el reporte "Egresos Hospitalarios" de la app SEIS,
-- validado con agosto 2026: 31 San José + 226 Leguía = 257, idéntico):
--   - ID_TIPO_ATENCION = 'HO', ESTADO = 'A'.
--   - Se cuenta por FECHA DE ALTA, no por ID_PERIODO: entran atenciones de
--     periodos anteriores dadas de alta en el mes.
--   - Solo IPRESS de nivel I y II: se excluye el HOSPITAL NACIONAL PNP LUIS N.
--     SAENZ (00013591, nivel III).
--
-- ⚠ La ventana es más amplia que el mes (24-sep a 07-nov) A PROPÓSITO: la
--   misma estancia puede tener en SIGESAPOL un alta 1 a 3 días distinta
--   (medido en agosto). El script de cruce empareja con margen y recién
--   después se queda con las altas de octubre. Para el conteo SEIS "puro" del
--   mes, filtrar FECHA_ALTA entre 2026-10-01 y 2026-10-31.
-- =============================================================================

SELECT
    'SEIS'                                                      AS FUENTE,
    a.id_atencion                                               AS ID_ATENCION,
    a.ID_IPRESS                                                 AS CODIGO_IPRESS,
    TRIM(s.DESCRIPCIONLOCAL)                                    AS IPRESS,
    TRIM(p.documento)                                           AS DNI,
    TRIM(p.NOMBRECOMPLETO)                                      AS PACIENTE,
    p.SEXO                                                      AS SEXO,
    TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO,
                  DATE(a.HOSPITALIZACION_INGRESO_FECHA_HORA))   AS EDAD,
    DATE_FORMAT(a.HOSPITALIZACION_INGRESO_FECHA_HORA, '%Y-%m-%d %H:%i') AS FECHA_INGRESO,
    DATE_FORMAT(a.HOSPITALIZACION_ALTA_FECHA_HORA,    '%Y-%m-%d %H:%i') AS FECHA_ALTA,
    a.HOSPITALIZACION_ALTA_DIAS_ESTANCIA                        AS DIAS_ESTANCIA,
    a.ID_UPS                                                    AS CODIGO_SERVICIO,
    u.NOMBRE                                                    AS SERVICIO,
    a.HOSPITALIZACION_ALTA_ID_MOTIVO                            AS MOTIVO_ALTA,
    a.ID_PERIODO                                                AS PERIODO_ORIGEN
FROM atencion a
LEFT JOIN personamast p ON p.PERSONA   = a.PACIENTE_ID
LEFT JOIN ac_sucursal s ON s.SUCURSAL  = a.ID_IPRESS
LEFT JOIN ups u         ON u.CODIGOUPS = a.ID_UPS
WHERE a.ID_TIPO_ATENCION = 'HO'
  AND a.ESTADO = 'A'
  AND a.ID_IPRESS <> '00013591'                  -- regla: sin Hosp. Luis N. Sáenz (nivel III)
  AND a.HOSPITALIZACION_ALTA_FECHA_HORA >= '2026-09-24'
  AND a.HOSPITALIZACION_ALTA_FECHA_HORA <  '2026-11-08'
ORDER BY a.ID_IPRESS, a.HOSPITALIZACION_ALTA_FECHA_HORA, a.id_atencion;
