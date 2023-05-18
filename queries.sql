--------------
-- Function --

CREATE FUNCTION calcularVitorias(@idCiclista INT)
RETURNS INT
AS
BEGIN
    DECLARE @vitorias INT;

    SELECT @vitorias = COUNT(*) 
    FROM estatistica
    WHERE Idciclista = @idCiclista
    AND IdTipo = 1
    AND valor = 1;

    RETURN @vitorias;
END;

DECLARE @idCiclista INT;
SET @idCiclista = 1; -- mudar pelo id do ciclista que queremos

SELECT nome, dbo.calcularVitorias(IdCiclista) AS vitorias
FROM ciclista
WHERE IdCiclista = @idCiclista;

------------------
-- Procedimento -- está a classificar sempre como trepador pois os dados são demasiado semelhantes mas funciona

CREATE PROCEDURE classificarCiclistasPorAno
AS
BEGIN
    IF OBJECT_ID('tempdb..#Classificacoes') IS NOT NULL
        DROP TABLE #Classificacoes;

    CREATE TABLE #Classificacoes (
        IdCiclista INT,
        AnoEtapa DECIMAL(4,0),
        Tipo VARCHAR(20)
    );

    DECLARE @AnoEtapa DECIMAL(4,0);
    SET @AnoEtapa = (SELECT MIN(anoEtapa) FROM etapa);

    WHILE @AnoEtapa IS NOT NULL
    BEGIN
        INSERT INTO #Classificacoes (IdCiclista, AnoEtapa, Tipo)
        SELECT c.IdCiclista,
            @AnoEtapa,
            CASE
                WHEN montanhas.Cnt > 5 THEN 'Trepador'
                WHEN sprints.Cnt > 5 THEN 'Velocista'
                ELSE 'Normal'
            END
        FROM ciclista c
        LEFT JOIN (
            SELECT es.IdCiclista, COUNT(*) AS Cnt
            FROM estatistica es
            INNER JOIN etapa e ON es.IdEtapa = e.IdEtapa
            WHERE es.IdTipo = 12 AND e.anoEtapa = @AnoEtapa
            GROUP BY es.IdCiclista
        ) montanhas ON c.IdCiclista = montanhas.IdCiclista
        LEFT JOIN (
            SELECT es.IdCiclista, COUNT(*) AS Cnt
            FROM estatistica es
            INNER JOIN etapa e ON es.IdEtapa = e.IdEtapa
            WHERE es.IdTipo = 13 AND e.anoEtapa = @AnoEtapa
            GROUP BY es.IdCiclista
        ) sprints ON c.IdCiclista = sprints.IdCiclista;

        SET @AnoEtapa = (SELECT MIN(anoEtapa) FROM etapa WHERE anoEtapa > @AnoEtapa);
    END;

    SELECT c.nome, cl.AnoEtapa, cl.Tipo
    FROM ciclista c
    LEFT JOIN #Classificacoes cl ON c.IdCiclista = cl.IdCiclista
    ORDER BY cl.AnoEtapa DESC;

    DROP TABLE #Classificacoes;
END;

exec classificarCiclistasPorAno;

