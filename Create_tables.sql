-- Criacao da tabela Cliente
CREATE TABLE tipoEst (
    IdTipo int,
	tipo char(25),
	PRIMARY KEY (IdTipo)
);

-- Criacao da tabela Conta
CREATE TABLE etapa (
    IdEtapa int IDENTITY(1,1),
	numEtapa decimal(2),
    anoEtapa decimal(4),
    loc_partida char(25),
    loc_chegada char(25),
	PRIMARY KEY (IdEtapa),
);

-- Criacao da tabela titular conta
CREATE TABLE ciclista(
    Idcilista int,
    nome char(25),
    total_km decimal(15),
    total_elevacao decimal(15),
    maior_distancia decimal(10),
    maior_elevacao decimal(10),
    total_vitorias decimal(15),
	PRIMARY KEY (Idcilista)
);

-- Criacao da tabela movimentos
CREATE TABLE estatistica(
    IdEstatistica int ,
    Idcilista int ,
    IdEtapa int ,
    IdTipo int ,
    valor decimal(15) ,
	PRIMARY KEY (IdEstatistica),
    CONSTRAINT FK_Idcilista FOREIGN KEY (Idcilista) REFERENCES ciclista(Idcilista),
    CONSTRAINT FK_IdEtapa FOREIGN KEY (IdEtapa) REFERENCES etapa(IdEtapa),
    CONSTRAINT FK_IdTipo FOREIGN KEY (IdTipo) REFERENCES tipoEst(IdTipo)
);