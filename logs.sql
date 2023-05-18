-- Criar Tabela de Logs --

CREATE TABLE LogInteracoes (
    numLog INT IDENTITY(1,1) PRIMARY KEY,
    Tabela VARCHAR(100),
    Operacao VARCHAR(20),
    DataHora DATETIME,
    Utilizador VARCHAR(50),
    idRegisto INT
);

-- Triggers de interação
-- ciclista
CREATE TRIGGER tr_ciclista ON ciclista
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @operacao VARCHAR(20)
    IF EXISTS (SELECT * FROM inserted) 
    BEGIN
        IF EXISTS (SELECT * FROM deleted) 
            SET @operacao = 'UPDATE'
        ELSE 
            SET @operacao = 'INSERT'
    END 
    ELSE 
        SET @operacao = 'DELETE'
    
    INSERT INTO LogInteracoes (Tabela, Operacao, DataHora, Utilizador, idRegisto)
    SELECT 'ciclista', @operacao, GETDATE(), SUSER_SNAME(), Idciclista FROM inserted UNION ALL
    SELECT 'ciclista', @operacao, GETDATE(), SUSER_SNAME(), Idciclista FROM deleted
END

-- tipoEst
CREATE TRIGGER tr_tipoEst ON tipoEst
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @operacao VARCHAR(20)
    IF EXISTS (SELECT * FROM inserted) 
    BEGIN
        IF EXISTS (SELECT * FROM deleted) 
            SET @operacao = 'UPDATE'
        ELSE 
            SET @operacao = 'INSERT'
    END 
    ELSE 
        SET @operacao = 'DELETE'
    
    INSERT INTO LogInteracoes (Tabela, Operacao, DataHora, Utilizador, idRegisto)
    SELECT 'tipoEst', @operacao, GETDATE(), SUSER_SNAME(), IdTipo FROM inserted UNION ALL
    SELECT 'tipoEst', @operacao, GETDATE(), SUSER_SNAME(), IdTipo FROM deleted
END

-- etapa
CREATE TRIGGER tr_etapa ON etapa
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @operacao VARCHAR(20)
    IF EXISTS (SELECT * FROM inserted) 
    BEGIN
        IF EXISTS (SELECT * FROM deleted) 
            SET @operacao = 'UPDATE'
        ELSE 
            SET @operacao = 'INSERT'
    END 
    ELSE 
        SET @operacao = 'DELETE'
    
    INSERT INTO LogInteracoes (Tabela, Operacao, DataHora, Utilizador, idRegisto)
    SELECT 'etapa', @operacao, GETDATE(), SUSER_SNAME(), IdEtapa FROM inserted UNION ALL
    SELECT 'etapa', @operacao, GETDATE(), SUSER_SNAME(), IdEtapa FROM deleted
END

-- estatistica
CREATE TRIGGER tr_estatistica ON estatistica
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @operacao VARCHAR(20)
    IF EXISTS (SELECT * FROM inserted) 
    BEGIN
        IF EXISTS (SELECT * FROM deleted) 
            SET @operacao = 'UPDATE'
        ELSE 
            SET @operacao = 'INSERT'
    END 
    ELSE 
        SET @operacao = 'DELETE'
    
    INSERT INTO LogInteracoes (Tabela, Operacao, DataHora, Utilizador, idRegisto)
    SELECT 'estatistica', @operacao, GETDATE(), SUSER_SNAME(), IdEstatistica FROM inserted UNION ALL
    SELECT 'estatistica', @operacao, GETDATE(), SUSER_SNAME(), IdEstatistica FROM deleted
END
