--------------
-- Instruções SQL --
-- 1. total de km por ciclista por ano
SELECT c.nome, e.anoEtapa, SUM(est.valor) AS total_km
FROM ciclista c
JOIN estatistica est ON c.Idciclista = est.Idciclista
JOIN etapa e ON est.IdEtapa = e.IdEtapa
WHERE est.IdTipo = 2
GROUP BY c.nome, e.anoEtapa
ORDER BY c.nome, e.anoEtapa;

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
    -- Atualização do total_km para cada ciclista
    UPDATE c
    SET total_km = c.total_km + i.valor
    FROM ciclista c
    INNER JOIN inserted i ON c.IdCiclista = i.IdCiclista
    WHERE i.IdTipo = 2;

    -- Atualização do total_elevacao para cada ciclista
    UPDATE c
    SET total_elevacao = c.total_elevacao + i.valor
    FROM ciclista c
    INNER JOIN inserted i ON c.IdCiclista = i.IdCiclista
    WHERE i.IdTipo = 3;

    -- Atualização da maior_distancia para cada ciclista
    UPDATE c
    SET maior_distancia = CASE
        WHEN i.valor > c.maior_distancia THEN i.valor
        ELSE c.maior_distancia
    END
    FROM ciclista c
    INNER JOIN inserted i ON c.IdCiclista = i.IdCiclista
    WHERE i.IdTipo = 2;

    -- Atualização da maior_elevacao para cada ciclista
    UPDATE c
    SET maior_elevacao = CASE
        WHEN i.valor > c.maior_elevacao THEN i.valor
        ELSE c.maior_elevacao
    END
    FROM ciclista c
    INNER JOIN inserted i ON c.IdCiclista = i.IdCiclista
    WHERE i.IdTipo = 3;

    -- Atualização do total_vitorias para cada ciclista
    UPDATE c
    SET total_vitorias = c.total_vitorias + 1
    FROM ciclista c
    INNER JOIN inserted i ON c.IdCiclista = i.IdCiclista
    WHERE i.valor = 1 AND i.IdTipo = 1;
END;

-- Validação 

CREATE TRIGGER validacao_insert
ON estatistica
INSTEAD OF INSERT
AS
BEGIN
    -- Verificar se os campos estão vazios
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE ISNULL(Idciclista, '') = '' OR ISNULL(IdEtapa, '') = '' OR ISNULL(IdTipo, '') = '' OR ISNULL(valor, '') = ''
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
END;


--------------
-- Cursores --
-- READ ONLY
DECLARE @AnoEtapa DECIMAL(4);
DECLARE @NumEtapa INT;
DECLARE @Nome VARCHAR(30);
DECLARE @TempoProva DECIMAL(10,2);
DECLARE @Horas INT;
DECLARE @Minutos INT;

DECLARE @Result TABLE (
    AnoEtapa DECIMAL(4),
    NumEtapa INT,
    Nome VARCHAR(30),
    TempoProva VARCHAR(5)
)

DECLARE Clas_ciclista CURSOR LOCAL STATIC READ_ONLY FOR
SELECT TP.anoEtapa,
       TP.numEtapa,
       TC.nome,
       TE.valor
FROM estatistica TE
INNER JOIN ciclista TC ON TE.Idciclista = TC.Idciclista
INNER JOIN etapa TP ON TE.IdEtapa = TP.IdEtapa
WHERE TE.IdTipo = 5
ORDER BY TP.anoEtapa, TP.numEtapa, TC.nome;

OPEN Clas_ciclista
FETCH NEXT FROM Clas_ciclista INTO @AnoEtapa, @NumEtapa, @Nome, @TempoProva

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Horas = FLOOR(@TempoProva / 60);
    SET @Minutos = @TempoProva % 60;

    INSERT INTO @Result (AnoEtapa, NumEtapa, Nome, TempoProva)
    VALUES (@AnoEtapa, @NumEtapa, @Nome, RIGHT('0' + CONVERT(VARCHAR(2), @Horas), 2) + ':' + RIGHT('0' + CONVERT(VARCHAR(2), @Minutos), 2))

    FETCH NEXT FROM Clas_ciclista INTO @AnoEtapa, @NumEtapa, @Nome, @TempoProva
END

CLOSE Clas_ciclista
DEALLOCATE Clas_ciclista

SELECT * FROM @Result

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
    @valor decimal(15,1)
AS
BEGIN
    DECLARE @maxIdciclista int, @maxIdEtapa int, @maxIdTipo int;

    SELECT @maxIdciclista = MAX(Idciclista) FROM ciclista;
	SELECT @maxIdTipo = MAX(IdTipo) FROM tipoEst;
	SELECT @maxIdEtapa = MAX(IdEtapa) FROM etapa;

    IF @Idciclista > @maxIdciclista
    BEGIN
        RAISERROR ('Erro: O Idciclista especificado não existe.', 16, 1);
        RETURN;
    END

    IF @IdEtapa > @maxIdEtapa
    BEGIN
        RAISERROR ('Erro: O IdEtapa especificado não existe.', 16, 1);
        RETURN;
    END

    IF @IdTipo > @maxIdTipo
    BEGIN
        RAISERROR ('Erro: O IdTipo especificado não existe.', 16, 1);
        RETURN;
    END

    INSERT INTO estatistica (Idciclista, IdEtapa, IdTipo, valor) VALUES (@Idciclista, @IdEtapa, @IdTipo, @valor);

    PRINT 'Dados inseridos com sucesso.';
END;

--Erro
EXEC validar_insercao_estatistica @Idciclista = 1, @IdEtapa = 1, @IdTipo = 31, @valor = 10.5;
--Sucesso
EXEC validar_insercao_estatistica @Idciclista = 1, @IdEtapa = 1, @IdTipo = 1, @valor = 10.5;

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
-- Create table for filestream
CREATE TABLE [dbo].[FileStreamTablevoltaPT](
    [Idciclista] INT,
    [FSID] UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL UNIQUE,
    [FSDescription] VARCHAR(50),
    [FSBLOB] VARBINARY(MAX) FILESTREAM NULL,
    FOREIGN KEY (Idciclista) REFERENCES ciclista(Idciclista)
);

-- Inserir dados binários numa tabela FILESTREAM
INSERT into dbo.FileStreamTablevoltaPT VALUES ( 1, newid(), 'Ciclista_1',(select * from
OPENROWSET(BULK N'C:\ciclistas\ciclista_1.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTablevoltaPT VALUES ( 2, newid(), 'Ciclista_2',(select * from
OPENROWSET(BULK N'C:\ciclistas\ciclista_2.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTablevoltaPT VALUES ( 3, newid(), 'Ciclista_3',(select * from
OPENROWSET(BULK N'C:\ciclistas\ciclista_3.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTablevoltaPT VALUES ( 4, newid(), 'Ciclista_4',(select * from
OPENROWSET(BULK N'C:\ciclistas\ciclista_4.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTablevoltaPT VALUES ( 5, newid(), 'Ciclista_5',(select * from
OPENROWSET(BULK N'C:\ciclistas\ciclista_5.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTablevoltaPT VALUES ( 6, newid(), 'Ciclista_6',(select * from
OPENROWSET(BULK N'C:\ciclistas\ciclista_6.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTablevoltaPT VALUES ( 7, newid(), 'Ciclista_7',(select * from
OPENROWSET(BULK N'C:\ciclistas\ciclista_7.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTablevoltaPT VALUES ( 8, newid(), 'Ciclista_8',(select * from
OPENROWSET(BULK N'C:\ciclistas\ciclista_8.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTablevoltaPT VALUES (  9, newid(), 'Ciclista_9',(select * from
OPENROWSET(BULK N'C:\ciclistas\ciclista_9.jpg',SINGLE_BLOB) as FS))

INSERT into dbo.FileStreamTablevoltaPT VALUES ( 10, newid(), 'Ciclista_10',(select * from
OPENROWSET(BULK N'C:\ciclistas\ciclista_10.jpg',SINGLE_BLOB) as FS))


.-.-.-.-.-.-.-.-.-.-.-.
-- FEITOS NA TAREFA --
.-.-.-.-.-.-.-.-.-.-.-.

-- Fazer análise de uma consulta mais pesada com Execution Plan;
USE estatisticasVoltaPT;
GO

SELECT c.Idciclista,
       c.nome,
       e.IdEtapa,
       e.numEtapa,
       e.anoEtapa,
       t.IdTipo,
       t.tipo,
       AVG(est.valor) AS MediaEstatistica
FROM ciclista c
JOIN estatistica est ON c.Idciclista = est.Idciclista
JOIN etapa e ON est.IdEtapa = e.IdEtapa
JOIN tipoEst t ON est.IdTipo = t.IdTipo
GROUP BY c.Idciclista, c.nome, e.IdEtapa, e.numEtapa, e.anoEtapa, t.IdTipo, t.tipo
ORDER BY e.anoEtapa, c.Idciclista;

GO 40

-- Com o Database Engine Tuning Advisor analisar e aplicar recomendações;
-- Voltar a analisar para tirar conclusões;

DONE - PRINTS

-- Construir um Database Maintenance, demonstrável, que reorganize Dados
-- e Indices, valide a Integridade de dados, faça uma cópia de segurança da
-- Base de Dados mantendo um histórico de 1 mês e que ocorra todos os
-- dias às 01:00H. Notificar ainda o Administrador da Base de Dados 
-- do estado da execução (Com Sucesso ou Falha) através do envio de um email.

DONE - PRINTS

-- Com SSRS elaborar um relatório com gráfico e registos em tabela, será
-- valorizado a análise e a qualidade da informação apresentada

!! POR ACABAR !!

.-.-.-.-.-.-.-.
-- OPCIONAIS --
.-.-.-.-.-.-.-.

-- Procedimento que insira numa tabela baseado num formato JSON --

CREATE PROCEDURE InsertEtapaFromJSON
    @jsonData NVARCHAR(MAX)
AS
BEGIN
    INSERT INTO etapa (numEtapa, anoEtapa, loc_partida, loc_chegada)
    SELECT
        JSON_VALUE(@jsonData, '$.numEtapa'),
        JSON_VALUE(@jsonData, '$.anoEtapa'),
        JSON_VALUE(@jsonData, '$.loc_partida'),
        JSON_VALUE(@jsonData, '$.loc_chegada');
END;

DECLARE @jsonData NVARCHAR(MAX) = '
{
  "numEtapa": 0,
  "anoEtapa": 2024,
  "loc_partida": "TESTE A",
  "loc_chegada": "TESTE B"
}';

EXEC InsertEtapaFromJSON @jsonData;

SELECT * FROM etapa where numEtapa = 0;

-- Procedimento que retorna e transforme um conjunto de dados de uma tabela num formato JSON --

CREATE PROCEDURE GetCiclistaDataAsJSON
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @jsonOutput NVARCHAR(MAX);

    SELECT @jsonOutput = (
        SELECT *
        FROM ciclista
        FOR JSON AUTO
    );

    SELECT @jsonOutput AS JsonData;
END;

EXEC GetCiclistaDataAsJSON;

-- Procedimento/trigger que inclua notifica¸c˜ao por email (TSQL) --
-- Criar o trigger para enviar a notificação por email após a inserção em uma tabela
-- Criar o trigger
CREATE TRIGGER trg_NotificarInsercaoCiclista
ON ciclista
AFTER INSERT
AS
BEGIN
    -- Variáveis para armazenar informações do novo ciclista
    DECLARE @Nome VARCHAR(25);
    DECLARE @TotalKm DECIMAL(15, 1);
    DECLARE @TotalElevacao DECIMAL(15, 1);
    DECLARE @MaiorDistancia DECIMAL(10, 1);
    DECLARE @MaiorElevacao DECIMAL(10, 1);
    DECLARE @TotalVitorias INT;
    DECLARE @EmailAdmin VARCHAR(255);
    DECLARE @Assunto VARCHAR(100);
    DECLARE @Mensagem VARCHAR(MAX);

    -- Obter as informações do novo ciclista
    SELECT @Nome = nome,
           @TotalKm = total_km,
           @TotalElevacao = total_elevacao,
           @MaiorDistancia = maior_distancia,
           @MaiorElevacao = maior_elevacao,
           @TotalVitorias = total_vitorias
    FROM inserted;
    
    -- Configurar informações do email
    SET @EmailAdmin = 'alsantos@ipvc.pt'; -- endereço de email do administrador
    SET @Assunto = 'Nova inserção na tabela ciclista';
    SET @Mensagem = 'Foi inserido um novo ciclista na tabela ciclista:' + CHAR(13) + CHAR(10) +
                    'Nome: ' + @Nome + CHAR(13) + CHAR(10) +
                    'Total de KM: ' + CAST(@TotalKm AS VARCHAR(15)) + CHAR(13) + CHAR(10) +
                    'Total de Elevação: ' + CAST(@TotalElevacao AS VARCHAR(15)) + CHAR(13) + CHAR(10) +
                    'Maior Distância: ' + CAST(@MaiorDistancia AS VARCHAR(10)) + CHAR(13) + CHAR(10) +
                    'Maior Elevação: ' + CAST(@MaiorElevacao AS VARCHAR(10)) + CHAR(13) + CHAR(10) +
                    'Total de Vitórias: ' + CAST(@TotalVitorias AS VARCHAR(10));

    -- Enviar o email
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = 'SQL Server Agent Profile TP', -- nome do perfil de email configurado no SQL Server
        @recipients = @EmailAdmin,
        @subject = @Assunto,
        @body = @Mensagem;
END;

insert into ciclista values ('teste', 0, 0, 0, 0, 0);
