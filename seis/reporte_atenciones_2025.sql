-- =============================================================================
-- REPORTE DE ATENCIONES 2025 - PROCEDIMIENTOS CPT Y DIAGNÓSTICO CIE-10 Z12.8
-- Desagregado por Grupo Etario, Sexo y Tipo de Beneficiario (Titular / Derechohabiente)
-- Base de Datos: sgcoresys
-- =============================================================================

SELECT 
    CASE 
        WHEN ad.ID_TIPO_DETALLE IN ('PRO','QUI') THEN CONCAT('PROC: ', ad.ID_CPT, ' - ', COALESCE(proc.NOMBRE, 'SIN DESCRIPCION'))
        WHEN ad.ID_TIPO_DETALLE = 'DIA' THEN CONCAT('DIAG: ', sd.CODIGODIAGNOSTICO, ' - ', COALESCE(sd.NOMBRE, 'SIN DESCRIPCION'))
    END AS CONCEPTO,
    
    CASE 
        WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 0 AND 11 THEN '0 - 11 años'
        WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 12 AND 17 THEN '12 - 17 años'
        WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 18 AND 29 THEN '18 - 29 años'
        WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 30 AND 59 THEN '30 - 59 años'
        WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) >= 60 THEN '60 años +'
        ELSE 'Sin Especificar'
    END AS GRUPO_ETARIO,
    
    CASE 
        WHEN p.SEXO = 'M' THEN 'Masculino'
        WHEN p.SEXO = 'F' THEN 'Femenino'
        ELSE 'Sin Especificar'
    END AS SEXO,
    
    CASE 
        WHEN p.ID_BENEFICIARIO = '01' THEN 'Titular'
        ELSE 'Derechohabiente'
    END AS TIPO_BENEFICIARIO,
    
    COUNT(DISTINCT a.id_atencion) AS CANTIDAD_ATENCIONES

FROM sgcoresys.atencion a
INNER JOIN sgcoresys.atencion_diagnostico ad 
    ON ad.ID_ATENCION = a.id_atencion
INNER JOIN sgcoresys.personamast p 
    ON p.PERSONA = a.PACIENTE_ID
LEFT JOIN sgcoresys.ss_ge_procedimientomedico proc 
    ON proc.CODIGOPROCEDIMIENTO = ad.ID_CPT
LEFT JOIN sgcoresys.ss_ge_diagnostico sd 
    ON sd.IDDIAGNOSTICO = ad.ID_DIAGNOSTICO

WHERE a.FECHA_ATENCION >= '2025-01-01 00:00:00' 
  AND a.FECHA_ATENCION <= '2025-12-31 23:59:59'
  AND a.ESTADO = 'A'
  AND (
      (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN (
          '88141',      -- Citopatología vaginal o cervical
          '88141.01',   -- Inspección Visual con Ácido Acético (IVAA)
          '87621',      -- Detección Papillomavirus humano (VPH)
          '99386.03',   -- Atención preventiva
          '57500',      -- Biopsia cervix/lesión
          '77057',      -- Mamografía de tamizaje bilateral
          '82270',      -- Sangre oculta en heces (Guayacol)
          '57452',      -- Colposcopia de cervix
          '84152'       -- Dosaje Antígeno Prostático Específico (PSA)
      ))
      OR
      (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_DIAGNOSTICO = 14028) -- Z12.8: Pesquisa tumor otros sitios
  )

GROUP BY CONCEPTO, GRUPO_ETARIO, SEXO, TIPO_BENEFICIARIO
ORDER BY CONCEPTO, GRUPO_ETARIO, SEXO, TIPO_BENEFICIARIO;
