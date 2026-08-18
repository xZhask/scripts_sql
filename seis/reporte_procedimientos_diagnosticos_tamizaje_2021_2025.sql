-- =============================================================================
-- REPORTE DE ATENCIONES POR PROCEDIMIENTOS (CPMS) Y DIAGNÓSTICOS (CIE-10) DE TAMIZAJE Y PREVENCIÓN
-- Periodo: 2021 - 2025
-- Base de Datos: sgcoresys
--
-- CÓDIGOS DE PROCEDIMIENTO (CPMS):
--   57452: Colposcopia de Cérvix incluyendo la parte superior o Adyacente de la Vagina.
--   57500: Biopsia de cuello uterino
--   77057: Mamografía Bilateral de Tamizaje.
--   82270: Test Sangre Oculta en Heces.
--   84152: Examen de Antígeno Prostático.
--   87621: Detección Molecular VPH.
--   88141: Citopatología Cervicovaginal o Vaginal y Tamizaje Manual (Papanicolaou).
--   88141.01: Inspección Visual con Ácido Acético (IVAA).
--   99386.03: Examen Clínico de Mama.
--
-- CÓDIGOS DE DIAGNÓSTICO (CIE-10):
--   C53.9: Tumor Maligno del Cuello del Útero sin otra especificación.
--   D06.9: Carcinoma In Situ del Cuello del Útero parte no especificada / Neoplasia Intraepitelial.
--   N63.X: Masa no Especificada en la Mama.
--   N87.0: Displasia Cervical Leve / NIC 1 / LIE Bajo Grado.
--   N87.1: Displasia Cervical Moderada / NIC 2 / LIE Alto Grado.
--   N87.2: Displasia Cervical Severa / NIC 3 / LIE Alto Grado.
--   R87.6: Hallazgos Anormales en Muestras de Órganos Genitales Femeninos (Frotis Anormal PAP).
--   Z12.8: Examen Clínico de Piel (Pesquisa especial).
-- =============================================================================

SELECT 
    a.id_atencion AS `id_atención`,
    a.id_tipo_atencion AS `tipo_atención`,
    p.documento AS `dni`,
    p.NOMBRECOMPLETO AS `nombre`,
    
    -- SEXO DEL PACIENTE
    CASE 
        WHEN p.SEXO = 'M' THEN 'MASCULINO'
        WHEN p.SEXO = 'F' THEN 'FEMENINO'
        ELSE COALESCE(p.SEXO, 'NO ESPECIFICADO')
    END AS `sexo`,
    
    -- GRUPO ETARIO
    CASE 
        WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 0 AND 11 THEN '0-11 (NIÑEZ)'
        WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 12 AND 17 THEN '12-17 (ADOLESCENCIA)'
        WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 18 AND 29 THEN '18-29 (JUVENTUD)'
        WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 30 AND 59 THEN '30-59 (ADULTEZ)'
        WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) >= 60 THEN '60+ (ADULTO MAYOR)'
        ELSE 'SIN DATO'
    END AS `grupo etario`,
    
    -- TIPO DE BENEFICIARIO (1 = TITULAR, OTROS = DERECHOHABIENTES)
    CASE 
        WHEN p.ID_BENEFICIARIO IN ('1', '01') THEN 'TITULAR'
        ELSE 'DERECHOHABIENTE'
    END AS `tipo de beneficiario`,
    
    -- CÓDIGO CIE-10 O CPMS
    CASE 
        WHEN ad.ID_TIPO_DETALLE = 'DIA' THEN sd.CodigoDiagnostico 
        ELSE ad.ID_CPT 
    END AS `cie10 o cpms`,
    
    -- DESCRIPCIÓN DE DIAGNÓSTICO O CPMS
    CASE 
        WHEN ad.ID_TIPO_DETALLE = 'DIA' THEN sd.Nombre 
        ELSE COALESCE(proc.NOMBRE, 
            CASE 
                WHEN ad.ID_CPT = '99386.03' THEN 'Examen Clínico de Mama' 
                ELSE 'SIN DESCRIPCION' 
            END
        ) 
    END AS `descripción diagnóstico o descripción CPMS`,
    
    -- AÑO (Extraído de FECHA_ATENCION o ID_PERIODO para evitar valores NULL)
    COALESCE(YEAR(a.FECHA_ATENCION), CAST(LEFT(a.ID_PERIODO, 4) AS UNSIGNED)) AS `año`,
    
    a.ID_IPRESS AS `codigo ipress`,
    i.DESCRIPCIONLOCAL AS `descripción ed ipress`,
    
    -- NIVEL DE IPRESS
    CASE 
        WHEN a.ID_IPRESS IN ('00011794', '00014718', '00016094', '00011833') THEN 'NIVEL II'
        ELSE 'NIVEL I'
    END AS `nivel de IPRESS`

FROM sgcoresys.atencion a
INNER JOIN sgcoresys.atencion_diagnostico ad 
    ON ad.id_atencion = a.id_atencion

LEFT JOIN sgcoresys.ss_ge_diagnostico sd 
    ON sd.idDiagnostico = ad.id_diagnostico

LEFT JOIN sgcoresys.ss_ge_procedimientomedico proc 
    ON proc.CODIGOPROCEDIMIENTO = ad.ID_CPT

INNER JOIN sgcoresys.personamast p 
    ON p.persona = a.paciente_id

INNER JOIN sgcoresys.ac_sucursal i 
    ON i.SUCURSAL = a.ID_IPRESS

WHERE a.ESTADO = 'A'
  AND (
      YEAR(a.FECHA_ATENCION) BETWEEN 2021 AND 2025
      OR a.ID_PERIODO BETWEEN '202101' AND '202512'
  )
  AND (
      -- Diagnósticos especificados (CIE-10)
      (ad.ID_TIPO_DETALLE = 'DIA' AND sd.CodigoDiagnostico IN (
          'C53.9', 'D06.9', 'N63.X', 'N87.0', 'N87.1', 'N87.2', 'R87.6', 'Z12.8'
      ))
      OR
      -- Procedimientos especificados (CPMS)
      (ad.ID_TIPO_DETALLE IN ('PRO', 'QUI') AND ad.ID_CPT IN (
          '57452', '57500', '77057', '82270', '84152', '87621', '88141', '88141.01', '99386.03'
      ))
  )

ORDER BY 
    `año` ASC,
    `nivel de IPRESS`,
    a.id_atencion;
