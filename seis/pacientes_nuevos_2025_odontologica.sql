-- =============================================================================
-- REPORTE DE PACIENTES NUEVOS ATENDIDOS EN EL AÑO 2025 (SIN DUPLICADOS POR DNI)
-- IPRESS: Clínica Odontológica PNP (ID_IPRESS = '00012822')
-- Criterio: 
--   1. 1 solo registro por DNI de paciente (sin duplicar personas registradas 2 veces).
--   2. Su primera atención en esta IPRESS ocurrió en 2025 (excluye atenciones de 2024 o anteriores).
--   3. La fecha y UPSS corresponden estrictamente a esa primera atención de 2025.
-- Base de Datos: sgcoresys
-- =============================================================================

SELECT 
    p.documento AS DNI_PACIENTE,
    CONCAT(
        COALESCE(MAX(p.APELLIDOPATERNO), ''), ' ', 
        COALESCE(MAX(p.APELLIDOMATERNO), ''), ' ', 
        COALESCE(MAX(p.NOMBRES), '')
    ) AS NOMBRE_PACIENTE,
    primer_registro.FECHA_PRIMERA_ATENCION,
    COALESCE(u.NOMBRE, a.ID_UPS, 'SIN ESPECIFICAR') AS UPSS
FROM (
    -- Agrupamos por DNI para garantizar 1 solo registro por paciente físico
    -- Y filtramos que su MÍNIMA fecha de atención en la IPRESS 00012822 sea del 2025
    SELECT 
        p1.documento,
        MIN(a1.FECHA_ATENCION) AS FECHA_PRIMERA_ATENCION,
        MIN(a1.id_atencion) AS ID_PRIMERA_ATENCION
    FROM sgcoresys.atencion a1
    INNER JOIN sgcoresys.personamast p1 
        ON p1.PERSONA = a1.PACIENTE_ID
    WHERE a1.ID_TIPO_ATENCION IN ('AM','EM','HO','PR','CR','DE','DM','ES','FM','FR','MR','PA','PQ','RF')
      AND a1.ID_IPRESS = '00012822' -- Clínica Odontológica PNP
      AND a1.ESTADO = 'A'
      AND p1.documento IS NOT NULL AND p1.documento != ''
    GROUP BY p1.documento
    HAVING MIN(a1.FECHA_ATENCION) >= '2025-01-01 00:00:00' 
       AND MIN(a1.FECHA_ATENCION) <= '2025-12-31 23:59:59'
) primer_registro
INNER JOIN sgcoresys.atencion a 
    ON a.id_atencion = primer_registro.ID_PRIMERA_ATENCION
INNER JOIN sgcoresys.personamast p 
    ON p.documento = primer_registro.documento
LEFT JOIN sgcoresys.ups u 
    ON u.CODIGOUPS = a.ID_UPS
GROUP BY p.documento, primer_registro.FECHA_PRIMERA_ATENCION, a.id_atencion, u.NOMBRE, a.ID_UPS
ORDER BY primer_registro.FECHA_PRIMERA_ATENCION ASC;
