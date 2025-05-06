/* 
    Les déclencheurs 
 */

-- Déclencheur pour générer le nom du membre et le prix d'adhèsion en fonction de l'âge du client
 CREATE OR REPLACE TRIGGER trg_set_nomembre
BEFORE INSERT ON membre
FOR EACH ROW
DECLARE
  v_age NUMBER;
BEGIN
  -- Récupérer l'âge depuis la table client
  SELECT age INTO v_age FROM client WHERE idClient = :NEW.idClient;

  -- Générer le nomembre et le type en fonction de l'âge
  IF v_age < 21 THEN
    :NEW.nomembre := 'ETU-' || :NEW.idClient;
    :NEW.type := 'Étudiant';
    :NEW.prix := 150; -- Prix d'adhésion pour étudiant
  ELSIF v_age BETWEEN 21 AND 60 THEN
    :NEW.nomembre := 'ADU-' || :NEW.idClient;
    :NEW.type := 'Adulte';
    :NEW.prix := 250; -- Prix d'adhésion pour adulte
  ELSE
    :NEW.nomembre := 'AOR-' || :NEW.idClient;
    :NEW.type := 'Âge d''or';
    :NEW.prix := 125; -- Prix d'adhésion pour personne agée
  END IF;
END;
/

-- Déclencheur pour générer le montant d'acompte avant chaque insertion dans la table réservation
CREATE OR REPLACE TRIGGER trg_set_acompte_reservation
BEFORE INSERT ON reservation
FOR EACH ROW
DECLARE
    v_prix_circuit circuit.prix%TYPE;
    v_acompte_calcule NUMBER;
BEGIN
    -- Récupérer le prix du circuit associé
    SELECT prix
    INTO v_prix_circuit
    FROM circuit
    WHERE noCircuit = :NEW.noCircuit;

    -- Calculer l'acompte comme le plus élevé entre 500$ et 10% du prix du circuit
    v_acompte_calcule := GREATEST(500, v_prix_circuit * 0.10);

    -- Assigner la valeur calculée à la colonne acompte
    :NEW.acompte := v_acompte_calcule;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Si aucun circuit n’est trouvé, mettre l’acompte à 500$ par défaut
        :NEW.acompte := 500;
END;
/

-- 1. Déclencheur pour la réduction "Réservez tôt"
CREATE OR REPLACE TRIGGER trg_apply_reduction_reztot
AFTER INSERT ON reservation
FOR EACH ROW
DECLARE
    v_date_depart circuit.date_depart%TYPE;
    v_jours_avant_depart NUMBER;
BEGIN
    -- Récupérer la date de départ du circuit
    SELECT date_depart INTO v_date_depart
    FROM circuit
    WHERE noCircuit = :NEW.noCircuit;

    -- Calculer le nombre de jours avant le départ
    v_jours_avant_depart := v_date_depart - :NEW.dateReservation;

    -- Appliquer la réduction si plus de 90 jours
    IF v_jours_avant_depart > 90 THEN
        INSERT INTO reservationReduction (idReservation, idReduction, montantReduction)
        VALUES (:NEW.idReservation, 'REZTOT', 100);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erreur trg_apply_reduction_reztot: ' || SQLERRM);
END;
/


-- 2. Déclencheur pour la réduction "Client Fidèle"
CREATE OR REPLACE TRIGGER trg_apply_reduction_fidelite
AFTER INSERT ON reservation
FOR EACH ROW
DECLARE
    v_nb_voyages_passes NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_nb_voyages_passes
    FROM reservation r
    JOIN circuit c ON r.noCircuit = c.noCircuit
    WHERE r.idClient = :NEW.idClient
      AND r.idReservation != :NEW.idReservation
      AND c.date_depart >= ADD_MONTHS(SYSDATE, -60) -- 5 dernières années
      AND r.statut = 'validé';

    IF v_nb_voyages_passes > 0 THEN
        INSERT INTO reservationReduction (idReservation, idReduction, montantReduction)
        VALUES (:NEW.idReservation, 'FIDELITE', 50);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erreur trg_apply_reduction_fidelite: ' || SQLERRM);
END;
/


-- 3. Déclencheur pour la réduction "Club Select"
CREATE OR REPLACE TRIGGER trg_apply_reduction_clubselect
AFTER INSERT ON reservation
FOR EACH ROW
DECLARE
    v_est_membre NUMBER := 0;
    v_prix_circuit NUMBER := 0;
    v_montant_reduction NUMBER := 0;
BEGIN
    -- Vérifier si le client est membre
    SELECT COUNT(*) INTO v_est_membre
    FROM membre
    WHERE idClient = :NEW.idClient;

    IF v_est_membre > 0 THEN
        -- Récupérer le prix du circuit
        SELECT prix INTO v_prix_circuit
        FROM circuit
        WHERE noCircuit = :NEW.noCircuit;

        -- Calcul de la réduction de 5%
        v_montant_reduction := v_prix_circuit * 0.05;

        -- Insertion de la réduction dans la table
        INSERT INTO reservationReduction (idReservation, idReduction, montantReduction)
        VALUES (:NEW.idReservation, 'CLUBSELECT', v_montant_reduction);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erreur trg_apply_reduction_clubselect: ' || SQLERRM);
END;
/

-- 3. Déclencheur pour la réduction "Mode de paiement"
CREATE OR REPLACE TRIGGER trg_reduction_paiement_comptant
AFTER INSERT ON paiement
FOR EACH ROW
WHEN (NEW.typePaiement IN ('Espèce', 'Chèque'))
DECLARE
    v_prix_circuit NUMBER := 0;
    v_montant_reduction NUMBER := 0;
BEGIN
    -- Récupérer le prix du circuit associé à la réservation
    SELECT c.prix INTO v_prix_circuit
    FROM reservation r
    JOIN circuit c ON r.noCircuit = c.noCircuit
    WHERE r.idReservation = :NEW.idReservation;

    -- Calcul de la réduction de 2%
    v_montant_reduction := v_prix_circuit * 0.02;

    -- MERGE évite les doublons
    MERGE INTO reservationReduction rr
    USING (
        SELECT :NEW.idReservation AS idRes, 'CHEQUE' AS idRed, v_montant_reduction AS montantRed FROM dual
    ) src
    ON (rr.idReservation = src.idRes AND rr.idReduction = src.idRed)
    WHEN NOT MATCHED THEN
        INSERT (idReservation, idReduction, montantReduction)
        VALUES (src.idRes, src.idRed, src.montantRed);
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- Ignorer les erreurs silencieusement
END;
/


-- Déclencheur pour insérer les frais de changement de circuit dans reservationFrais

CREATE OR REPLACE TRIGGER trg_apply_frais_changement_circuit
AFTER UPDATE OF noCircuit ON reservation
FOR EACH ROW
WHEN (OLD.noCircuit IS NOT NULL AND NEW.noCircuit IS NOT NULL AND OLD.noCircuit != NEW.noCircuit)
DECLARE
    v_frais_changement NUMBER := 100;
BEGIN
    
    -- Insérer les frais de changement dans reservationFrais
    INSERT INTO reservationFrais (idReservation, idFrais)
    VALUES (:NEW.idReservation, 'F7');
    

END;
/

--  Déclencheur permet d'insérer une ligne dans la table reservationFrais après chaque annulation de réservation
CREATE OR REPLACE TRIGGER trg_insert_reservation_frais_annulation
AFTER INSERT ON annulation
FOR EACH ROW
DECLARE
    v_date_depart circuit.DATE_DEPART%TYPE;
    v_jours_avant_depart NUMBER;
    v_id_frais frais.idFrais%TYPE;
BEGIN
    IF :NEW.typeAnnulation != 'decision Agence' THEN
        -- Récupérer la date de départ du circuit associé à la réservation
        SELECT c.date_Depart
        INTO v_date_depart
        FROM circuit c
        JOIN reservation r ON r.noCircuit = c.noCircuit
        WHERE r.idReservation = :NEW.idReservation;

        -- Calculer le nombre de jours entre l'annulation et le départ
        v_jours_avant_depart := v_date_depart - :NEW.dateAnnulation;

        -- Déterminer le type de frais d'annulation en fonction du délai
        IF v_jours_avant_depart >= 45 THEN
            v_id_frais := 'F1'; -- Acompte
        ELSIF v_jours_avant_depart BETWEEN 31 AND 44 THEN
            v_id_frais := 'F2'; -- 40%
        ELSIF v_jours_avant_depart BETWEEN 21 AND 30 THEN
            v_id_frais := 'F3'; -- 60%
        ELSIF v_jours_avant_depart BETWEEN 1 AND 20 THEN
            v_id_frais := 'F4'; -- 100%
        ELSE
            v_id_frais := 'F5'; -- 100%
        END IF;

        -- Insérer les frais d'annulation dans reservationFrais
        INSERT INTO reservationFrais (idReservation, idFrais)
        VALUES (:NEW.idReservation, v_id_frais);

        -- Mettre à jour le statut de la réservation à 'Annulée'
        UPDATE reservation
        SET statut = 'Annulée'
        WHERE idReservation = :NEW.idReservation;

    ELSE
        -- Cas spécifique : annulation sur décision de l'agence
        INSERT INTO reservationFrais (idReservation, idFrais)
        VALUES (:NEW.idReservation, 'F8');
        
        -- Mettre à jour le statut de la réservation à 'Annulée'
        UPDATE reservation
        SET statut = 'Annulée'
        WHERE idReservation = :NEW.idReservation;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Erreur: Données non trouvées pour la réservation ' || :NEW.idReservation);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erreur dans trg_insert_reservation_frais_annulation: ' || SQLERRM);
END;
/