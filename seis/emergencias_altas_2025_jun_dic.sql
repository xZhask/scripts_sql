-- =============================================================================
-- SEIS · EMERGENCIAS CON ALTA Y PENDIENTES DE ALTA · JUNIO - DICIEMBRE 2025
-- Base: seis_setiembre26 (MySQL 8.4, puerto 3306)
--
-- Salida: 1 fila por atención de emergencia, sin DNI ni nombre del paciente.
-- La ejecuta emergencias_altas_resumen.py, que genera los cuadros resumen.
--
-- Criterios:
--   - ID_TIPO_ATENCION = 'EM', ESTADO = 'A'.
--   - FECHA_ATENCION entre 2025-06-01 y 2025-12-31. ID_PERIODO se amplía un mes
--     a cada lado para usar atencion_idx_01 sin perder las atenciones con
--     periodo distinto al mes de la fecha.
--   - Luis N. Sáenz (00013591) no tiene emergencias en este periodo en SEIS.
--
-- Dónde están las fechas:
--   - Ingreso: EMERGENCIA_INGRESO_FECHA_HORA (igual a FECHA_ATENCION).
--   - Alta:    EMERGENCIA_ALTA_FECHA_HORA. Sin fecha = PENDIENTE.
--
-- Tiempo entre ingreso y alta:
--   - DIAS_TRANSCURRIDOS: tiempo real en días (12 horas = 0.5).
--   - DIAS_CALENDARIO:    cambios de fecha (23:50 a 00:10 del día siguiente = 1).
--
-- CALIDAD_ESTANCIA (los promedios usan solo VALIDA):
--   - VALIDA:             alta posterior al ingreso, hasta 30 días después.
--   - ALTA_IGUAL_INGRESO: 0 minutos; parece carga posterior, no tiempo real.
--   - FECHA_FUTURA:       alta posterior a 2026-11-05 (año mal digitado).
--   - MAYOR_30_DIAS:      criterio de corte, posible error; no verificado.
--   - PENDIENTE:          sin fecha de alta.
--   - ALTA_ANTES_INGRESO: control; no hay ningún caso en este periodo.
--
-- Validado (2026-11-05) contra seis_setiembre26:
--   33,521 emergencias = 33,245 con alta + 276 pendientes.
--   VALIDA 30,715 | ALTA_IGUAL_INGRESO 2,494 | FECHA_FUTURA 18 | MAYOR_30_DIAS 18.
--   Estancia válida: promedio 103.7 min (1.73 h, 0.072 días), mediana 20 min,
--   percentil 90 138 min.
-- =============================================================================

SELECT
    a.id_atencion                                   AS ID_ATENCION,
    DATE_FORMAT(a.FECHA_ATENCION, '%Y%m')           AS PERIODO,
    a.EMERGENCIA_INGRESO_FECHA_HORA                 AS FECHA_INGRESO,
    a.EMERGENCIA_ALTA_FECHA_HORA                    AS FECHA_ALTA,
    a.ID_IPRESS                                     AS CODIGO_IPRESS,
    TRIM(s.DESCRIPCIONLOCAL)                        AS IPRESS,
    CASE WHEN a.ID_IPRESS IN ('00011794', '00014718', '00016094', '00011833')
         THEN 'II' ELSE 'I' END                     AS NIVEL,
    pr.DESCRIPCIONLOCAL                             AS PRIORIDAD,
    CASE WHEN a.EMERGENCIA_ALTA_FECHA_HORA IS NULL
         THEN 'PENDIENTE' ELSE 'CON ALTA' END       AS ESTADO_ALTA,
    co.DESCRIPCIONLOCAL                             AS CONDICION_ALTA,
    TIMESTAMPDIFF(MINUTE, a.EMERGENCIA_INGRESO_FECHA_HORA, a.EMERGENCIA_ALTA_FECHA_HORA)
                                                    AS MINUTOS,
    ROUND(TIMESTAMPDIFF(MINUTE, a.EMERGENCIA_INGRESO_FECHA_HORA, a.EMERGENCIA_ALTA_FECHA_HORA) / 1440, 3)
                                                    AS DIAS_TRANSCURRIDOS,
    DATEDIFF(a.EMERGENCIA_ALTA_FECHA_HORA, a.EMERGENCIA_INGRESO_FECHA_HORA)
                                                    AS DIAS_CALENDARIO,
    CASE
        WHEN a.EMERGENCIA_ALTA_FECHA_HORA IS NULL THEN 'PENDIENTE'
        WHEN a.EMERGENCIA_ALTA_FECHA_HORA > '2026-11-05' THEN 'FECHA_FUTURA'
        WHEN a.EMERGENCIA_ALTA_FECHA_HORA = a.EMERGENCIA_INGRESO_FECHA_HORA THEN 'ALTA_IGUAL_INGRESO'
        WHEN a.EMERGENCIA_ALTA_FECHA_HORA > DATE_ADD(a.EMERGENCIA_INGRESO_FECHA_HORA, INTERVAL 30 DAY) THEN 'MAYOR_30_DIAS'
        WHEN a.EMERGENCIA_ALTA_FECHA_HORA < a.EMERGENCIA_INGRESO_FECHA_HORA THEN 'ALTA_ANTES_INGRESO'
        ELSE 'VALIDA'
    END                                             AS CALIDAD_ESTANCIA

FROM atencion a

LEFT JOIN ac_sucursal s
    ON s.SUCURSAL = a.ID_IPRESS

LEFT JOIN ma_miscelaneosdetalle pr
    ON pr.CODIGOTABLA = 'PRIORIDAD' AND pr.CODIGOELEMENTO = a.EMERGENCIA_INGRESO_ID_PRIORIDAD

LEFT JOIN ma_miscelaneosdetalle co
    ON co.CODIGOTABLA = 'CONDICION' AND co.CODIGOELEMENTO = a.EMERGENCIA_ALTA_ID_CONDICION

WHERE a.ID_TIPO_ATENCION = 'EM'
  AND a.ID_PERIODO BETWEEN '202505' AND '202601'
  AND a.FECHA_ATENCION >= '2025-06-01'
  AND a.FECHA_ATENCION <  '2026-01-01'
  AND a.ESTADO = 'A'

ORDER BY a.FECHA_ATENCION, a.id_atencion;
