SELECT 
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

    -- kWh sobrescrito quando id_beneficiario = 526
    CASE 
        WHEN beneficiario.id_beneficiario = 526 THEN 7300
        ELSE plano_assinatura.kWhDisponibilizadosMes
    END AS kWhDisponibilizadosMes,

    -- Mensalidade sobrescrita quando id_beneficiario = 526
    CASE 
        WHEN beneficiario.id_beneficiario = 526 THEN 7295.02
        ELSE plano_assinatura.valorMensalidade
    END AS valorMensalidade,

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

FROM tbl_beneficiario beneficiario 
INNER JOIN [dbo].[tbl_usina_energia_injetada_unidade_kwh] edp 
    ON edp.numero_instalacao_beneficiario = REPLACE((SUBSTRING(beneficiario.cpf_numero_instalacao, CHARINDEX('#', beneficiario.cpf_numero_instalacao), 100)), '#', '')  
INNER JOIN [dbo].[tbl_plano_assinatura_benef] plano_assinatura
    ON plano_assinatura.id_tbl_plano_assinatura_benef = beneficiario.tbl_plano_assinatura_beneficiario_id_tbl_plano_assinatura_benef

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
    )
    AND YEAR(mes_ano) >= 2023
  --  AND edp.numero_instalacao_beneficiario = 1485359

FOR JSON PATH;
