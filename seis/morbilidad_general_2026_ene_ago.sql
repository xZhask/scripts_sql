-- =============================================================================
-- MORBILIDAD GENERAL ENERO - AGOSTO 2026 (DETALLE, PARA CRUCE CON SIGESAPOL)
-- Base de Datos: SEIS (sgcoresys / db_seis_marzo26)
-- Columnas: ID_ATENCION, DNI, TIPO_ATENCION, FECHA_ATENCION, CIE10,
--           DESCRIPCION_CIE10, ID_UPS, DESCRIPCION_UPS, ID_IPRESS, DESCRIPCION_IPRESS
--
-- Propósito: extraer el detalle (1 fila por atención con diagnóstico definitivo)
-- del periodo 202601-202608 para cruzarlo contra la BD PostgreSQL
-- "sigesapol_agosto" del mismo periodo, deduplicar por DNI/fecha/diagnóstico
-- y obtener la morbilidad general consolidada.
--
-- NOTA (validado 2026-09-05): la BD db_seis_marzo26 solo tiene data cargada
-- hasta ID_PERIODO = 202604 (abril). Los periodos 202605-202608 devolverán
-- 0 filas hasta que se migre esa data. Dejar la consulta lista para
-- ejecutarla en Adminer cuando la carga llegue hasta agosto.
--
-- Se excluye el HOSPITAL NACIONAL PNP LUIS N. SAENZ (codigo '00013591') de
-- los reportes por indicación expresa del usuario. No aparece en la carga
-- actual de SEIS (validado 2026-09-05: 0 filas para ese ID_IPRESS), pero se
-- deja el filtro explícito por si empieza a reportar aquí más adelante.
-- =============================================================================

SELECT
    a.id_atencion AS ID_ATENCION,
    p.documento AS DNI,

    CASE a.ID_TIPO_ATENCION
        WHEN 'AM' THEN 'AMBULATORIA'
        WHEN 'EM' THEN 'EMERGENCIA'
        WHEN 'HO' THEN 'HOSPITALIZACIÓN'
        ELSE a.ID_TIPO_ATENCION
    END AS TIPO_ATENCION,

    a.FECHA_ATENCION,

    dx.CodigoDiagnostico AS CIE10,

    CONVERT(
        BINARY(CONVERT(dx.nombre USING latin1))
        USING utf8mb4
    ) AS DESCRIPCION_CIE10,

    a.ID_UPS,
    CONVERT(
        BINARY(CONVERT(u.NOMBRE USING latin1))
        USING utf8mb4
    ) AS DESCRIPCION_UPS,

    a.ID_IPRESS,
    CONVERT(
        BINARY(CONVERT(s.DESCRIPCIONLOCAL USING latin1))
        USING utf8mb4
    ) AS DESCRIPCION_IPRESS

FROM atencion a

INNER JOIN atencion_diagnostico ad
    ON a.id_atencion = ad.id_atencion

INNER JOIN ss_ge_diagnostico dx
    ON dx.idDiagnostico = ad.id_diagnostico

INNER JOIN personamast p
    ON p.persona = a.paciente_id

LEFT JOIN ups u
    ON u.CODIGOUPS = a.ID_UPS

LEFT JOIN ac_sucursal s
    ON s.SUCURSAL = a.ID_IPRESS

WHERE a.ID_PERIODO BETWEEN '202601' AND '202608'
  AND a.FECHA_ATENCION >= '2026-01-01 00:00:00'
  AND a.FECHA_ATENCION <= '2026-08-31 23:59:59'
  AND a.id_tipo_atencion IN ('AM', 'EM', 'HO')
  AND a.ESTADO = 'A'
  AND ad.id_secuencia = 1
  AND ad.id_tipo_diagnostico = '02'
  AND dx.CodigoDiagnostico NOT LIKE 'Z%'
  -- Quitar el filtro anterior (comentar la línea de arriba) si se requieren
  -- también los diagnósticos de tamizaje/administrativos (código Z) en el cruce.
  AND a.ID_IPRESS <> '00013591'  -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ

ORDER BY a.FECHA_ATENCION;
