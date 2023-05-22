--------------
-- Instruções SQL --
-- 1. media de km na volta toda/ano 
SELECT anoEtapa, AVG(total_km) AS media_km
FROM etapa
GROUP BY anoEtapa;

-- 2. soma do numero de vitorias daquele ano
SELECT c.Idciclista, c.nome, SUM(CASE WHEN e.valor = 1 AND e.IdTipo = 1 THEN 1 ELSE 0 END) AS NumVitorias
FROM estatistica e
INNER JOIN ciclista c ON e.Idciclista = c.Idciclista
GROUP BY c.Idciclista, c.nome;

-- 3. apresenta  a media de km de cada etapa durante os anos todos --- corrigir
SELECT e.IdEtapa, e.numEtapa, AVG(est.valor) AS media_km
FROM etapa e
INNER JOIN estatistica est ON e.IdEtapa = est.IdEtapa
WHERE est.IdTipo = 2
GROUP BY e.IdEtapa, e.numEtapa;

--------------
-- Views -- apresentar todos os podios de um corredor com todos os dados dessa todos os dados dessa prova 
--- nao esta a apresentar todos os dados e nao sei se esta muito complexa
CREATE VIEW InformacoesCorrida AS
SELECT e.IdEtapa, e.numEtapa, e.anoEtapa, e.loc_partida, e.loc_chegada
FROM etapa e
INNER JOIN estatistica est ON e.IdEtapa = est.IdEtapa
WHERE est.IdTipo = 1 AND est.valor = 1 AND est.Idciclista = 5;

--------------
-- Triggers -- corrigir
-- Disparado
CREATE TRIGGER soma_valores
ON estatistica
AFTER INSERT
AS
BEGIN
    UPDATE c
    SET total_km = c.total_km + i.valor,
        total_elevacao = c.total_elevacao + i.valor,
        maior_distancia = CASE WHEN i.valor > c.maior_distancia THEN i.valor ELSE c.maior_distancia END,
        maior_elevacao = CASE WHEN i.valor > c.maior_elevacao THEN i.valor ELSE c.maior_elevacao END,
        total_vitorias = c.total_vitorias + 1
    FROM ciclista c
    INNER JOIN inserted i ON c.IdCiclista = i.IdCiclista
END

-- Validação --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


--------------
-- Cursores --
-- READ ONLY
DECLARE @Horas INT, @Minutos INT, @Segundos INT;
DECLARE @Posicao VARCHAR(25);
DECLARE @AnoEtapa decimal(4);
DECLARE @numEtapa int;
DECLARE @Nome VARCHAR(30);
DECLARE @TempoProva DECIMAL(10,2);

DECLARE Clas_ciclista CURSOR FOR
SELECT TC.nome, TP.numEtapa, TP.anoEtapa, TE.valor
FROM estatistica TE
INNER JOIN ciclista TC ON TE.Idciclista = TC.Idciclista;
INNER JOIN etapa TP ON TE.IdEtapa = TP.IdEtapa;

OPEN Clas_ciclista
FETCH NEXT FROM Clas_ciclista INTO @Horas, @Minutos, @Segundos, @Posicao, @AnoEtapa, @numEtapa, @Nome, @TempoProva

WHILE @@FETCH_STATUS = 0
BEGIN

    SET @Horas = FLOOR(@TempoProva / 60);
    SET @Minutos = FLOOR((@TempoProva / 60) % 60);

    PRINT '  POSICAO  |  ANO PROVA  |  NUMERO ETAPA  |  NOME                   |  TEMPO PROVA  '
    PRINT '--------------------------------------------------------------------------------------'
    PRINT '  ' + @Posicao + REPLICATE(' ', 9 - LEN(@Posicao)) + '|  ' + @AnoEtapa + REPLICATE(' ', 11 - LEN(@AnoEtapa)) + '|  ' + @numEtapa + REPLICATE(' ', 14 - LEN(@numEtapa)) + '|  ' + @Nome + REPLICATE(' ', 23 - LEN(@Nome)) + '|  ' + RIGHT('00' + CONVERT(VARCHAR(2), @Horas), 2) + ':' + RIGHT('00' + CONVERT(VARCHAR(2), @Minutos), 2)

    FETCH NEXT FROM Clas_ciclista INTO @Horas, @Minutos, @Segundos, @Posicao, @AnoEtapa, @numEtapa, @Nome, @TempoProva
END

CLOSE Clas_ciclista
DEALLOCATE Clas_ciclista

-- UPDATE --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
...

--------------
-- Functions --
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

--------------
-- SP's -- --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


------------------
-- Procedimentos -- está a classificar sempre como trepador pois os dados são demasiado semelhantes mas funciona
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

-- validar
CREATE PROCEDURE validar_insercao_estatistica
    @Idciclista int,
    @IdEtapa int,
    @IdTipo int ,
    @valor decimal(15,1),
AS
BEGIN
    DECLARE @maxIdciclista int, @maxIdTipo int;

    SELECT @maxIdciclista = MAX(Idciclista), @maxIdTipo = MAX(IdTipo) FROM ciclista;

    IF @Idciclista > @maxIdciclista
    BEGIN
        RAISERROR ('Erro: O Idciclista especificado não existe.', 16, 1);
        RETURN;
    END

    IF @IdTipo > @maxIdTipo
    BEGIN
        RAISERROR ('Erro: O IdTipo especificado não existe.', 16, 1);
        RETURN;
    END

    insert into estatistica (idciclista, idEtapa, idTipo, valor) values (@Idciclista, @IdEtapa, @IdTipo, @valor);

    PRINT 'Dados inseridos com sucesso.';
END

exec validar_insercao_estatistica;

------------------
-- PIVOT --
SELECT *
FROM
(
    SELECT IdTipo
    FROM estatistica
) AS src
PIVOT
(
    COUNT(IdTipo)
    FOR IdTipo IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12], [13], [14], [15]) 
) AS pivoted;

------------------
-- ROW_NUMBER --
SELECT ROW_NUMBER() OVER (ORDER BY idciclista) AS num, nome, total_km
FROM ciclista

------------------
-- RANK --
SELECT RANK() OVER (ORDER BY total_vitorias DESC) AS ranking, nome, total_vitorias
FROM ciclista

------------------
-- DENSE_RANK --
SELECT DENSE_RANK() OVER (ORDER BY total_vitorias DESC) AS ranking, nome, total_vitorias
FROM ciclista

------------------
-- PARTITION BY --
SELECT nome, equipe, total_km, RANK() OVER (PARTITION BY equipe ORDER BY total_km DESC) AS ranking
FROM ciclista





























