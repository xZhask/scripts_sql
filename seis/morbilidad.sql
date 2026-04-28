SELECT a.id_atencion,p.documento,a.ID_TIPO_ATENCION,a.ID_IPRESS,dx.codigodiagnostico, dx.nombre,p.SEXO,p.ID_BENEFICIARIO
FROM ATENCION a 
INNER JOIN atencion_diagnostico ad ON a.id_atencion = ad.id_atencion
INNER JOIN ss_ge_diagnostico dx ON dx.idDiagnostico=ad.id_diagnostico
INNER JOIN personamast p ON p.persona = a.paciente_id
INNER JOIN ac_sucursal i ON i.SUCURSAL = a.ID_IPRESS
WHERE a.id_tipo_atencion IN ('AM','EM','HO')
AND a.ESTADO='A'
AND ad.id_secuencia=1
AND ad.id_tipo_diagnostico='02'
AND a.ID_PERIODO IN('202601','202602','202603')
AND a.PACIENTE_EDAD > 17
#AND p.ID_BENEFICIARIO IN (1,2,3,4,5)
AND a.ID_IPRESS IN ('00012088','00009320','00011661','00011773','00017336');

#AND a.FECHA_ATENCION BETWEEN '2025-01-01' AND '2025-06-30'
#AND dx.CodigoDiagnostico NOT LIKE ('Z%')
# AND a.ID_PERIODO IN('202501','202502','202503','202504','202505','202506','202507','202508','202509')

# chiclayo : 00011833
# angamos : 00012822
# nivel 2 : 00011794, 00014718, 00016094