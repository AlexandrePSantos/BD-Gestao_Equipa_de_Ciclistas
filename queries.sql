--------------
-- Instruções SQL --
-- 1. media de km na volta toda/ano 
SELECT e.anoEtapa, AVG(c.total_km) AS media_km
FROM ciclista c
JOIN estatistica est ON c.Idciclista = est.Idciclista
JOIN etapa e ON est.IdEtapa = e.IdEtapa
GROUP BY e.anoEtapa;

-- 2. soma do numero de vitorias daquele ano
SELECT c.Idciclista, c.nome, SUM(CASE WHEN e.valor = 1 AND e.IdTipo = 1 THEN 1 ELSE 0 END) AS NumVitorias
FROM estatistica e
INNER JOIN ciclista c ON e.Idciclista = c.Idciclista
GROUP BY c.Idciclista, c.nome;

-- 3. apresenta  a media de km de cada etapa durante os anos todos
SELECT e.numEtapa, AVG(est.valor) AS media_km
FROM etapa e
INNER JOIN estatistica est ON e.IdEtapa = est.IdEtapa
WHERE est.IdTipo = 2
GROUP BY e.numEtapa;

--------------
-- View -- 
-- 1º -> criar user WebAPP com permissão de leitura (SELECT) apenas:
CREATE LOGIN WebAPP WITH PASSWORD = '123456';
CREATE USER WebAPP FOR LOGIN WebAPP;
-- 2º -> view:
CREATE VIEW PodiosCorredores AS
SELECT Corredor, numEtapa, anoEtapa, loc_partida, loc_chegada, TipoEstatistica, ValorEstatistica
FROM (
    SELECT c.nome AS Corredor, e.numEtapa, e.anoEtapa, e.loc_partida, e.loc_chegada, t.tipo 
    AS TipoEstatistica, es.valor AS ValorEstatistica,
    ROW_NUMBER() OVER (PARTITION BY c.nome, e.numEtapa ORDER BY c.nome, e.numEtapa) AS RowNumber
    FROM ciclista c
    JOIN estatistica es ON c.Idciclista = es.Idciclista
    JOIN etapa e ON es.IdEtapa = e.IdEtapa
    JOIN tipoEst t ON es.IdTipo = t.IdTipo
) AS Podios
WHERE RowNumber <= 3;

SELECT * from PodiosCorredores;

GRANT SELECT ON PodiosCorredores TO WebAPP;

--------------
-- Triggers --
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

-- Validação 
CREATE TRIGGER validacao_insert
ON estatistica
BEFORE INSERT
AS
BEGIN
    -- Verificar se os campos estão vazios
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE Idciclista IS NULL OR IdEtapa IS NULL OR IdTipo IS NULL OR valor IS NULL
              OR Idciclista = '' OR IdEtapa = '' OR IdTipo = '' OR valor = ''
    )
    BEGIN
        RAISERROR ('Todos os campos devem ser preenchidos.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- Inserir os dados válidos na tabela
    INSERT INTO estatistica (Idciclista, IdEtapa, IdTipo, valor)
    SELECT Idciclista, IdEtapa, IdTipo, valor
    FROM inserted;
END

--------------
-- Cursores -- tem erros nas horas
-- READ ONLY
DECLARE @Posicao VARCHAR(25);
DECLARE @AnoEtapa decimal(4);
DECLARE @numEtapa int;
DECLARE @Nome VARCHAR(30);
DECLARE @TempoProva DECIMAL(10,2);

DECLARE Clas_ciclista CURSOR FOR
SELECT TC.nome, TP.numEtapa, TP.anoEtapa, TE.valor
FROM estatistica TE
INNER JOIN ciclista TC ON TE.Idciclista = TC.Idciclista
INNER JOIN etapa TP ON TE.IdEtapa = TP.IdEtapa;

OPEN Clas_ciclista
FETCH NEXT FROM Clas_ciclista INTO @Nome, @numEtapa, @AnoEtapa, @TempoProva

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @Horas INT, @Minutos INT;
    
    SET @Horas = FLOOR(@TempoProva / 60);
    SET @Minutos = FLOOR(@TempoProva % 60);

    SELECT '  POSICAO  |  ANO PROVA  |  NUMERO ETAPA  |  NOME   |  TEMPO PROVA  '
    UNION ALL
    SELECT '--------------------------------------------------------------------------------------'
    UNION ALL
    SELECT '  ' + @Posicao + REPLICATE(' ', 9 - LEN(@Posicao)) + '|  ' + CONVERT(VARCHAR(4), @AnoEtapa) + REPLICATE(' ', 11 - LEN(CONVERT(VARCHAR(4), @AnoEtapa))) + '|  ' + CONVERT(VARCHAR(2), @numEtapa) + REPLICATE(' ', 14 - LEN(CONVERT(VARCHAR(2), @numEtapa))) + '|  ' + @Nome + REPLICATE(' ', 23 - LEN(@Nome)) + '|  ' + RIGHT('00' + CONVERT(VARCHAR(2), @Horas), 2) + ':' + RIGHT('00' + CONVERT(VARCHAR(2), @Minutos), 2)

    FETCH NEXT FROM Clas_ciclista INTO @Nome, @numEtapa, @AnoEtapa, @TempoProva
END

CLOSE Clas_ciclista
DEALLOCATE Clas_ciclista

-- UPDATE -- atualizar a tabela ciclista 
DECLARE @Idciclista INT;
DECLARE @Valor DECIMAL(15, 1);

DECLARE cursorAtualizar CURSOR FOR
SELECT Idciclista, valor
FROM estatistica;

OPEN cursorAtualizar;

FETCH NEXT FROM cursorAtualizar INTO @Idciclista, @Valor;

WHILE @@FETCH_STATUS = 0
BEGIN
    UPDATE ciclista
    SET total_km = total_km + @Valor,
        total_elevacao = total_elevacao + @Valor,
        maior_distancia = CASE WHEN @Valor > maior_distancia THEN @Valor ELSE maior_distancia END,
        maior_elevacao = CASE WHEN @Valor > maior_elevacao THEN @Valor ELSE maior_elevacao END,
        total_vitorias = total_vitorias + 1
    WHERE Idciclista = @Idciclista;

    FETCH NEXT FROM cursorAtualizar INTO @Idciclista, @Valor;
END;

CLOSE cursorAtualizar;
DEALLOCATE cursorAtualizar;

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

--------------
-- SP's -- 
-- Inserir
CREATE PROCEDURE sp_InserirDados
    @nome varchar(25),
    @total_km decimal(15,1),
    @total_elevacao decimal(15,1),
    @maior_distancia decimal(10,1),
    @maior_elevacao decimal(10,1),
    @total_vitorias int
AS
BEGIN
    INSERT INTO ciclista (nome, total_km, total_elevacao, maior_distancia, maior_elevacao, total_vitorias)
    VALUES (@nome, @total_km, @total_elevacao, @maior_distancia, @maior_elevacao, @total_vitorias);
END

-- Atualizar
CREATE PROCEDURE sp_AtualizarDados
    @IdCiclista int,
    @nome varchar(25),
    @total_km decimal(15,1),
    @total_elevacao decimal(15,1),
    @maior_distancia decimal(10,1),
    @maior_elevacao decimal(10,1),
    @total_vitorias int
AS
BEGIN
    UPDATE ciclista
    SET nome = @nome,
        total_km = @total_km,
        total_elevacao = @total_elevacao,
        maior_distancia = @maior_distancia,
        maior_elevacao = @maior_elevacao,
        total_vitorias = @total_vitorias
    WHERE IdCiclista = @IdCiclista;
END

-- Apagar
CREATE PROCEDURE sp_RemoverDados
    @IdCiclista int
AS
BEGIN
    DELETE FROM ciclista
    WHERE IdCiclista = @IdCiclista;
END

-- Controle de Transação e Tratamento de Erros
CREATE PROCEDURE sp_TransacaoExemplo
    @IdEtapa int,
    @IdCiclista int,
    @IdTipo int,
    @valor decimal(15, 1)
AS
BEGIN
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Inserir dados na tabela estatistica
        INSERT INTO estatistica (IdEtapa, IdCiclista, IdTipo, valor)
        VALUES (@IdEtapa, @IdCiclista, @IdTipo, @valor);

        -- Atualizar dados na tabela ciclista
        UPDATE ciclista
        SET total_km = total_km + @valor,
            total_vitorias = total_vitorias + 1
        WHERE IdCiclista = @IdCiclista;
        COMMIT;
    END TRY
    BEGIN CATCH
        -- Lidar com erros
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH;
END

------------------
-- Procedimentos -- classificar como trepador e velocista
CREATE PROCEDURE classificarCiclistasPorAno
AS
BEGIN
    IF OBJECT_ID('tempdb..#Classificacoes') IS NOT NULL
        DROP TABLE #Classificacoes;

    CREATE TABLE #Classificacoes (
        IdCiclista INT,
        AnoEtapa DECIMAL(4,0),
        Trepador VARCHAR(3),
        Velocista VARCHAR(3)
    );

    DECLARE @AnoEtapa DECIMAL(4,0);
    SET @AnoEtapa = (SELECT MIN(anoEtapa) FROM etapa);

    WHILE @AnoEtapa IS NOT NULL
    BEGIN
        INSERT INTO #Classificacoes (IdCiclista, AnoEtapa, Trepador, Velocista)
        SELECT c.IdCiclista,
            @AnoEtapa,
            CASE WHEN montanhas.Cnt > 5 THEN 'Sim' ELSE 'Não' END,
            CASE WHEN sprints.Cnt > 5 THEN 'Sim' ELSE 'Não' END
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

    SELECT c.nome, cl.AnoEtapa, cl.Trepador, cl.Velocista
    FROM ciclista c
    LEFT JOIN #Classificacoes cl ON c.IdCiclista = cl.IdCiclista
    ORDER BY cl.AnoEtapa DESC;

    DROP TABLE #Classificacoes;
END;

EXEC classificarCiclistasPorAno;

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
-- PIVOT -- calcular a média de valores de estatistica por tipo para cada ciclista com pivot
SELECT *
FROM (SELECT Idciclista, IdTipo, valor FROM estatistica) AS src
PIVOT (AVG(valor) FOR IdTipo IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12], [13], [14], [15])) AS pivoted
ORDER BY Idciclista;

------------------
-- ROW_NUMBER -- numerar linhas sequencialmente
SELECT ROW_NUMBER() OVER (ORDER BY Idciclista) AS Numeracao, *
FROM ciclista;

------------------
-- RANK --  numerar linhas sequencialmente
SELECT RANK() OVER (ORDER BY total_km DESC) AS Classificacao, *
FROM ciclista;

------------------
-- DENSE_RANK -- obter a classificação dos ciclistas por total_vitorias
SELECT DENSE_RANK() OVER (ORDER BY total_vitorias DESC) AS Classificacao, *
FROM ciclista;

------------------
-- PARTITION BY -- obter a média das estatísticas por tipo para cada ciclista e ano
SELECT c.nome, e.anoEtapa, te.tipo, AVG(es.valor) AS media_valor
FROM ciclista c
INNER JOIN estatistica es ON c.Idciclista = es.Idciclista
INNER JOIN etapa e ON es.IdEtapa = e.IdEtapa
INNER JOIN tipoEst te ON es.IdTipo = te.IdTipo
GROUP BY c.nome, e.anoEtapa, te.tipo
ORDER BY e.anoEtapa, c.nome, te.tipo;


------------------
-- implementar o filestream incluindo procedimentos de inserção
-- Create database for filestream
CREATE DATABASE FileStreamDB
ON
PRIMARY ( NAME = FileStreamDB,
      FILENAME = 'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\BDFilestream\FileStreamDB.mdf'),
      FILEGROUP FileStreamDBFS CONTAINS FILESTREAM(
      NAME = FileStreamDBFS,
    FILENAME = 'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\BDFilestream\FileStreamDBFS')
LOG ON (                        
      NAME = FileStreamDBLOG,
    FILENAME = 'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\BDFilestream\FileStreamDBLOG.ldf')
GO

-- A especificação da palavra-chave CONTAINS FILESTREAM como parte da instrução CREATE DATABASE ativa o suporte ao FILESTREAM para esta base de dados.

-- Create table for filestream
CREATE TABLE [dbo].[FileStreamTable](
   [FSID] UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL UNIQUE,
   [FSDescription] VARCHAR(50),
   [FSBLOB] VARBINARY(MAX) FILESTREAM NULL)


-- Inserir dados binários numa tabela FILESTREAM
INSERT into dbo.FileStreamTable VALUES ( newid(), 'Ciclista_1',(select * from
OPENROWSET(BULK N'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\ciclistas\ciclista_1.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTable VALUES ( newid(), 'Ciclista_2',(select * from
OPENROWSET(BULK N'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\ciclistas\ciclista_2.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTable VALUES ( newid(), 'Ciclista_3',(select * from
OPENROWSET(BULK N'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\ciclistas\ciclista_3.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTable VALUES ( newid(), 'Ciclista_4',(select * from
OPENROWSET(BULK N'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\ciclistas\ciclista_4.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTable VALUES ( newid(), 'Ciclista_5',(select * from
OPENROWSET(BULK N'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\ciclistas\ciclista_5.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTable VALUES ( newid(), 'Ciclista_6',(select * from
OPENROWSET(BULK N'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\ciclistas\ciclista_6.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTable VALUES ( newid(), 'Ciclista_7',(select * from
OPENROWSET(BULK N'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\ciclistas\ciclista_7.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTable VALUES ( newid(), 'Ciclista_8',(select * from
OPENROWSET(BULK N'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\ciclistas\ciclista_8.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTable VALUES ( newid(), 'Ciclista_9',(select * from
OPENROWSET(BULK N'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\ciclistas\ciclista_9.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTable VALUES ( newid(), 'Ciclista_10',(select * from
OPENROWSET(BULK N'C:\Users\ruijo\OneDrive\Documentos\GitHub\Trab.Pratico\ciclistas\ciclista_10.jpg',SINGLE_BLOB) as FS))


.-.-.-.-.-.-.-.-.-.-.-.
-- FEITOS NA TAREFA --
.-.-.-.-.-.-.-.-.-.-.-.



-- Fazer análise de uma consulta mais pesada com Execution Plan;
-- Com o Database Engine Tuning Advisor analisar e aplicar recomendações;
-- Voltar a analisar para tirar conclusões;


-- Construir um Database Maintenance, demonstrável, que reorganize Dados
-- e Indices, valide a Integridade de dados, faça uma cópia de segurança da
-- Base de Dados mantendo um histórico de 1 mês e que ocorra todos os
-- dias às 01:00H. Notificar ainda o Administrador da Base de Dados 
-- do estado da execução (Com Sucesso ou Falha) através do envio de um email.

-- Com SSRS elaborar um relatório com gráfico e registos em tabela, será
-- valorizado a análise e a qualidade da informação apresentada



.-.-.-.-.-.-.-.
-- OPCIONAIS --
.-.-.-.-.-.-.-.

-- Procedimento que insira numa tabela baseado num formato JSON --


-- Procedimento que retorna e transforme um conjunto de dados de uma tabela num formato JSON --


-- Procedimento/trigger que inclua notifica¸c˜ao por email (TSQL) --





























