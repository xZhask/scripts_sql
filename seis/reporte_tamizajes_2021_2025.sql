-- Query para obtener atenciones de tamizajes (CPMS / CIE10) de 2021 a 2025
-- según especificaciones de tipos de atención y rangos de edad.

SELECT 
    a.id_atencion,
    p.documento AS documento_paciente,
    p.NOMBRECOMPLETO AS nombre_paciente,
    p.SEXO AS sexo,
    CASE 
        WHEN p.ID_BENEFICIARIO = '01' THEN 'TITULAR'
        WHEN p.ID_BENEFICIARIO IN ('02', '03', '04', '05', '06', '07', '08') THEN 'FAMILIAR'
        ELSE 'OTRO'
    END AS tipo_beneficiario,
    ad.ID_CPT AS codigo_cpms_cie10,
    CONVERT(BINARY(CONVERT(proc.NOMBRE USING latin1)) USING utf8mb4) AS descripcion_cpms_cie10,
    YEAR(a.fecha_atencion) AS anio_atencion,
    a.PACIENTE_EDAD AS edad,
    CASE 
        WHEN ad.ID_CPT = '77057' THEN '40 - 49 años y 50 - 69 años'
        WHEN ad.ID_CPT = '82270' THEN '50 - 70 años'
        WHEN ad.ID_CPT = '84152' THEN '45 - 75 años'
        WHEN ad.ID_CPT = '87621' THEN '30 - 49 años'
        WHEN ad.ID_CPT = '88141' THEN '25 - 64 años'
        WHEN ad.ID_CPT = '88141.01' THEN '30 - 49 años'
        WHEN ad.ID_CPT = '99386.03' THEN '40 - 69 años'
    END AS rango_edad
FROM atencion a
INNER JOIN atencion_diagnostico ad 
    ON ad.ID_ATENCION = a.id_atencion
INNER JOIN personamast p 
    ON p.PERSONA = a.paciente_id
INNER JOIN ss_ge_procedimientomedico proc 
    ON proc.CODIGOPROCEDIMIENTO = ad.ID_CPT
WHERE a.id_tipo_atencion = 'PR'
  AND a.ESTADO = 'A'
  AND ad.ID_TIPO_DETALLE IN ('PRO', 'QUI')
  AND a.fecha_atencion >= '2021-01-01 00:00:00'
  AND a.fecha_atencion <= '2025-12-31 23:59:59'
  AND (
      (ad.ID_CPT = '77057' AND a.PACIENTE_EDAD BETWEEN 40 AND 69) OR
      (ad.ID_CPT = '82270' AND a.PACIENTE_EDAD BETWEEN 50 AND 70) OR
      (ad.ID_CPT = '84152' AND a.PACIENTE_EDAD BETWEEN 45 AND 75) OR
      (ad.ID_CPT = '87621' AND a.PACIENTE_EDAD BETWEEN 30 AND 49) OR
      (ad.ID_CPT = '88141' AND a.PACIENTE_EDAD BETWEEN 25 AND 64) OR
      (ad.ID_CPT = '88141.01' AND a.PACIENTE_EDAD BETWEEN 30 AND 49) OR
      (ad.ID_CPT = '99386.03' AND a.PACIENTE_EDAD BETWEEN 40 AND 69)
  )

UNION ALL

SELECT 
    a.id_atencion,
    p.documento AS documento_paciente,
    p.NOMBRECOMPLETO AS nombre_paciente,
    p.SEXO AS sexo,
    CASE 
        WHEN p.ID_BENEFICIARIO = '01' THEN 'TITULAR'
        WHEN p.ID_BENEFICIARIO IN ('02', '03', '04', '05', '06', '07', '08') THEN 'FAMILIAR'
        ELSE 'OTRO'
    END AS tipo_beneficiario,
    sd.CodigoDiagnostico AS codigo_cpms_cie10,
    CONVERT(BINARY(CONVERT(sd.NOMBRE USING latin1)) USING utf8mb4) AS descripcion_cpms_cie10,
    YEAR(a.fecha_atencion) AS anio_atencion,
    a.PACIENTE_EDAD AS edad,
    '18 - 70 años' AS rango_edad
FROM atencion a
INNER JOIN atencion_diagnostico ad 
    ON ad.ID_ATENCION = a.id_atencion
INNER JOIN personamast p 
    ON p.PERSONA = a.paciente_id
INNER JOIN ss_ge_diagnostico sd 
    ON sd.idDiagnostico = ad.id_diagnostico
WHERE a.id_tipo_atencion IN ('AM', 'EM', 'HO')
  AND a.ESTADO = 'A'
  AND ad.ID_TIPO_DETALLE = 'DIA'
  AND a.fecha_atencion >= '2021-01-01 00:00:00'
  AND a.fecha_atencion <= '2025-12-31 23:59:59'
  AND sd.CodigoDiagnostico = 'Z12.8'
  AND a.PACIENTE_EDAD BETWEEN 18 AND 70;
