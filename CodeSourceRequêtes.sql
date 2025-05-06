/* 

les requetes 

 */
 -- 1. Requete qui affiche la liste des annulations avec les détails des frais (Le : clients n'ayant pas payé leur solde à la date convenue)
SELECT 
    a.idreservation AS reservationAnnulée,
    a.dateannulation,
    r.acompte + SUM(p.somme) - COALESCE(SUM(rr.montantReduction), 0) AS FraisEncaissés,
    c.nomClient
FROM annulation a
JOIN reservation r ON a.idreservation = r.idreservation
JOIN paiement p ON p.idreservation = r.idreservation
JOIN client c ON c.idclient = r.idclient
LEFT JOIN reservationReduction rr ON rr.idReservation = r.idreservation
WHERE a.typeannulation = 'retard paiement'
GROUP BY a.idreservation, a.dateannulation, r.acompte, c.nomClient;


-- 2. Requete qui affiche la liste des gens auxquels nous devrons envoyer une lettre d'avertissement 2 semaines avant la date à laquelle leur solde deviendra dû.
SELECT 
    r.idreservation,
    c.idclient,
    c.nomclient,
    ci.date_depart,
    ci.prix AS prixInitial,

    -- Prix après réduction
    ci.prix - COALESCE((
        SELECT SUM(rr2.montantReduction)
        FROM reservationReduction rr2
        WHERE rr2.idReservation = r.idreservation
    ), 0) AS prixApresReduction,

    -- Reste à payer après paiements, acompte et réductions
    ci.prix 
    - COALESCE((
        SELECT SUM(p2.somme)
        FROM paiement p2
        WHERE p2.idreservation = r.idreservation
    ), 0)
    - r.acompte
    - COALESCE((
        SELECT SUM(rr2.montantReduction)
        FROM reservationReduction rr2
        WHERE rr2.idReservation = r.idreservation
    ), 0) AS resteApayer

FROM reservation r
JOIN client c ON c.idclient = r.idclient
JOIN circuit ci ON ci.nocircuit = r.nocircuit

WHERE ci.date_depart - SYSDATE < 59 -- 14 jours plus 45 jours avant le départ ( date limite de paiement )

AND (
    ci.prix 
    - COALESCE((
        SELECT SUM(p2.somme)
        FROM paiement p2
        WHERE p2.idreservation = r.idreservation
    ), 0)
    - r.acompte
    - COALESCE((
        SELECT SUM(rr2.montantReduction)
        FROM reservationReduction rr2
        WHERE rr2.idReservation = r.idreservation
    ), 0)
) > 0

ORDER BY ci.date_depart;


-- 3. Requete qui affiche la liste des circuits avec les informations pertinentes sur chaque circuit .

SELECT c.nocircuit,
       c.date_depart,
       c.date_retour,
       c.prix,
       LISTAGG(d.nomdestination, ', ') WITHIN GROUP (ORDER BY d.nomdestination) AS destinations,
       f.type AS typeForfait
FROM circuit c 
JOIN destinationCircuit dc ON c.nocircuit = dc.nocircuit
JOIN destination d ON dc.iddestination = d.iddestination 
JOIN forfait f ON c.idforfait = f.idforfait
WHERE c.date_depart > SYSDATE
GROUP BY c.nocircuit, c.date_depart, c.date_retour, c.prix, f.type;


-- 4.	Requête qui affiche la liste des clients qui ont des frais de changement de circuit

SELECT 
        f.idfrais,
        rf.idreservation,
        r.idClient ,
        c.nomclient,
        r.nocircuit as circuitReservé
FROM 
    frais f 
JOIN reservationfrais rf ON rf.idfrais = f.idfrais
JOIN reservation r ON r.idreservation = rf.idreservation
JOIN client c ON c.idclient = r.idclient 
WHERE f.idfrais = 'F7' ;

-- 5. Requête qui affiche la liste des clients avec le circuit réservé et les destinations associées.
SELECT 
    c.idclient,
    c.nomclient,
    r.idreservation,
    r.nocircuit,
    LISTAGG(d.nomdestination, ', ') WITHIN GROUP (ORDER BY d.nomdestination) AS destinations
FROM client c 
JOIN reservation r ON r.idclient = c.idclient
JOIN circuit ci ON r.nocircuit = ci.nocircuit
JOIN destinationCircuit dc ON ci.nocircuit = dc.nocircuit
JOIN destination d ON dc.iddestination = d.iddestination
GROUP BY c.idclient, c.nomclient, r.idreservation, r.nocircuit;

-- 6. Requête qui affiche la liste des reservations annulées avec les détails des frais d'annulation.
SELECT
    r.idreservation,
    r.nocircuit,
    c.nomclient,
    a.dateannulation,
    ci.date_depart,

    -- Total payé (paiements + acompte)
    (SELECT COALESCE(SUM(somme), 0) 
     FROM paiement 
     WHERE idReservation = r.idreservation) + r.acompte AS totalPaye,

    f.type AS typeAnnulation,

    -- Frais d'annulation (calculés uniquement sur le total payé + acompte)
    CASE
        WHEN f.idfrais = 'F1' THEN r.acompte
        WHEN REGEXP_LIKE(f.pourcentagefrais, '^\d+%$') THEN 
            (
                (SELECT COALESCE(SUM(somme), 0) 
                 FROM paiement 
                 WHERE idReservation = r.idreservation) + r.acompte
            ) * TO_NUMBER(REGEXP_SUBSTR(f.pourcentagefrais, '\d+')) / 100
        ELSE 0
    END AS fraisAnnulation,

    -- Montant remboursé (total payé - frais)
    CASE
        WHEN f.idfrais = 'F1' THEN 
            (SELECT COALESCE(SUM(somme), 0) 
             FROM paiement 
             WHERE idReservation = r.idreservation)
        WHEN REGEXP_LIKE(f.pourcentagefrais, '^\d+%$') THEN 
            (
                (SELECT COALESCE(SUM(somme), 0) 
                 FROM paiement 
                 WHERE idReservation = r.idreservation) + r.acompte
            ) - (
                (
                    (SELECT COALESCE(SUM(somme), 0) 
                     FROM paiement 
                     WHERE idReservation = r.idreservation) + r.acompte
                ) * TO_NUMBER(REGEXP_SUBSTR(f.pourcentagefrais, '\d+')) / 100
            )
        ELSE 
            (SELECT COALESCE(SUM(somme), 0) 
             FROM paiement 
             WHERE idReservation = r.idreservation) + r.acompte
    END AS montantRembourse

FROM reservation r
JOIN annulation a ON a.idreservation = r.idreservation
JOIN client c ON c.idclient = r.idclient
JOIN circuit ci ON ci.nocircuit = r.nocircuit
JOIN reservationfrais rf ON rf.idreservation = r.idreservation
JOIN frais f ON f.idfrais = rf.idfrais

WHERE r.statut = 'Annulée'

GROUP BY r.idreservation, r.nocircuit, c.nomclient, a.dateannulation, ci.date_depart,
         f.idfrais, f.type, f.pourcentagefrais, r.acompte;

-- 7. Requête qui affiche la liste des clients avec le montant total payé et le solde restant à payer pour chaque réservation .
SELECT 
    r.idreservation,
    c.idclient,
    c.nomclient,

    -- Montant des réductions (sous-requête)
    (SELECT COALESCE(SUM(montantReduction), 0)
     FROM reservationReduction
     WHERE idReservation = r.idreservation) AS totalReduction,

    -- Total payé (paiements + acompte, sans retrait des réductions)
    (SELECT COALESCE(SUM(somme), 0)
     FROM paiement
     WHERE idReservation = r.idreservation) + r.acompte AS totalPaye,

    -- Solde restant = (prix - réductions) - total payé
    (ci.prix 
        - (SELECT COALESCE(SUM(montantReduction), 0)
           FROM reservationReduction
           WHERE idReservation = r.idreservation)
        - (
            (SELECT COALESCE(SUM(somme), 0)
             FROM paiement
             WHERE idReservation = r.idreservation) + r.acompte
        )
    ) AS soldeRestant

FROM client c 
JOIN reservation r ON r.idclient = c.idclient
JOIN circuit ci ON r.nocircuit = ci.nocircuit

WHERE r.statut = 'validé'

-- filtre les réservations où le solde est encore dû
AND (
    (ci.prix 
        - (SELECT COALESCE(SUM(montantReduction), 0)
           FROM reservationReduction
           WHERE idReservation = r.idreservation)
        - (
            (SELECT COALESCE(SUM(somme), 0)
             FROM paiement
             WHERE idReservation = r.idreservation) + r.acompte
        )
    ) > 0
)

ORDER BY totalPaye desc;

-- 8. Requête qui affiche la liste des clients avec le montant total payé et le solde restant à payer pour chaque réservation, y compris les réservations annulées.
SELECT 
    r.idreservation,
    r.statut,
    c.idclient,
    c.nomclient,
    SUM(p.somme) + r.acompte + COALESCE(SUM(rr.montantReduction), 0) AS totalPaye,
    ci.prix - (SUM(p.somme) + r.acompte + COALESCE(SUM(rr.montantReduction), 0)) AS soldeRestant
FROM client c
JOIN reservation r ON r.idclient = c.idclient
JOIN circuit ci ON r.nocircuit = ci.nocircuit
JOIN paiement p ON p.idreservation = r.idreservation
LEFT JOIN reservationReduction rr ON rr.idReservation = r.idreservation
WHERE r.statut IN ('validé', 'Annulée')
GROUP BY r.statut, r.idreservation, c.idclient, c.nomclient, r.acompte, ci.prix
HAVING ci.prix - (SUM(p.somme) + r.acompte + COALESCE(SUM(rr.montantReduction), 0)) > 0
ORDER BY c.nomclient;
-- 9. Requête qui affiche la liste des circuits avec le nombre de réservations et le montant total encaissé pour chaque circuit.
SELECT 
    c.nocircuit,
    COUNT(DISTINCT r.idreservation) AS nombreReservations,

    -- Paiements + acomptes sans duplication
    (
        (SELECT COALESCE(SUM(p2.somme), 0)
         FROM paiement p2
         JOIN reservation r2 ON p2.idreservation = r2.idreservation
         WHERE r2.nocircuit = c.nocircuit
           AND r2.statut = 'validé')
        +
        (SELECT COALESCE(SUM(r3.acompte), 0)
         FROM reservation r3
         WHERE r3.nocircuit = c.nocircuit
           AND r3.statut = 'validé')
    ) AS montantTotalEncaisse

FROM circuit c
JOIN reservation r ON r.nocircuit = c.nocircuit
WHERE r.statut = 'validé'

GROUP BY c.nocircuit
ORDER BY c.nocircuit;

-- 10. Requête qui affiche la liste des accompagnateurs avec les reservations associées.
SELECT 
    a.idaccompagnateur,
    a.nomaccompagnateur,
    r.idreservation,
    r.nocircuit,
    c.nomclient 
FROM accompagnateur a
JOIN reservation r ON r.idaccompagnateur = a.idaccompagnateur
JOIN client c ON c.idclient = r.idclient
WHERE r.statut = 'validé'
ORDER BY a.nomaccompagnateur, r.idreservation;

-- 11. Requête qui affiche la liste des reductions appliquées à chaque réservation.
SELECT 
    r.idreservation,
    c.nomclient,
    rr.idreduction,
    rr.nomreduction,
    red.montantreduction
FROM reservation r
JOIN client c ON c.idclient = r.idclient
JOIN reservationreduction rr ON rr.idreservation = r.idreservation
Join reduction red ON red.idreduction = rr.idreduction
WHERE r.statut = 'validé'
ORDER BY r.idreservation, rr.idreduction;
