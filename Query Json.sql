SELECT 
parceiro.nome as parceiro, 
    YEAR(mes_ano) AS ano, 
    CONCAT(
        'Semestre_', 
        CASE 
            WHEN MONTH(mes_ano) BETWEEN 1 AND 6 THEN 1 
            ELSE 2 
        END,
        '_',
        YEAR(mes_ano)
    ) AS semestre,
    edp.mes_ano, 
    REPLACE((SUBSTRING(beneficiario.cpf_numero_instalacao, CHARINDEX('#', beneficiario.cpf_numero_instalacao), 100)), '#', '') AS instalacao, 
    beneficiario.cpf_cnpj_beneficiario, 
    beneficiario.nome_beneficiario,
    plano_assinatura.kWhDisponibilizadosMes,
    plano_assinatura.valorMensalidade,
	plano_assinatura.percent_desc_energia,
    CAST( plano_assinatura.valorMensalidade / plano_assinatura.kWhDisponibilizadosMes AS NUMERIC(15,2) ) valor_kwh,
    -- Soma correta dos kWh recebidos (somente parte inteira)
    kwh.fora_ponta_int + kwh.ponta_int AS edp_total_kwh,

    -- Diferen�a kWh recebidos x contratado
    CASE 
        WHEN (kwh.fora_ponta_int + kwh.ponta_int) > 0 THEN
            (kwh.fora_ponta_int + kwh.ponta_int)
            -
            (
                CASE 
                    WHEN beneficiario.id_beneficiario = 526 THEN 7300
                    ELSE plano_assinatura.kWhDisponibilizadosMes
                END
            )
        ELSE 0 
    END AS edp_dif_recebidos_x_contratado
, plano_assinatura.id_tbl_plano_assinatura_benef
, concessionaria.valor_medio_kwh as valor_kwh_edp
FROM tbl_beneficiario beneficiario 
INNER JOIN [dbo].[tbl_usina_energia_injetada_unidade_kwh] edp 
    ON edp.numero_instalacao_beneficiario = REPLACE((SUBSTRING(beneficiario.cpf_numero_instalacao, CHARINDEX('#', beneficiario.cpf_numero_instalacao), 100)), '#', '')  
INNER JOIN [dbo].[tbl_plano_assinatura_benef] plano_assinatura
    ON plano_assinatura.id_tbl_plano_assinatura_benef = beneficiario.tbl_plano_assinatura_beneficiario_id_tbl_plano_assinatura_benef
 INNER JOIN [dbo].[tbl_usina_tbl_beneficiario]			benef_usina             ON benef_usina.tbl_beneficiario_id_beneficiario             = beneficiario.id_beneficiario
 INNER JOIN [dbo].[tbl_usina]							usina                   ON usina.id_tbl_usina									    = benef_usina.tbl_usina_id_tbl_usina 
 INNER JOIN [dbo].[tbl_parceiro]						parceiro			    ON parceiro.id_parceiros									= beneficiario.tbl_parceiro_id_parceiros
 INNER JOIN [dbo].[tbl_concessionaria_semestre_kwh]		concessionaria			ON concessionaria.id_concessionaria							= usina.tbl_concessionaria_id_concessionaria 
 AND concessionaria.ano      = YEAR(edp.mes_ano)
 AND concessionaria.semestre =
        CASE 
            WHEN MONTH(edp.mes_ano) BETWEEN 1 AND 6 THEN 1
            ELSE 2
        END
-- Convers�o correta dos campos fora/ponta
CROSS APPLY (
    SELECT 
        -- Fora ponta: remove ponto e pega parte antes da v�rgula
        CONVERT(bigint,
            LEFT(
                REPLACE(ISNULL(edp.fora_ponta_kwh, '0'), '.', ''),
                CASE 
                    WHEN CHARINDEX(',', REPLACE(ISNULL(edp.fora_ponta_kwh, '0'), '.', '')) > 0 
                        THEN CHARINDEX(',', REPLACE(ISNULL(edp.fora_ponta_kwh, '0'), '.', '')) - 1
                    ELSE LEN(REPLACE(ISNULL(edp.fora_ponta_kwh, '0'), '.', ''))
                END
            )
        ) AS fora_ponta_int,

        -- Ponta: remove ponto e pega parte antes da v�rgula
        CONVERT(bigint,
            LEFT(
                REPLACE(ISNULL(edp.ponta_kwh, '0'), '.', ''),
                CASE 
                    WHEN CHARINDEX(',', REPLACE(ISNULL(edp.ponta_kwh, '0'), '.', '')) > 0 
                        THEN CHARINDEX(',', REPLACE(ISNULL(edp.ponta_kwh, '0'), '.', '')) - 1
                    ELSE LEN(REPLACE(ISNULL(edp.ponta_kwh, '0'), '.', ''))
                END
            )
        ) AS ponta_int
) AS kwh

WHERE 
    REPLACE((SUBSTRING(beneficiario.cpf_numero_instalacao, CHARINDEX('#', beneficiario.cpf_numero_instalacao), 100)), '#', '') IN (
        '506281','1921756','1921762','1990889','506279',
        '634374','1506204','596654','1485359'
    ) AND
	
        YEAR(mes_ano) >= 2023
	AND usina.nome_usina = 'USINASOLARES'
    AND edp.numero_instalacao_beneficiario = 506281

--FOR JSON PATH;
