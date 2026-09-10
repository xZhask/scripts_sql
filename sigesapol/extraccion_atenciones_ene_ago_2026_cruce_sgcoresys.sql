-- =============================================================================
-- EXTRACCIÓN SIGESAPOL_AGOSTO · ENERO A AGOSTO 2026
-- Equivalente a seis/extraccion_atenciones_ene_ago_2026_cruce_sigesapol.sql
-- (lado sgcoresys) — MISMAS columnas y MISMO orden, para que el cruce /
-- deduplicación posterior (por DNI + fecha + IPRESS + consultorio) sea un
-- simple merge entre ambos exports.
--
-- Motor: PostgreSQL. Base: sigesapol_agosto (nombre que le hayan puesto al
-- restaurar el dump de agosto).
--
-- Mapeo de tipo de atención (prestaciones.id_tipo_atencion), según el
-- comentario ya existente en sigesapol/top10_morbilidad.sql:
--   1 = Ambulatoria -> AM   2 = Emergencia -> EM   3 = Hospitalización -> HO
--   (7 = Urgencia, se deja fuera, igual que del lado sgcoresys solo se
--    tomó AM/EM/HO)
--
-- Nivel: clasificado por establecimientos.codigo (el código oficial de
-- IPRESS, el mismo que se usa como "CODIGO IPRESS" en
-- sigesapol/data_general_atenciones.sql) con la MISMA lista de códigos
-- Nivel II que en sgcoresys — NO por establecimientos.id (PK interno de
-- sigesapol, no comparable entre sistemas).
--
-- Criterios espejo de sgcoresys: p.id_estado_reg = 1 (equivalente a
-- a.ESTADO='A'), rd.id_tipo_diagnostico = 2 (equivalente a '02' definitivo),
-- dx.codigo NOT LIKE 'Z%'.
--
-- ⚠ DOS COSAS A CONFIRMAR ANTES DE USAR ESTO PARA EL CONTEO FINAL:
--   1) Del lado sgcoresys se filtró ad.id_secuencia = 1 (solo diagnóstico
--      PRINCIPAL por atención). Acá no encontré un campo equivalente en
--      receta_diagnosticos en las queries que ya tienen en /sigesapol — si
--      existe, agrégalo al WHERE. Si no existe, una misma prestación con
--      2 diagnósticos definitivos generará 2 filas acá, mientras que del
--      lado sgcoresys esa misma atención solo aporta 1. Eso puede inflar
--      el conteo de sigesapol frente a sgcoresys antes de deduplicar.
--   2) sigesapol/data_general_atenciones.sql excluye "id_establecimiento
--      <> 76", pero sigesapol/top10_morbilidad.sql lo clasifica como
--      'NIVEL III' (no lo excluye). Acá NO se excluye ningún
--      establecimiento — confirmar qué es el 76 y si debe quedar fuera.
-- =============================================================================

SELECT
    a.nro_doc_ident AS "DNI",
    p.fecha_atencion AS "FECHA_ATENCION",
    p.id AS "ID_ATENCION",
    CASE p.id_tipo_atencion
        WHEN 1 THEN 'AM'
        WHEN 2 THEN 'EM'
        WHEN 3 THEN 'HO'
    END AS "TIPO_ATENCION",
    e.codigo AS "ID_IPRESS",
    CASE
        WHEN e.codigo IN ('00011794','00014718','00016094','00011833') THEN 'NIVEL II'
        ELSE 'NIVEL I'
    END AS "NIVEL_IPRESS",
    p.codigo_upss AS "ID_UPS",
    u.descripcion_upss AS "UPS_DESCRIPCION",
    dx.codigo AS "CIE10",
    dx.nombre AS "DESCRIPCION_CIE10"
FROM prestaciones p
INNER JOIN establecimientos e
    ON e.id = p.id_establecimiento
INNER JOIN receta_diagnosticos rd
    ON rd.id_prestacion = p.id
INNER JOIN diagnosticos dx
    ON dx.id = rd.id_diagnostico
LEFT JOIN asegurados a
    ON a.id = p.id_asegurado
LEFT JOIN (
    SELECT DISTINCT ON (codigo)
           codigo,
           descripcion_upss
    FROM upsses
    ORDER BY codigo, updated_at DESC
) u
    ON u.codigo = p.codigo_upss
WHERE p.id_tipo_atencion IN (1, 2, 3)
  AND p.id_estado_reg = 1
  AND rd.id_tipo_diagnostico = 2
  AND dx.codigo NOT LIKE 'Z%'
  AND p.fecha_atencion >= '2026-01-01'
  AND p.fecha_atencion <  '2026-09-01'
ORDER BY p.fecha_atencion, e.codigo, a.nro_doc_ident;
