-- =============================================================================
-- MORBILIDAD GENERAL ENERO - AGOSTO 2026 (DETALLE, PARA CRUCE CON SEIS)
-- Base de Datos: PostgreSQL "sigesapol_agosto"
-- Columnas: ID_PRESTACION, DNI, TIPO_ATENCION, FECHA_ATENCION, CIE10,
--           DESCRIPCION_CIE10, CODIGO_UPS, DESCRIPCION_UPS, CODIGO_IPRESS,
--           DESCRIPCION_IPRESS
--
-- Propósito: contraparte de seis/morbilidad_general_2026_ene_ago.sql. Ambas
-- consultas devuelven las mismas columnas para poder cruzarlas (por ejemplo
-- en una tabla dinámica o con un JOIN/ANTI-JOIN en una tabla temporal) y
-- deduplicar atenciones registradas en los dos sistemas durante la migración
-- de SEIS hacia SIGESAPOL.
--
-- CLAVE DE CRUCE SUGERIDA: DNI + fecha (día, sin hora) + CIE10 + código IPRESS.
-- No se puede cruzar por ID_ATENCION porque son secuencias independientes en
-- cada sistema. Un establecimiento que migró a mitad de periodo puede tener
-- el mismo episodio registrado en SEIS Y en SIGESAPOL: al agrupar por esa
-- clave y quedarte con 1 fila por grupo evitas contar la atención 2 veces.
--
-- VALIDADO 2026-09-05: sigesapol_agosto SÍ tiene data completa para los 8
-- meses (ene-ago 2026), a diferencia de la BD del SEIS que solo llega a abril.
-- El código de establecimientos.codigo usa el mismo formato de 8 dígitos que
-- ID_IPRESS en SEIS (ej. '00012088'), por lo que ese campo es el join key
-- entre ambos sistemas.
--
-- Se excluye el HOSPITAL NACIONAL PNP LUIS N. SAENZ (codigo '00013591') de
-- los reportes por indicación expresa del usuario.
-- =============================================================================

SELECT
    p.id AS ID_PRESTACION,
    a.nro_doc_ident AS DNI,

    CASE p.id_tipo_atencion
        WHEN 1 THEN 'AMBULATORIA'
        WHEN 2 THEN 'EMERGENCIA'
        WHEN 3 THEN 'HOSPITALIZACIÓN'
        WHEN 7 THEN 'URGENCIA'
        ELSE p.id_tipo_atencion::varchar
    END AS TIPO_ATENCION,

    p.fecha_atencion AS FECHA_ATENCION,

    dx.codigo AS CIE10,
    dx.nombre AS DESCRIPCION_CIE10,

    p.codigo_upss AS CODIGO_UPS,
    u.descripcion_upss AS DESCRIPCION_UPS,

    e.codigo AS CODIGO_IPRESS,
    e.nombre AS DESCRIPCION_IPRESS

FROM prestaciones p

INNER JOIN receta_diagnosticos rd
    ON rd.id_prestacion = p.id

INNER JOIN diagnosticos dx
    ON dx.id = rd.id_diagnostico

LEFT JOIN asegurados a
    ON a.id = p.id_asegurado

INNER JOIN establecimientos e
    ON e.id = p.id_establecimiento

LEFT JOIN (
    SELECT DISTINCT ON (codigo)
           codigo,
           descripcion_upss
    FROM upsses
    ORDER BY codigo, updated_at DESC
) u
    ON u.codigo = p.codigo_upss

WHERE p.fecha_atencion >= '2026-01-01'
  AND p.fecha_atencion <  '2026-09-01'
  AND p.id_estado_reg = 1
  AND p.id_tipo_atencion IN (1, 2, 3)  -- AMBULATORIA/EMERGENCIA/HOSPITALIZACIÓN, equivalente a AM/EM/HO en SEIS
                                        -- agregar el 7 (URGENCIA) si se requiere: no tiene equivalente en SEIS
  AND rd.id_tipo_diagnostico = 2        -- DEFINITIVO (equivalente a id_tipo_diagnostico='02' en SEIS)
  AND dx.codigo NOT LIKE 'Z%'
  -- Quitar el filtro anterior si se requieren también los diagnósticos de
  -- tamizaje/administrativos (código Z) en el cruce.
  AND e.codigo <> '00013591'  -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ (id=76)

ORDER BY p.fecha_atencion;
