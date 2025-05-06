-- 1. Tables de base

CREATE TABLE client (
    idClient VARCHAR2(20) PRIMARY KEY,
    nomClient VARCHAR2(100),
    emailClient VARCHAR2(100),
    telephoneClient VARCHAR2(20),
    age NUMBER DEFAULT 0 NOT NULL
);

CREATE TABLE agence (
    nomAgence VARCHAR2(100) PRIMARY KEY,
    adresseAgence VARCHAR2(250),
    emailAgence VARCHAR2(100),
    telephone VARCHAR2(20),
    fax VARCHAR2(20)
);

CREATE TABLE accompagnateur (
    idAccompagnateur VARCHAR2(20) PRIMARY KEY,
    nomAccom VARCHAR2(100),
    telephoneAccom VARCHAR2(20),
    nomAgence VARCHAR2(100),
    FOREIGN KEY (nomAgence) REFERENCES agence(nomAgence)
);

CREATE TABLE membre (
    noMembre VARCHAR2(20) PRIMARY KEY,
    type VARCHAR2(50),
    prix NUMBER DEFAULT 0 NOT NULL,
    idClient VARCHAR2(20),
    FOREIGN KEY (idClient) REFERENCES client(idClient)
);
ALTER TABLE membre
ADD CONSTRAINT uq_membre_idclient UNIQUE (idClient);

CREATE TABLE agent (
    noAgent VARCHAR2(20) PRIMARY KEY,
    nomAgent VARCHAR2(100)
);

-- 2. Destination et circuit

CREATE TABLE destination (
    idDestination NUMBER PRIMARY KEY,
    nomDestination VARCHAR2(100)
);

CREATE TABLE forfait (
    idForfait NUMBER PRIMARY KEY,
    type VARCHAR2(50)
);

CREATE TABLE circuit (
    noCircuit VARCHAR2(20) PRIMARY KEY,
    date_depart DATE,
    date_retour DATE,
    prix NUMBER,
    idForfait NUMBER,
    FOREIGN KEY (idForfait) REFERENCES forfait(idForfait)
);

CREATE TABLE destinationCircuit (
    idDestination NUMBER,
    noCircuit VARCHAR2(20),
    PRIMARY KEY (idDestination, noCircuit),
    FOREIGN KEY (idDestination) REFERENCES destination(idDestination),
    FOREIGN KEY (noCircuit) REFERENCES circuit(noCircuit)
);

-- 3. Réductions, frais

CREATE TABLE reduction (
    idReduction VARCHAR2(20) PRIMARY KEY,
    montantReduction VARCHAR2(20)
);

CREATE TABLE frais (
    idFrais VARCHAR2(10) PRIMARY KEY,
    type VARCHAR2(50),
    pourcentageFrais VARCHAR2(20)
);


-- 4. Réservation, annulation

CREATE TABLE reservation (
    idReservation VARCHAR2(20) PRIMARY KEY,
    dateReservation DATE,
    statut VARCHAR2(50),
    idClient VARCHAR2(20),
    idAccompagnateur VARCHAR2(20),
    noAgent VARCHAR2(20),
    noCircuit VARCHAR2(20),
    acompte NUMBER DEFAULT 0 NOT NULL,
    FOREIGN KEY (idClient) REFERENCES client(idClient),
    FOREIGN KEY (idAccompagnateur) REFERENCES accompagnateur(idAccompagnateur),
    FOREIGN KEY (noAgent) REFERENCES agent(noAgent),
    FOREIGN KEY (noCircuit) REFERENCES circuit(noCircuit)
);

CREATE TABLE annulation (
    idAnnulation VARCHAR2(20) PRIMARY KEY,
    typeAnnulation VARCHAR2(50),
    dateAnnulation DATE,
    idReservation VARCHAR2(20),
    FOREIGN KEY (idReservation) REFERENCES reservation(idReservation)
);

CREATE TABLE paiement (
    refPaiement NUMBER PRIMARY KEY,
    typePaiement VARCHAR2(50),
    idReservation VARCHAR2(20),
    somme NUMBER,
    datePaiement DATE,
    FOREIGN KEY (idReservation) REFERENCES reservation(idReservation)
);

CREATE TABLE reservationReduction (
    idReservation VARCHAR2(20),
    idReduction VARCHAR2(20),
    montantReduction NUMBER DEFAULT 0 NOT NULL,
    PRIMARY KEY (idReservation, idReduction),
    FOREIGN KEY (idReservation) REFERENCES reservation(idReservation),
    FOREIGN KEY (idReduction) REFERENCES reduction(idReduction)
);

CREATE TABLE reservationFrais (
    idReservation VARCHAR2(20),
    idFrais VARCHAR2(20),
    PRIMARY KEY (idReservation, idFrais),
    FOREIGN KEY (idReservation) REFERENCES reservation(idReservation),
    FOREIGN KEY (idFrais) REFERENCES frais(idFrais)
);




/* //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
*/




/* //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
*/

