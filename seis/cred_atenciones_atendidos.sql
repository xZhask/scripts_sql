-- =============================================================================
-- CRED (Control de Crecimiento y Desarrollo) — ATENCIONES Y ATENDIDOS
-- Base: bdseis_agosto26 (MariaDB, sistema SEIS)
-- Periodo de referencia del análisis: 2025-01 a 2026-09
--
-- -----------------------------------------------------------------------------
-- HALLAZGO PRINCIPAL: **NO EXISTE UNA UPS DE CRED**. No se puede filtrar por UPS.
-- -----------------------------------------------------------------------------
-- 1) El catálogo maestro `ups` (500 filas, catálogo MINSA de UPSS/UPS) NO tiene
--    ninguna entrada de Crecimiento y Desarrollo, ni de Estimulación Temprana.
--    El bloque 22xxxx (Consulta Externa) salta de PEDIATRÍA GENERAL (224700) a
--    las subespecialidades pediátricas, sin CRED. El bloque 26xxxx (Estrategias
--    Sanitarias) tampoco lo incluye.
--
-- 2) El catálogo legado `tablaz` SÍ tiene el código UPSS148 = 'CRECIMIENTO Y
--    DESARROLLO', pero está en ESTADO='I' (inactivo, migración 2015) y tiene
--    **CERO atenciones en toda la historia de la tabla `atencion`**. Es letra
--    muerta: no sirve para filtrar.
--
-- 3) Las atenciones de CRED se registran bajo UPS genéricas de nivel raíz:
--         UPS 260000 ESTRATEGIAS SANITARIAS NACIONALES  3,009 at (63.9%)
--         UPS 260300 ESTRAT.SANIT.NAC.-INMUNIZACIONES   1,087 at (23.1%)
--         UPS 220000 CONSULTA EXTERNA                     581 at (12.3%)
--         + residuos en 230200, 160000, 224700, 260800, 222400 y un '26000' mal
--           tipeado que ni siquiera existe en el catálogo.
--    Filtrar por esas 3 UPS traería **114,533 atenciones para quedarse con
--    4,677**: 96% de ruido. La UPS NO identifica el servicio.
--
-- -----------------------------------------------------------------------------
-- CÓMO SÍ SE IDENTIFICA CRED: POR CÓDIGO DE PROCEDIMIENTO (CPMS/CPT)
-- -----------------------------------------------------------------------------
-- El catálogo `ss_ge_procedimientomedico` nombra CRED de forma explícita:
--    99381     Atención Integral de Salud del Niño-CRED menor de 1 año   2,249 at
--    99382     Atención integral de salud del niño-CRED de 1 a 4 años    2,469 at
--    99381.01  Atención Integral de Salud del Niño-CRED neonato              0 at
--    99383     Atención Integral de Salud del Niño-CRED de 5 a 11 años       0 at
--
-- 99381.01 y 99383 se dejan en el filtro por si empiezan a usarse, pero HOY
-- están en cero. Ver la sección de OJO al final: el CRED escolar (5-11) no se
-- está registrando con su código.
--
-- Validación de coherencia clínica (edad del paciente vs. rango del código):
--    99381 (<1 año) : 2,249 at, solo 28 con edad > 1  (1.2% fuera de rango)
--    99382 (1-4)    : 2,469 at, solo 91 con edad > 4  (3.7% fuera de rango)
--    Distribución: edad 0 → 2,182 | 1 → 1,243 | 2 → 581 | 3 → 360 | 4 → 255,
--    y una cola corta de errores de digitación (edades 28, 31, 42, 101).
--    Los códigos se están usando bien. El filtro es confiable.
--
-- La vía diagnóstica NO funciona: Z00.1 (Control de salud de rutina del niño),
-- Z00.2 y Z76.2 devuelven **cero** atenciones en 2025-2026. No se diagnostica
-- el CRED con CIE-10 en este sistema.
--
-- -----------------------------------------------------------------------------
-- CÓDIGOS DE BORDE — decisión normativa, NO incluidos por defecto
-- -----------------------------------------------------------------------------
-- Estos son actividades afines. Se midió si ocurren DENTRO de la misma atención
-- de CRED o si son atenciones aparte:
--    99401.05 Consejería en atención temprana del desarrollo   3,991 at → 93%
--             comparten atención con 99381/99382
--    99401.06 Consejería en importancia del control de CRED      719 at → 84%
--             comparten atención con 99381/99382
--    96111    Pruebas de desarrollo                            1,300 at → 56%
--             comparten. PERO edad promedio 14.7 años (máx 77): NO es
--             pediátrico en la práctica. No usar para CRED.
--    99411.01 Atención Temprana del Desarrollo                     17 at → 0%
--             comparten. Es estimulación temprana, servicio distinto.
--
-- Como 99401.05/.06 son componentes de la misma visita en 84-93% de los casos,
-- agregarlos apenas mueve el conteo de ATENCIONES pero sí duplicaría si se
-- contara a nivel de procedimiento. Por eso el núcleo es 9938x.
-- Para incluirlas, descomentar la línea marcada como AMPLIADO.
--
-- -----------------------------------------------------------------------------
-- FILTROS OBLIGATORIOS
-- -----------------------------------------------------------------------------
--   a.ID_TIPO_ATENCION = 'PR'      -> el 100% de las CRED son tipo PR
--                                     (procedimiento). NO son 'AM'.
--   ad.ID_TIPO_DETALLE = 'PRO'     -> el CPT vive en el detalle de procedimientos
--   a.ESTADO = 'A'                 -> descarta 1,411 atenciones anuladas
--
-- ATENCIONES = COUNT(DISTINCT a.id_atencion)
-- ATENDIDOS  = COUNT(DISTINCT a.PACIENTE_ID)   (paciente único en el periodo)
-- =============================================================================

-- === PARÁMETROS: ajustar el periodo aquí ====================================
SET @PERIODO_INI = '202501';   -- YYYYMM inclusive
SET @PERIODO_FIN = '202612';   -- YYYYMM inclusive

-- =============================================================================
-- BLOQUE 1 · RESUMEN POR IPRESS Y NIVEL
-- =============================================================================
SELECT
    a.ID_IPRESS                                   AS IPRESS,
    s.DESCRIPCIONLOCAL                            AS NOMBRE_IPRESS,
    CASE WHEN a.ID_IPRESS IN ('00011794','00014718','00016094','00011833')
         THEN 'NIVEL II' ELSE 'NIVEL I' END       AS NIVEL_IPRESS,
    COUNT(DISTINCT a.id_atencion)                 AS CANTIDAD_DE_ATENCIONES,
    COUNT(DISTINCT a.PACIENTE_ID)                 AS CANTIDAD_DE_ATENDIDOS
FROM atencion a
INNER JOIN atencion_diagnostico ad
        ON ad.ID_ATENCION = a.id_atencion
       AND ad.ID_TIPO_DETALLE = 'PRO'
LEFT  JOIN ac_sucursal s
        ON TRIM(s.SUCURSAL) = TRIM(a.ID_IPRESS)
WHERE a.ID_PERIODO BETWEEN @PERIODO_INI AND @PERIODO_FIN
  AND a.ID_TIPO_ATENCION = 'PR'
  AND a.ESTADO = 'A'
  AND ad.ID_CPT IN ('99381','99381.01','99382','99383')
  -- AMPLIADO: para sumar consejerías, usar en su lugar:
  -- AND ad.ID_CPT IN ('99381','99381.01','99382','99383','99401.05','99401.06')
GROUP BY a.ID_IPRESS, s.DESCRIPCIONLOCAL, NIVEL_IPRESS
ORDER BY CANTIDAD_DE_ATENCIONES DESC;

-- =============================================================================
-- BLOQUE 2 · RESUMEN POR MES Y GRUPO ETARIO (el código CPT ya es el grupo etario)
-- =============================================================================
SELECT
    a.ID_PERIODO                                  AS PERIODO,
    ad.ID_CPT                                     AS CPT,
    pm.NOMBRE                                     AS DESCRIPCION_CPT,
    COUNT(DISTINCT a.id_atencion)                 AS CANTIDAD_DE_ATENCIONES,
    COUNT(DISTINCT a.PACIENTE_ID)                 AS CANTIDAD_DE_ATENDIDOS
FROM atencion a
INNER JOIN atencion_diagnostico ad
        ON ad.ID_ATENCION = a.id_atencion
       AND ad.ID_TIPO_DETALLE = 'PRO'
LEFT  JOIN ss_ge_procedimientomedico pm
        ON pm.CODIGOPROCEDIMIENTO = ad.ID_CPT
WHERE a.ID_PERIODO BETWEEN @PERIODO_INI AND @PERIODO_FIN
  AND a.ID_TIPO_ATENCION = 'PR'
  AND a.ESTADO = 'A'
  AND ad.ID_CPT IN ('99381','99381.01','99382','99383')
GROUP BY a.ID_PERIODO, ad.ID_CPT, pm.NOMBRE
ORDER BY a.ID_PERIODO, ad.ID_CPT;

-- =============================================================================
-- BLOQUE 3 · DETALLE PACIENTE A PACIENTE (para auditoría / cruce con SIGESAPOL)
-- =============================================================================
SELECT
    a.ID_IPRESS                                   AS IPRESS,
    s.DESCRIPCIONLOCAL                            AS NOMBRE_IPRESS,
    p.documento                                   AS DNI,
    p.NOMBRECOMPLETO                              AS NOMBRE_PACIENTE,
    a.PACIENTE_EDAD                               AS EDAD,
    DATE(a.FECHA_ATENCION)                        AS FECHA_ATENCION,
    a.id_atencion                                 AS ID_ATENCION,
    ad.ID_CPT                                     AS CPT,
    pm.NOMBRE                                     AS DESCRIPCION_CPT,
    a.ID_UPS                                      AS ID_UPS,
    u.NOMBRE                                      AS UPS_DESCRIPCION
FROM atencion a
INNER JOIN atencion_diagnostico ad
        ON ad.ID_ATENCION = a.id_atencion
       AND ad.ID_TIPO_DETALLE = 'PRO'
LEFT  JOIN ac_sucursal s ON TRIM(s.SUCURSAL) = TRIM(a.ID_IPRESS)
LEFT  JOIN personamast p ON p.PERSONA = a.PACIENTE_ID
LEFT  JOIN ss_ge_procedimientomedico pm ON pm.CODIGOPROCEDIMIENTO = ad.ID_CPT
LEFT  JOIN ups u ON u.CODIGOUPS = a.ID_UPS
WHERE a.ID_PERIODO BETWEEN @PERIODO_INI AND @PERIODO_FIN
  AND a.ID_TIPO_ATENCION = 'PR'
  AND a.ESTADO = 'A'
  AND ad.ID_CPT IN ('99381','99381.01','99382','99383')
ORDER BY a.ID_IPRESS, a.FECHA_ATENCION;

-- =============================================================================
-- OJO — DOS COSAS QUE CONVIENE ADVERTIR EN EL REPORTE
-- =============================================================================
-- 1) CRED ESCOLAR AUSENTE. El código 99383 (CRED de 5 a 11 años) tiene CERO
--    registros, y sin embargo hay 83 atenciones de niños de 5 a 11 años
--    codificadas como 99382 (que es "1 a 4 años"). El CRED escolar existe pero
--    se está registrando con el código equivocado. Si el reporte se abre por
--    grupo etario, esa franja va a salir vacía o mal asignada.
--
-- 2) COBERTURA GEOGRÁFICA. Solo 21 IPRESS registran CRED en 2025-2026, y el
--    grueso está en provincias (Chiclayo 1,257 · Leguía 1,121 · Huancayo 482 ·
--    Andahuaylas 368 · Huánuco 362). Ausentes casi todos los policlínicos de
--    Lima que sí aparecen con alto volumen en otros servicios. Antes de leer
--    esto como "no hay CRED en Lima", confirmar si esas IPRESS lo registran en
--    SIGESAPOL — el SEIS se está dejando de usar progresivamente y el volumen
--    2026 cae a ~1/4 del de 2025 por la migración, no por menos actividad.
-- =============================================================================
