create DATABASE estatisticasVoltaPT;

-- Criacao da tabela Cliente
CREATE TABLE tipoEst (
    IdTipo int PRIMARY KEY IDENTITY(1,1),
	tipo varchar(25)
);

-- Criacao da tabela Conta
CREATE TABLE etapa (
    IdEtapa int PRIMARY KEY IDENTITY(1,1),
	numEtapa int,
    anoEtapa decimal(4),
    loc_partida varchar(25),
    loc_chegada varchar(25)
);

-- Criacao da tabela titular conta
CREATE TABLE ciclista(
    Idcilista int PRIMARY KEY IDENTITY(1,1),
    nome varchar(25),
    total_km decimal(15,1),
    total_elevacao decimal(15,1),
    maior_distancia decimal(10,1),
    maior_elevacao decimal(10,1),
    total_vitorias int
);

-- Criacao da tabela movimentos
CREATE TABLE estatistica(
    IdEstatistica int PRIMARY KEY IDENTITY(1,1),
    Idcilista int ,
    IdEtapa int ,
    IdTipo int ,
    valor decimal(15,1),
    CONSTRAINT FK_Idcilista FOREIGN KEY (Idcilista) REFERENCES ciclista(Idcilista),
    CONSTRAINT FK_IdEtapa FOREIGN KEY (IdEtapa) REFERENCES etapa(IdEtapa),
    CONSTRAINT FK_IdTipo FOREIGN KEY (IdTipo) REFERENCES tipoEst(IdTipo)
);