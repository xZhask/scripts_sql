-- EST. INDIVIDUAL
select e.codigo AS "CODIGO IPRESS", e.nombre AS "IPRESS", aes.id AS "ID ATENCIÓN",aea.id_estrategia AS "CODIGO ESTRATÉGIA",
es.nombre AS "DESCRIPCIÓN ESTRATÉGIA" , a.nro_doc_ident AS "DNI PACIENTE", CONCAT(a.paterno,' ',a.materno,', ', a.nombre) as "NOMBRE PACIENTE",
a.sexo as "SEXO", EXTRACT(YEAR FROM AGE(aes.fecha_atencion, a.fecha_nac::date)) AS "EDAD", tb.descripcion AS "BENEFICIARIO", med.dni as "DNI RESPONSABLE",
CONCAT(med.paterno,' ',med.materno,', ', med.nombre) as "NOMBRE DE RESPONSABLE", med.colegiatura AS "COLEGIATURA",cp.descripcion AS "COLEGIO DE RESPONSABLE",
aes.id_upss AS "CODIGO UPS",u.descripcion_upss AS "UPS DESCRIPCIÓN",dx.codigo AS "CIE10",dx.nombre AS "DESCRIPCIÓN DIAGNÓSTICO",aea.observacion AS "OBSERVACIÓN"
from atencion_estrategia_sanitaria aes
left join atencion_estrategia_actividad aea ON aea.id_atencion_estrategia=aes.id
left join tipo_atenciones ta ON aes.id_tipo_atencion=ta.id
left join estrategia_sanitaria es ON es.codigo = aea.id_estrategia
left join atencion_estrategia_diagnostico aed ON aed.id_atencion_estrategia=aes.id
left join upsses u ON u.id=aes.id_upss
left join establecimientos e ON e.id=aes.id_establecimiento
left join asegurados a ON a.id = aes.id_asegurado
left join tipo_beneficiarios tb ON tb.id=a.id_tipo_beneficiario
left join diagnosticos dx ON aed.id_diagnostico = dx.id
left join medicos med ON med.id=aes.id_medico
left join colegio_profesionales cp ON cp.id=med.id_colegio_profesional
where aes.fecha_atencion >='2026-03-01' and	aes.fecha_atencion <'2026-04-01'
AND aes.tipo_estrategia=1
AND aes.estado=1;