SELECT
    a.id_atencion,
    a.ID_TIPO_ATENCION,
    a.ID_IPRESS,
    i.DESCRIPCIONLOCAL,
    a.FECHA_ATENCION,

    -- PACIENTE
    p.TIPODOCUMENTO,
    p.documento,
    p.NOMBRECOMPLETO,
    p.SEXO,
    p.FECHANACIMIENTO,
    p.ID_BENEFICIARIO,

    -- RESPONSABLE SOLICITANTE
    ps.documento AS 'DOC. RESP. SOLICITANTE',
    ps.NOMBRECOMPLETO AS 'RESP. SOLICITANTE',
    ps.ID_COLEGIO_PROFESIONAL AS 'COLEGIO RESP. SOLICITANTE',

    -- RESPONSABLE PROCEDIMIENTO
    pr.documento AS 'DOC. RESP. PROC',
    pr.NOMBRECOMPLETO AS 'RESP. PROCEDIMIENTO',
    pr.ID_COLEGIO_PROFESIONAL AS 'COLEGIO RESP. PROC',

    -- PROCEDIMIENTO (UNA FILA POR PROCEDIMIENTO)
    proc.CODIGOPROCEDIMIENTO,
    proc.NOMBRE AS NOMBRE_PROCEDIMIENTO,
    proc.ID_TIPO_CPT,
    proc.ID_DIVISION,
    proc.ID_SUBDIVISION,

    -- UPS
    a.ID_UPS,
    u.NOMBRE AS NOMBRE_UPS,
    a.PROCEDIMIENTO_ID_SERVICIO_ORIGEN,

    -- DIAGNÓSTICOS CONCATENADOS
    d.DIAGNOSTICOS

FROM atencion a

-- SOLO registros de procedimientos
LEFT JOIN atencion_diagnostico ad
    ON ad.ID_ATENCION = a.id_atencion
   AND ad.ID_TIPO_DETALLE IN ('PRO','QUI')

-- PROCEDIMIENTO (LEFT para no perder atenciones)
LEFT JOIN ss_ge_procedimientomedico proc
    ON proc.CODIGOPROCEDIMIENTO = ad.ID_CPT

-- ESTABLECIMIENTO
INNER JOIN ac_sucursal i
    ON i.SUCURSAL = a.ID_IPRESS

-- PACIENTE
INNER JOIN personamast p
    ON p.PERSONA = a.PACIENTE_ID

-- RESPONSABLE SOLICITANTE
INNER JOIN atencion_responsable solic
    ON solic.ID_ATENCION = a.id_atencion
   AND solic.ID_TIPO_RESPONSABLE = 'RESP'

INNER JOIN personamast ps
    ON ps.PERSONA = solic.ID_EMPLEADO

-- RESPONSABLE PROCEDIMIENTO
INNER JOIN atencion_responsable resp
    ON resp.ID_ATENCION = a.id_atencion
   AND resp.ID_TIPO_RESPONSABLE = 'PROC'

INNER JOIN personamast pr
    ON pr.PERSONA = resp.ID_EMPLEADO

-- UPS
LEFT JOIN ups u
    ON u.CODIGOUPS = a.ID_UPS

-- DIAGNÓSTICOS CONCATENADOS
LEFT JOIN (
    SELECT
        ad2.ID_ATENCION,
        GROUP_CONCAT(
            DISTINCT CONCAT(
                sd.CODIGODIAGNOSTICO, ' - ', sd.NOMBRE
            )
            ORDER BY sd.CODIGODIAGNOSTICO
            SEPARATOR ' | '
        ) AS DIAGNOSTICOS
    FROM atencion_diagnostico ad2
    INNER JOIN ss_ge_diagnostico sd
        ON sd.IDDIAGNOSTICO = ad2.ID_DIAGNOSTICO
    WHERE ad2.ID_TIPO_DETALLE = 'DIA'
    GROUP BY ad2.ID_ATENCION
) d
    ON d.ID_ATENCION = a.id_atencion

WHERE a.id_tipo_atencion = 'PR'
  AND a.FECHA_ATENCION BETWEEN '2026-01-01' AND '2026-01-31'
  AND a.estado = 'A'
  AND i.CODIGOIPRESS IN ('00012088','00009320','00011661','00011773','00017336');

--  AND proc.CODIGOPROCEDIMIENTO='99499.01'; -- teleconsulta
