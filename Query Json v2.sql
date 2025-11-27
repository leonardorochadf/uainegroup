WITH hist AS (
    SELECT 
        h.id_tbl_plano_assinatura_benef,
        h.kWhDisponibilizadosMes,
        h.percent_desc_energia,
        h.valorMensalidade,
        h.aud_ins_dttm,
        ROW_NUMBER() OVER (
            PARTITION BY h.id_tbl_plano_assinatura_benef, YEAR(h.aud_ins_dttm), MONTH(h.aud_ins_dttm)
            ORDER BY h.aud_ins_dttm DESC
        ) AS rn
    FROM dbo.tbl_plano_assinatura_benef_hist h
),
detalhamento AS (
    SELECT 
        parceiro.nome AS parceiro, 
        YEAR(edp.mes_ano) AS ano, 
        CONCAT(
            'Semestre_', 
            CASE WHEN MONTH(edp.mes_ano) BETWEEN 1 AND 6 THEN 1 ELSE 2 END,
            '_',
            YEAR(edp.mes_ano)
        ) AS semestre,
        
        edp.mes_ano, 
        
        REPLACE(
            SUBSTRING(beneficiario.cpf_numero_instalacao, CHARINDEX('#', beneficiario.cpf_numero_instalacao), 100),
            '#',''
        ) AS instalacao, 
        
        beneficiario.cpf_cnpj_beneficiario, 
        beneficiario.nome_beneficiario,

        COALESCE(histFilt.kWhDisponibilizadosMes, plano_assinatura.kWhDisponibilizadosMes) AS kWhDisponibilizadosMes,
        COALESCE(histFilt.valorMensalidade, plano_assinatura.valorMensalidade)             AS valorMensalidade,
        COALESCE(histFilt.percent_desc_energia, plano_assinatura.percent_desc_energia)     AS percent_desc_energia,

        CAST(
            COALESCE(histFilt.valorMensalidade, plano_assinatura.valorMensalidade) /
            COALESCE(histFilt.kWhDisponibilizadosMes, plano_assinatura.kWhDisponibilizadosMes)
            AS NUMERIC(15,2)
        ) AS valor_kwh,

        CASE 
            WHEN concessionaria.valor_medio_kwh = 0 THEN 0
            ELSE 
                CASE 
                    WHEN 1 - ( 
                        (COALESCE(histFilt.valorMensalidade, plano_assinatura.valorMensalidade) /
                         COALESCE(histFilt.kWhDisponibilizadosMes, plano_assinatura.kWhDisponibilizadosMes))
                        /
                        concessionaria.valor_medio_kwh
                    ) < 0
                    THEN 0
                    ELSE 
                        ROUND(
                            100 * (
                                1 - (
                                    (COALESCE(histFilt.valorMensalidade, plano_assinatura.valorMensalidade) /
                                     COALESCE(histFilt.kWhDisponibilizadosMes, plano_assinatura.kWhDisponibilizadosMes))
                                    /
                                    concessionaria.valor_medio_kwh
                                )
                            ), 2
                        )
                END
        END AS percentual_desconto_aplicado,

        kwh.fora_ponta_int + kwh.ponta_int AS edp_total_kwh,

        CASE 
            WHEN (kwh.fora_ponta_int + kwh.ponta_int) > 0 THEN
                (kwh.fora_ponta_int + kwh.ponta_int) -
                COALESCE(histFilt.kWhDisponibilizadosMes, plano_assinatura.kWhDisponibilizadosMes)
            ELSE 0 
        END AS edp_dif_recebidos_x_contratado,

        plano_assinatura.id_tbl_plano_assinatura_benef,
        concessionaria.valor_medio_kwh AS valor_kwh_edp
    FROM tbl_beneficiario beneficiario 

    INNER JOIN dbo.tbl_usina_energia_injetada_unidade_kwh edp 
        ON edp.numero_instalacao_beneficiario =
            REPLACE(
                SUBSTRING(beneficiario.cpf_numero_instalacao, CHARINDEX('#', beneficiario.cpf_numero_instalacao), 100),
                '#',''
            )

    INNER JOIN dbo.tbl_plano_assinatura_benef plano_assinatura
        ON plano_assinatura.id_tbl_plano_assinatura_benef =
           beneficiario.tbl_plano_assinatura_beneficiario_id_tbl_plano_assinatura_benef

    LEFT JOIN hist histFilt
        ON histFilt.id_tbl_plano_assinatura_benef = plano_assinatura.id_tbl_plano_assinatura_benef
        AND histFilt.rn = 1
        AND YEAR(histFilt.aud_ins_dttm) = YEAR(edp.mes_ano)
        AND MONTH(histFilt.aud_ins_dttm) = MONTH(edp.mes_ano)

    INNER JOIN dbo.tbl_usina_tbl_beneficiario benef_usina
        ON benef_usina.tbl_beneficiario_id_beneficiario = beneficiario.id_beneficiario

    INNER JOIN dbo.tbl_usina usina
        ON usina.id_tbl_usina = benef_usina.tbl_usina_id_tbl_usina 

    INNER JOIN dbo.tbl_parceiro parceiro
        ON parceiro.id_parceiros = beneficiario.tbl_parceiro_id_parceiros

    INNER JOIN dbo.tbl_concessionaria_semestre_kwh concessionaria
        ON concessionaria.id_concessionaria = usina.tbl_concessionaria_id_concessionaria
        AND concessionaria.ano = YEAR(edp.mes_ano)
        AND concessionaria.semestre =
            CASE WHEN MONTH(edp.mes_ano) BETWEEN 1 AND 6 THEN 1 ELSE 2 END

    CROSS APPLY (
        SELECT 
            CONVERT(bigint,
                LEFT(
                    REPLACE(ISNULL(edp.fora_ponta_kwh, '0'), '.', ''),
                    CASE WHEN CHARINDEX(',', REPLACE(ISNULL(edp.fora_ponta_kwh, '0'), '.', '')) > 0 
                            THEN CHARINDEX(',', REPLACE(ISNULL(edp.fora_ponta_kwh, '0'), '.', '')) - 1
                         ELSE LEN(REPLACE(ISNULL(edp.fora_ponta_kwh, '0'), '.', ''))
                    END
                )
            ) AS fora_ponta_int,

            CONVERT(bigint,
                LEFT(
                    REPLACE(ISNULL(edp.ponta_kwh, '0'), '.', ''),
                    CASE WHEN CHARINDEX(',', REPLACE(ISNULL(edp.ponta_kwh, '0'), '.', '')) > 0 
                            THEN CHARINDEX(',', REPLACE(ISNULL(edp.ponta_kwh, '0'), '.', '')) - 1
                         ELSE LEN(REPLACE(ISNULL(edp.ponta_kwh, '0'), '.', ''))
                    END
                )
            ) AS ponta_int
    ) AS kwh

    WHERE 
        REPLACE(
            SUBSTRING(beneficiario.cpf_numero_instalacao, CHARINDEX('#', beneficiario.cpf_numero_instalacao), 100),
            '#',''
        ) IN (
            '506281','1921756','1921762','1990889','506279',
            '634374','1506204','596654','1485359'
        )
        AND YEAR(edp.mes_ano) >= 2023
        AND usina.nome_usina = 'USINASOLARES'
),
geral AS (
    SELECT 
        geral.[numero_instalacao_geradora],
        FORMAT(geral.mes_ano, 'yyyy-MM')	AS [mes_ano],
        YEAR(geral.mes_ano)					AS [ano],
        geral.[fora_ponta_kwh]				AS total_kwh_gerado
    FROM 
        dbo.tbl_usina_energia_injetada_total_kwh geral
    WHERE 
        geral.numero_instalacao_geradora = '161073905'
)

SELECT 
    (
        SELECT * FROM detalhamento
        FOR JSON PATH
    ) AS detalhamento_beneficiarios,
    (
        SELECT * FROM geral
        FOR JSON PATH
    ) AS geral_usina

FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
