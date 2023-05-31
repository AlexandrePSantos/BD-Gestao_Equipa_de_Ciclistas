create DATABASE estatisticasVoltaPT;

-- Criacao da tabela tipoEst
CREATE TABLE tipoEst (
    IdTipo int PRIMARY KEY IDENTITY(1,1),
	tipo varchar(25)
);

-- Criacao da tabela etapa
CREATE TABLE etapa (
    IdEtapa int PRIMARY KEY IDENTITY(1,1),
	numEtapa int,
    anoEtapa decimal(4),
    loc_partida varchar(25),
    loc_chegada varchar(25)
);

-- Criacao da tabela ciclista
CREATE TABLE ciclista(
    Idciclista int PRIMARY KEY IDENTITY(1,1),
    nome varchar(25),
    total_km decimal(15,1),
    total_elevacao decimal(15,1),
    maior_distancia decimal(10,1),
    maior_elevacao decimal(10,1),
    total_vitorias int
);

-- Criacao da tabela estatistica
CREATE TABLE estatistica(
    IdEstatistica int PRIMARY KEY IDENTITY(1,1),
    Idciclista int ,
    IdEtapa int ,
    IdTipo int ,
    valor decimal(15,1),
    CONSTRAINT FK_Idciclista FOREIGN KEY (Idciclista) REFERENCES ciclista(Idciclista),
    CONSTRAINT FK_IdEtapa FOREIGN KEY (IdEtapa) REFERENCES etapa(IdEtapa),
    CONSTRAINT FK_IdTipo FOREIGN KEY (IdTipo) REFERENCES tipoEst(IdTipo)
);

-- Restrições de integridade
-- estatistica
ALTER table estatistica
ADD valor decimal(15,1) CHECK (valor > 0);

ALTER table estatistica
ADD IdTipo INT CHECK (valor > 0);

ALTER table estatistica
ADD IdTipo INT CHECK (valor < 17);