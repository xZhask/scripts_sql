-- =============================================================================
-- RESUMEN EJECUTIVO DE ATENCIONES POR PRODUCTO PRESUPUESTAL (2021-2025)
-- Base de Datos: SEIS (sgcoresys / db_seis_marzo26)
-- =============================================================================

SELECT 
    YEAR(a.FECHA_ATENCION) AS ANIO,
    
    CASE 
        -- 3000004 | Mujer tamizada en cáncer de cuello uterino
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('88141','88141.01','88150','88155','87624','87625','99170','U3100'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND sd.CODIGODIAGNOSTICO IN ('Z12.4','Z01.4'))
        THEN '3000004 | Mujer tamizada en cáncer de cuello uterino'

        -- 3000036 | Familias saludables prevención del cáncer
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('C0009','C0010'))
        THEN '3000036 | Familias saludables prevención del cáncer'

        -- 3000365 | Cáncer de cuello uterino (Estadiaje y tratamiento)
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT IN ('57452','57454','57520') OR (ad.ID_CPT >= '96401' AND ad.ID_CPT <= '96549') OR (ad.ID_CPT >= '77401' AND ad.ID_CPT <= '77799')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = 'D' AND sd.CODIGODIAGNOSTICO LIKE 'C53%')
        THEN '3000365 | Cáncer de cuello uterino (Estadiaje y tratamiento)'

        -- 3000366 | Cáncer de mama (Estadiaje y tratamiento)
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT IN ('19100','19101') OR (ad.ID_CPT >= '19301' AND ad.ID_CPT <= '19307')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = 'D' AND sd.CODIGODIAGNOSTICO LIKE 'C50%')
        THEN '3000366 | Cáncer de mama (Estadiaje y tratamiento)'

        -- 3000367 | Cáncer de estómago (Estadiaje y tratamiento)
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT = '43239' OR (ad.ID_CPT >= '43620' AND ad.ID_CPT <= '43634')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = 'D' AND sd.CODIGODIAGNOSTICO LIKE 'C16%')
        THEN '3000367 | Cáncer de estómago (Estadiaje y tratamiento)'

        -- 3000368 | Cáncer de próstata (Diagnóstico, estadiaje y tratamiento)
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('55700','55840','55845','84153'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = 'D' AND sd.CODIGODIAGNOSTICO LIKE 'C61%')
        THEN '3000368 | Cáncer de próstata (Diagnóstico, estadiaje y tratamiento)'

        -- 3000369 | Cáncer de pulmón (Diagnóstico, estadiaje y tratamiento)
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT = '31625' OR (ad.ID_CPT >= '32440' AND ad.ID_CPT <= '32504')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = 'D' AND sd.CODIGODIAGNOSTICO LIKE 'C34%')
        THEN '3000369 | Cáncer de pulmón (Diagnóstico, estadiaje y tratamiento)'

        -- 3000370 | Cáncer de colon y recto (Diagnóstico, estadiaje y tratamiento)
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT = '45380' OR (ad.ID_CPT >= '44140' AND ad.ID_CPT <= '44160')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = 'D' AND (sd.CODIGODIAGNOSTICO LIKE 'C18%' OR sd.CODIGODIAGNOSTICO LIKE 'C19%' OR sd.CODIGODIAGNOSTICO LIKE 'C20%' OR sd.CODIGODIAGNOSTICO LIKE 'C21%'))
        THEN '3000370 | Cáncer de colon y recto (Diagnóstico, estadiaje y tratamiento)'

        -- 3000371 | Cáncer de hígado (Diagnóstico, estadiaje y tratamiento)
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ((ad.ID_CPT >= '47120' AND ad.ID_CPT <= '47130') OR ad.ID_CPT = '47370'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = 'D' AND sd.CODIGODIAGNOSTICO LIKE 'C22%')
        THEN '3000371 | Cáncer de hígado (Diagnóstico, estadiaje y tratamiento)'

        -- 3000372 | Leucemia (Diagnóstico y tratamiento)
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('38220','38221','85060'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = 'D' AND (sd.CODIGODIAGNOSTICO LIKE 'C91%' OR sd.CODIGODIAGNOSTICO LIKE 'C92%' OR sd.CODIGODIAGNOSTICO LIKE 'C93%' OR sd.CODIGODIAGNOSTICO LIKE 'C94%' OR sd.CODIGODIAGNOSTICO LIKE 'C95%'))
        THEN '3000372 | Leucemia (Diagnóstico y tratamiento)'

        -- 3000373 | Linfoma (Diagnóstico y tratamiento)
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT >= '38500' AND ad.ID_CPT <= '38530'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = 'D' AND (sd.CODIGODIAGNOSTICO LIKE 'C81%' OR sd.CODIGODIAGNOSTICO LIKE 'C82%' OR sd.CODIGODIAGNOSTICO LIKE 'C83%' OR sd.CODIGODIAGNOSTICO LIKE 'C84%' OR sd.CODIGODIAGNOSTICO LIKE 'C85%' OR sd.CODIGODIAGNOSTICO LIKE 'C88%'))
        THEN '3000373 | Linfoma (Diagnóstico y tratamiento)'

        -- 3000374 | Cáncer de piel no melanomas (Diagnóstico, estadiaje y tratamiento)
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT IN ('11104','11105') OR (ad.ID_CPT >= '11600' AND ad.ID_CPT <= '11646')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = 'D' AND sd.CODIGODIAGNOSTICO LIKE 'C44%' AND sd.CODIGODIAGNOSTICO NOT LIKE 'C43%')
        THEN '3000374 | Cáncer de piel no melanomas (Diagnóstico, estadiaje y tratamiento)'

        -- 3000683 | Niña protegida con vacuna VPH
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('90649','90650'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND sd.CODIGODIAGNOSTICO = 'Z25.8')
        THEN '3000683 | Niña protegida con vacuna VPH'

        -- 3000815 | Consejería para la prevención y control del cáncer
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('99401','99411'))
        THEN '3000815 | Consejería prevención cáncer'

        -- 3000816 | Mujer tamizada en cáncer de mama
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('77067','77065','77066','77057'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND sd.CODIGODIAGNOSTICO = 'Z12.3')
        THEN '3000816 | Mujer tamizada en cáncer de mama'

        -- 3000817 | Persona tamizada para detección de otros cánceres prevalentes
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('82270','43235'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND sd.CODIGODIAGNOSTICO IN ('Z12.1','Z12.0','Z12.8'))
        THEN '3000817 | Persona tamizada otros cánceres prevalentes'

        -- 3000818 | Persona atendida con lesiones premalignas de cuello uterino
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('57511','57513','57460'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND (sd.CODIGODIAGNOSTICO IN ('N87.0','N87.1') OR sd.CODIGODIAGNOSTICO LIKE 'D06%'))
        THEN '3000818 | Lesiones premalignas de cuello uterino'

        -- 3000819 | Persona atendida con cuidados paliativos
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT = '99499.10' OR (ad.ID_CPT >= '99211' AND ad.ID_CPT <= '99215')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND sd.CODIGODIAGNOSTICO = 'Z51.5')
        THEN '3000819 | Cuidados paliativos'

        -- 3000001 | Acciones comunes
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('99213','C7001','C7003'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND sd.CODIGODIAGNOSTICO IN ('Z00.0','Z01.9'))
        THEN '3000001 | Acciones comunes'

        ELSE 'Otros / Sin PP'
    END AS PRODUCTO_PRESUPUESTAL,

    COUNT(DISTINCT a.id_atencion) AS TOTAL_ATENCIONES

FROM atencion a
INNER JOIN atencion_diagnostico ad 
    ON ad.ID_ATENCION = a.id_atencion
LEFT JOIN ss_ge_diagnostico sd 
    ON sd.IDDIAGNOSTICO = ad.ID_DIAGNOSTICO

WHERE a.ID_PERIODO BETWEEN '202101' AND '202512'
  AND a.FECHA_ATENCION >= '2021-01-01 00:00:00'
  AND a.FECHA_ATENCION <= '2025-12-31 23:59:59'
  AND a.ESTADO = 'A'
  AND (
      -- Procedimientos CPT catalogados
      (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (
          ad.ID_CPT IN (
              '88141','88141.01','88150','88155','87624','87625','99170','U3100','C0009','C0010',
              '57452','57454','57520','19100','19101','43239','55700','55840','55845','84153',
              '31625','45380','47370','38220','38221','85060','11104','11105','90649','90650',
              '99401','99411','77067','77065','77066','77057','82270','43235','57511','57513',
              '57460','99499.10','99213','C7001','C7003'
          )
          OR (ad.ID_CPT >= '96401' AND ad.ID_CPT <= '96549')
          OR (ad.ID_CPT >= '77401' AND ad.ID_CPT <= '77799')
          OR (ad.ID_CPT >= '19301' AND ad.ID_CPT <= '19307')
          OR (ad.ID_CPT >= '43620' AND ad.ID_CPT <= '43634')
          OR (ad.ID_CPT >= '32440' AND ad.ID_CPT <= '32504')
          OR (ad.ID_CPT >= '44140' AND ad.ID_CPT <= '44160')
          OR (ad.ID_CPT >= '47120' AND ad.ID_CPT <= '47130')
          OR (ad.ID_CPT >= '38500' AND ad.ID_CPT <= '38530')
          OR (ad.ID_CPT >= '11600' AND ad.ID_CPT <= '11646')
          OR (ad.ID_CPT >= '99211' AND ad.ID_CPT <= '99215')
      ))
      OR
      -- Diagnósticos CIE-10 catalogados
      (ad.ID_TIPO_DETALLE = 'DIA' AND (
          sd.CODIGODIAGNOSTICO IN ('Z12.4','Z01.4','Z25.8','Z12.3','Z12.1','Z12.0','Z12.8','N87.0','N87.1','Z51.5','Z00.0','Z01.9')
          OR sd.CODIGODIAGNOSTICO LIKE 'D06%'
          OR (ad.ID_TIPO_DIAGNOSTICO = 'D' AND (
              sd.CODIGODIAGNOSTICO LIKE 'C53%' OR sd.CODIGODIAGNOSTICO LIKE 'C50%' OR sd.CODIGODIAGNOSTICO LIKE 'C16%'
              OR sd.CODIGODIAGNOSTICO LIKE 'C61%' OR sd.CODIGODIAGNOSTICO LIKE 'C34%' OR sd.CODIGODIAGNOSTICO LIKE 'C18%'
              OR sd.CODIGODIAGNOSTICO LIKE 'C19%' OR sd.CODIGODIAGNOSTICO LIKE 'C20%' OR sd.CODIGODIAGNOSTICO LIKE 'C21%'
              OR sd.CODIGODIAGNOSTICO LIKE 'C22%' OR sd.CODIGODIAGNOSTICO LIKE 'C91%' OR sd.CODIGODIAGNOSTICO LIKE 'C92%'
              OR sd.CODIGODIAGNOSTICO LIKE 'C93%' OR sd.CODIGODIAGNOSTICO LIKE 'C94%' OR sd.CODIGODIAGNOSTICO LIKE 'C95%'
              OR sd.CODIGODIAGNOSTICO LIKE 'C81%' OR sd.CODIGODIAGNOSTICO LIKE 'C82%' OR sd.CODIGODIAGNOSTICO LIKE 'C83%'
              OR sd.CODIGODIAGNOSTICO LIKE 'C84%' OR sd.CODIGODIAGNOSTICO LIKE 'C85%' OR sd.CODIGODIAGNOSTICO LIKE 'C88%'
              OR (sd.CODIGODIAGNOSTICO LIKE 'C44%' AND sd.CODIGODIAGNOSTICO NOT LIKE 'C43%')
          ))
      ))
  )

GROUP BY ANIO, PRODUCTO_PRESUPUESTAL
HAVING PRODUCTO_PRESUPUESTAL <> 'Otros / Sin PP'
ORDER BY ANIO ASC, PRODUCTO_PRESUPUESTAL;
