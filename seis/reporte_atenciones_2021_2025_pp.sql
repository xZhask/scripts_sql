-- =============================================================================
-- SÁBANA DE ATENCIONES 2021-2025 CON PRODUCTOS PRESUPUESTALES (PP)
-- Columnas agregadas: ANIO, NIVEL_IPRESS, PRODUCTO_PRESUPUESTAL
-- Filtros obligatorios: a.id_tipo_atencion = 'AM' AND a.ESTADO = 'A'
-- Tipo Diagnóstico Definitivo: ad.id_tipo_diagnostico = '02'
-- Base de Datos: sgcoresys
-- =============================================================================

SELECT 
    YEAR(a.FECHA_ATENCION) AS ANIO,

    CASE
        WHEN a.ID_IPRESS IN ('00011794', '00014718', '00016094', '00011833') THEN 'NIVEL II'
        ELSE 'NIVEL I'
    END AS NIVEL_IPRESS,

    CASE 
        -- 3000004 | Mujer tamizada en cáncer de cuello uterino
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('88141','88141.01','88150','88155','87624','87625','99170','U3100'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND sd.CODIGODIAGNOSTICO IN ('Z12.4','Z01.4'))
        THEN '3000004 | Mujer tamizada en cáncer de cuello uterino'

        -- 3000036 | Familias saludables prevención del cáncer
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('C0009','C0010'))
        THEN '3000036 | Familias saludables prevención del cáncer'

        -- 3000365 | Cáncer de cuello uterino (Estadiaje y tratamiento - Dx '02')
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT IN ('57452','57454','57520') OR (ad.ID_CPT >= '96401' AND ad.ID_CPT <= '96549') OR (ad.ID_CPT >= '77401' AND ad.ID_CPT <= '77799')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = '02' AND sd.CODIGODIAGNOSTICO LIKE 'C53%')
        THEN '3000365 | Cáncer de cuello uterino (Estadiaje y tratamiento)'

        -- 3000366 | Cáncer de mama (Estadiaje y tratamiento - Dx '02')
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT IN ('19100','19101') OR (ad.ID_CPT >= '19301' AND ad.ID_CPT <= '19307')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = '02' AND sd.CODIGODIAGNOSTICO LIKE 'C50%')
        THEN '3000366 | Cáncer de mama (Estadiaje y tratamiento)'

        -- 3000367 | Cáncer de estómago (Estadiaje y tratamiento - Dx '02')
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT = '43239' OR (ad.ID_CPT >= '43620' AND ad.ID_CPT <= '43634')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = '02' AND sd.CODIGODIAGNOSTICO LIKE 'C16%')
        THEN '3000367 | Cáncer de estómago (Estadiaje y tratamiento)'

        -- 3000368 | Cáncer de próstata (Diagnóstico, estadiaje y tratamiento - Dx '02')
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('55700','55840','55845','84153'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = '02' AND sd.CODIGODIAGNOSTICO LIKE 'C61%')
        THEN '3000368 | Cáncer de próstata (Diagnóstico, estadiaje y tratamiento)'

        -- 3000369 | Cáncer de pulmón (Diagnóstico, estadiaje y tratamiento - Dx '02')
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT = '31625' OR (ad.ID_CPT >= '32440' AND ad.ID_CPT <= '32504')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = '02' AND sd.CODIGODIAGNOSTICO LIKE 'C34%')
        THEN '3000369 | Cáncer de pulmón (Diagnóstico, estadiaje y tratamiento)'

        -- 3000370 | Cáncer de colon y recto (Diagnóstico, estadiaje y tratamiento - Dx '02')
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT = '45380' OR (ad.ID_CPT >= '44140' AND ad.ID_CPT <= '44160')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = '02' AND (sd.CODIGODIAGNOSTICO LIKE 'C18%' OR sd.CODIGODIAGNOSTICO LIKE 'C19%' OR sd.CODIGODIAGNOSTICO LIKE 'C20%' OR sd.CODIGODIAGNOSTICO LIKE 'C21%'))
        THEN '3000370 | Cáncer de colon y recto (Diagnóstico, estadiaje y tratamiento)'

        -- 3000371 | Cáncer de hígado (Diagnóstico, estadiaje y tratamiento - Dx '02')
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ((ad.ID_CPT >= '47120' AND ad.ID_CPT <= '47130') OR ad.ID_CPT = '47370'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = '02' AND sd.CODIGODIAGNOSTICO LIKE 'C22%')
        THEN '3000371 | Cáncer de hígado (Diagnóstico, estadiaje y tratamiento)'

        -- 3000372 | Leucemia (Diagnóstico y tratamiento - Dx '02')
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND ad.ID_CPT IN ('38220','38221','85060'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = '02' AND (sd.CODIGODIAGNOSTICO LIKE 'C91%' OR sd.CODIGODIAGNOSTICO LIKE 'C92%' OR sd.CODIGODIAGNOSTICO LIKE 'C93%' OR sd.CODIGODIAGNOSTICO LIKE 'C94%' OR sd.CODIGODIAGNOSTICO LIKE 'C95%'))
        THEN '3000372 | Leucemia (Diagnóstico y tratamiento)'

        -- 3000373 | Linfoma (Diagnóstico y tratamiento - Dx '02')
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT >= '38500' AND ad.ID_CPT <= '38530'))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = '02' AND (sd.CODIGODIAGNOSTICO LIKE 'C81%' OR sd.CODIGODIAGNOSTICO LIKE 'C82%' OR sd.CODIGODIAGNOSTICO LIKE 'C83%' OR sd.CODIGODIAGNOSTICO LIKE 'C84%' OR sd.CODIGODIAGNOSTICO LIKE 'C85%' OR sd.CODIGODIAGNOSTICO LIKE 'C88%'))
        THEN '3000373 | Linfoma (Diagnóstico y tratamiento)'

        -- 3000374 | Cáncer de piel no melanomas (Diagnóstico, estadiaje y tratamiento - Dx '02')
        WHEN (ad.ID_TIPO_DETALLE IN ('PRO','QUI') AND (ad.ID_CPT IN ('11104','11105') OR (ad.ID_CPT >= '11600' AND ad.ID_CPT <= '11646')))
          OR (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_TIPO_DIAGNOSTICO = '02' AND sd.CODIGODIAGNOSTICO LIKE 'C44%' AND sd.CODIGODIAGNOSTICO NOT LIKE 'C43%')
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

WHERE a.ID_PERIODO BETWEEN '202101' AND '202512'
  AND a.FECHA_ATENCION >= '2021-01-01 00:00:00' 
  AND a.FECHA_ATENCION <= '2025-12-31 23:59:59'
  AND a.id_tipo_atencion = 'AM'
  AND a.ESTADO = 'A'
  AND (
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
      (ad.ID_TIPO_DETALLE = 'DIA' AND ad.ID_DIAGNOSTICO IN (
          14025, 13926, 14087, 14024, 14022, 14021, 14028, 6649, 6650, 14326, 13912, 13953,
          1815, 1816, 1817, 1818, 1527, 1528, 1529, 1530, 1510, 1511, 1512, 1513, 1514,
          1515, 1516, 1517, 1518, 1348, 1349, 1350, 1351, 1352, 1353, 1354, 1355, 14766,
          1415, 1416, 1417, 1418, 1419, 1420, 1357, 1358, 1359, 1360, 14757, 14758, 1364,
          1365, 1366, 1367, 1369, 1370, 1371, 1372, 1373, 1374, 1375, 1722, 1723, 1724,
          1725, 1726, 1727, 15067, 1728, 15068, 1729, 1731, 1732, 1733, 1734, 1735, 1736,
          15069, 1737, 15070, 1738, 1740, 1741, 1742, 15071, 1743, 1744, 1746, 1747, 1748,
          1749, 1750, 1751, 15072, 1752, 1754, 1755, 1756, 1757, 1758, 1675, 1676, 1677,
          1678, 15048, 1679, 1680, 1682, 1683, 1684, 15049, 15050, 15051, 15052, 1685, 1686,
          1688, 1689, 1690, 1691, 1692, 1693, 1694, 1695, 1696, 1697, 1699, 1700, 1701,
          1702, 1703, 1704, 15053, 15054, 15055, 15056, 1706, 1707, 15057, 1708, 1709,
          1711, 1712, 1713, 1714, 15065, 1715, 1716, 1460, 1461, 1462, 1463, 1464, 1465,
          1466, 1467, 1468, 1469
      ))
  )

GROUP BY ANIO, NIVEL_IPRESS, PRODUCTO_PRESUPUESTAL, CONCEPTO, GRUPO_ETARIO, p.SEXO, TIPO_BENEFICIARIO
ORDER BY ANIO ASC, NIVEL_IPRESS, PRODUCTO_PRESUPUESTAL, CONCEPTO, GRUPO_ETARIO, p.SEXO, TIPO_BENEFICIARIO;
