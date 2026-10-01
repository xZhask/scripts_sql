-- =============================================================================
-- EXTRACCIÓN SGCORESYS · ENERO A AGOSTO 2026
-- Para ejecutar en Adminer (web) contra la instancia de PRODUCCIÓN de sgcoresys,
-- ya que la copia local aún no está restaurada.
--
-- Objetivo: obtener una fila por (atención, diagnóstico principal) lista para
-- cruzar/deduplicar contra el export de sigesapol_agosto (PostgreSQL) por
-- MISMO DÍA + MISMO IPRESS + MISMO CONSULTORIO (código o descripción) +
-- MISMO DNI. Esa deduplicación y el cálculo final de "atenciones y atendidos
-- por nivel, tipo de atención y CIE10" se hace en un paso posterior (Python/
-- Excel), una vez tengamos también el export del lado sigesapol.
--
-- Sin CTE / sin window functions a propósito, por compatibilidad con
-- versiones de MariaDB/MySQL más antiguas que puedan estar en producción.
--
-- Criterios (consistentes con morbilidad_agrupada.sql de este repo y con
-- top10_morbilidad.sql del lado sigesapol):
--   - a.ESTADO = 'A'
--   - ad.id_secuencia = 1           -> diagnóstico principal de la atención
--   - ad.id_tipo_diagnostico = '02' -> diagnóstico definitivo
--   - dx.CodigoDiagnostico NOT LIKE 'Z%' (igual que sigesapol: dx.codigo NOT LIKE 'Z%')
--   - Solo atenciones AM (ambulatoria), EM (emergencia), HO (hospitalización)
--   - Periodo: 2026-01-01 a 2026-08-31
--
-- Claves para el cruce con sigesapol_agosto:
--   DNI            <-> asegurados.nro_doc_ident
--   FECHA_ATENCION <-> prestaciones.fecha_atencion (comparar solo la parte de fecha)
--   ID_IPRESS      <-> establecimientos.codigo
--   ID_UPS / UPS_DESCRIPCION <-> prestaciones.codigo_upss / upsses.descripcion_upss
--     (el código de consultorio puede venir ligeramente distinto entre
--      sistemas; por eso se trae también la descripción del UPS como
--      respaldo para el match difuso)
-- =============================================================================

SELECT
    p.documento AS DNI,
    a.FECHA_ATENCION,
    a.id_atencion AS ID_ATENCION,
    a.id_tipo_atencion AS TIPO_ATENCION,
    a.ID_IPRESS,
    CASE
        WHEN a.ID_IPRESS IN ('00011794','00014718','00016094','00011833') THEN 'NIVEL II'
        ELSE 'NIVEL I'
    END AS NIVEL_IPRESS,
    a.ID_UPS,
    u.NOMBRE AS UPS_DESCRIPCION,
    dx.CodigoDiagnostico AS CIE10,
    dx.nombre AS DESCRIPCION_CIE10
FROM ATENCION a
INNER JOIN atencion_diagnostico ad ON ad.id_atencion = a.id_atencion
INNER JOIN ss_ge_diagnostico dx    ON dx.idDiagnostico = ad.id_diagnostico
INNER JOIN personamast p           ON p.persona = a.paciente_id
LEFT JOIN ups u                    ON u.CODIGOUPS = a.ID_UPS
WHERE a.id_tipo_atencion IN ('AM','EM','HO')
  AND a.ESTADO = 'A'
  AND ad.id_secuencia = 1
  AND ad.id_tipo_diagnostico = '02'
  AND dx.CodigoDiagnostico NOT LIKE 'Z%'
  AND a.FECHA_ATENCION >= '2026-01-01' AND a.FECHA_ATENCION < '2026-09-01'
ORDER BY a.FECHA_ATENCION, a.ID_IPRESS, p.documento;
