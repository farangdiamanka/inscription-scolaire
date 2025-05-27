-- Script de création de la base de données pour le système d'inscription scolaire
-- Version: 1.0
-- Date: 2024

-- Créer la base de données
CREATE DATABASE IF NOT EXISTS inscription_scolaire
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE inscription_scolaire;

-- Table des utilisateurs du système
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin', 'secretaire', 'comptable', 'directeur') DEFAULT 'secretaire',
    nom_complet VARCHAR(200),
    email VARCHAR(100),
    telephone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des élèves
CREATE TABLE IF NOT EXISTS eleves (
    id INT AUTO_INCREMENT PRIMARY KEY,
    matricule VARCHAR(20) UNIQUE NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    nom VARCHAR(100) NOT NULL,
    date_naissance DATE,
    lieu_naissance VARCHAR(100),
    sexe ENUM('M', 'F') NOT NULL,
    nationalite VARCHAR(50) DEFAULT 'Sénégalaise',
    niveau VARCHAR(20) NOT NULL,
    ecole_precedente VARCHAR(200),
    -- Informations médicales
    groupe_sanguin VARCHAR(5),
    conditions_medicales TEXT,
    medicaments TEXT,
    medecin_nom VARCHAR(200),
    medecin_telephone VARCHAR(20),
    -- Métadonnées
    statut ENUM('actif', 'inactif', 'diplome', 'transfere') DEFAULT 'actif',
    date_inscription DATE DEFAULT CURRENT_DATE,
    photo_path VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by INT,
    -- Index pour améliorer les performances
    INDEX idx_matricule (matricule),
    INDEX idx_nom (nom, prenom),
    INDEX idx_niveau (niveau),
    INDEX idx_statut (statut),
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des parents/tuteurs
CREATE TABLE IF NOT EXISTS parents (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom_complet VARCHAR(200) NOT NULL,
    telephone VARCHAR(20) NOT NULL,
    telephone2 VARCHAR(20),
    email VARCHAR(100),
    profession VARCHAR(100),
    lieu_travail VARCHAR(200),
    adresse_domicile TEXT,
    adresse_travail TEXT,
    relation ENUM('pere', 'mere', 'tuteur', 'autre') DEFAULT 'pere',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_nom (nom_complet),
    INDEX idx_telephone (telephone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table de liaison élèves-parents (plusieurs parents par élève possible)
CREATE TABLE IF NOT EXISTS eleves_parents (
    id INT AUTO_INCREMENT PRIMARY KEY,
    eleve_id INT NOT NULL,
    parent_id INT NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    is_payeur BOOLEAN DEFAULT FALSE,
    autorisation_sortie BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_eleve_parent (eleve_id, parent_id),
    FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES parents(id) ON DELETE CASCADE,
    INDEX idx_eleve (eleve_id),
    INDEX idx_parent (parent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des contacts d'urgence
CREATE TABLE IF NOT EXISTS contacts_urgence (
    id INT AUTO_INCREMENT PRIMARY KEY,
    eleve_id INT NOT NULL,
    nom VARCHAR(200) NOT NULL,
    telephone VARCHAR(20) NOT NULL,
    telephone2 VARCHAR(20),
    relation VARCHAR(50),
    priorite INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE,
    INDEX idx_eleve (eleve_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des services disponibles
CREATE TABLE IF NOT EXISTS services (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(20) UNIQUE NOT NULL,
    nom VARCHAR(100) NOT NULL,
    description TEXT,
    tarif_mensuel DECIMAL(10, 2),
    tarif_annuel DECIMAL(10, 2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insérer les services par défaut
INSERT INTO services (code, nom, tarif_mensuel) VALUES
('transport', 'Transport Scolaire', 10000),
('cantine', 'Cantine', 15000),
('taekwondo', 'Taekwondo', 5000),
('fournitures', 'Pack Fournitures', 0);

-- Table des inscriptions aux services
CREATE TABLE IF NOT EXISTS services_eleves (
    id INT AUTO_INCREMENT PRIMARY KEY,
    eleve_id INT NOT NULL,
    service_id INT NOT NULL,
    date_debut DATE DEFAULT CURRENT_DATE,
    date_fin DATE,
    statut ENUM('actif', 'suspendu', 'termine') DEFAULT 'actif',
    -- Détails spécifiques au service (JSON)
    details JSON,
    tarif_special DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_eleve (eleve_id),
    INDEX idx_service (service_id),
    INDEX idx_statut (statut)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des tarifs par niveau
CREATE TABLE IF NOT EXISTS tarifs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    niveau VARCHAR(20) UNIQUE NOT NULL,
    annee_scolaire VARCHAR(9) DEFAULT '2024-2025',
    frais_inscription DECIMAL(10, 2) NOT NULL,
    frais_reinscription DECIMAL(10, 2) NOT NULL,
    mensualite DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_niveau (niveau),
    INDEX idx_annee (annee_scolaire)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insérer les tarifs par défaut
INSERT INTO tarifs (niveau, frais_inscription, frais_reinscription, mensualite) VALUES
('PPS', 30000, 20000, 120000),
('PS', 30000, 20000, 120000),
('MS', 30000, 20000, 120000),
('GS', 30000, 20000, 120000),
('CI', 30000, 20000, 130000),
('CP', 30000, 20000, 130000),
('CE1', 30000, 20000, 130000),
('CE2', 30000, 20000, 130000),
('CM1', 30000, 20000, 130000),
('CM2', 30000, 20000, 130000),
('6eme', 30000, 20000, 140000),
('5eme', 30000, 20000, 140000),
('4eme', 30000, 20000, 140000),
('3eme', 30000, 20000, 140000),
('2nd', 30000, 20000, 150000),
('Hifz', 30000, 20000, 100000);

-- Table des paiements
CREATE TABLE IF NOT EXISTS paiements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    eleve_id INT NOT NULL,
    type_paiement ENUM('inscription', 'reinscription', 'mensualite', 'service', 'autre') NOT NULL,
    montant DECIMAL(10, 2) NOT NULL,
    montant_recu DECIMAL(10, 2) NOT NULL,
    montant_rendu DECIMAL(10, 2) DEFAULT 0,
    mode_paiement ENUM('especes', 'cheque', 'virement', 'mobile_money', 'carte') NOT NULL,
    reference VARCHAR(100),
    banque VARCHAR(100),
    numero_recu VARCHAR(50),
    mois_concerne VARCHAR(7), -- Format: YYYY-MM
    annee_scolaire VARCHAR(9) DEFAULT '2024-2025',
    statut ENUM('en_attente', 'complete', 'partiel', 'annule', 'rembourse') DEFAULT 'complete',
    date_paiement DATETIME DEFAULT CURRENT_TIMESTAMP,
    remarques TEXT,
    created_by INT NOT NULL,
    updated_by INT,
    FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id),
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_eleve (eleve_id),
    INDEX idx_type (type_paiement),
    INDEX idx_date (date_paiement),
    INDEX idx_statut (statut),
    INDEX idx_mois (mois_concerne),
    INDEX idx_recu (numero_recu)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des documents
CREATE TABLE IF NOT EXISTS documents (
    id INT AUTO_INCREMENT PRIMARY KEY,
    eleve_id INT NOT NULL,
    type_document ENUM('extrait_naissance', 'photo', 'carnet_vaccination', 'certificat_scolarite', 'bulletin', 'autre') NOT NULL,
    nom_fichier VARCHAR(255) NOT NULL,
    chemin_fichier VARCHAR(500) NOT NULL,
    taille_fichier INT,
    mime_type VARCHAR(100),
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uploaded_by INT,
    FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE,
    FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_eleve (eleve_id),
    INDEX idx_type (type_document)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des réinscriptions
CREATE TABLE IF NOT EXISTS reinscriptions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    eleve_id INT NOT NULL,
    ancien_niveau VARCHAR(20) NOT NULL,
    nouveau_niveau VARCHAR(20) NOT NULL,
    annee_scolaire VARCHAR(9) NOT NULL,
    date_reinscription DATE DEFAULT CURRENT_DATE,
    statut ENUM('en_cours', 'validee', 'annulee') DEFAULT 'validee',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INT,
    FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_eleve (eleve_id),
    INDEX idx_annee (annee_scolaire)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des classes (pour organiser les élèves)
CREATE TABLE IF NOT EXISTS classes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(50) NOT NULL,
    niveau VARCHAR(20) NOT NULL,
    annee_scolaire VARCHAR(9) NOT NULL,
    effectif_max INT DEFAULT 30,
    salle VARCHAR(50),
    professeur_principal VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_classe (nom, annee_scolaire),
    INDEX idx_niveau (niveau),
    INDEX idx_annee (annee_scolaire)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table d'affectation des élèves aux classes
CREATE TABLE IF NOT EXISTS eleves_classes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    eleve_id INT NOT NULL,
    classe_id INT NOT NULL,
    date_affectation DATE DEFAULT CURRENT_DATE,
    date_fin DATE,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE,
    FOREIGN KEY (classe_id) REFERENCES classes(id) ON DELETE CASCADE,
    UNIQUE KEY unique_eleve_classe_active (eleve_id, is_active),
    INDEX idx_eleve (eleve_id),
    INDEX idx_classe (classe_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table de logs pour l'audit
CREATE TABLE IF NOT EXISTS logs_activites (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(50),
    record_id INT,
    old_values JSON,
    new_values JSON,
    ip_address VARCHAR(45),
    user_agent VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user (user_id),
    INDEX idx_action (action),
    INDEX idx_date (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Vues utiles

-- Vue des élèves avec leurs parents principaux
CREATE OR REPLACE VIEW vue_eleves_parents AS
SELECT 
    e.id,
    e.matricule,
    e.prenom,
    e.nom,
    e.niveau,
    e.statut,
    p.nom_complet as parent_nom,
    p.telephone as parent_telephone,
    p.email as parent_email
FROM eleves e
LEFT JOIN eleves_parents ep ON e.id = ep.eleve_id AND ep.is_primary = 1
LEFT JOIN parents p ON ep.parent_id = p.id;

-- Vue des paiements mensuels
CREATE OR REPLACE VIEW vue_paiements_mensuels AS
SELECT 
    p.id,
    e.matricule,
    CONCAT(e.prenom, ' ', e.nom) as eleve_nom,
    e.niveau,
    p.mois_concerne,
    p.montant,
    p.statut,
    p.date_paiement,
    u.nom_complet as recu_par
FROM paiements p
JOIN eleves e ON p.eleve_id = e.id
JOIN users u ON p.created_by = u.id
WHERE p.type_paiement = 'mensualite'
ORDER BY p.date_paiement DESC;

-- Procédures stockées

DELIMITER //

-- Procédure pour générer le prochain matricule
CREATE PROCEDURE generer_matricule(OUT nouveau_matricule VARCHAR(20))
BEGIN
    DECLARE max_matricule INT;
    
    SELECT MAX(CAST(matricule AS UNSIGNED)) INTO max_matricule
    FROM eleves
    WHERE matricule REGEXP '^[0-9]+$';
    
    IF max_matricule IS NULL THEN
        SET max_matricule = 240000;
    END IF;
    
    SET nouveau_matricule = CAST(max_matricule + 1 AS CHAR);
END//

-- Procédure pour calculer les arriérés d'un élève
CREATE PROCEDURE calculer_arrieres(IN p_eleve_id INT, OUT total_arrieres DECIMAL(10,2))
BEGIN
    DECLARE mois_scolarite INT DEFAULT 9; -- Septembre à Mai
    DECLARE mensualite DECIMAL(10,2);
    DECLARE total_paye DECIMAL(10,2);
    DECLARE niveau_eleve VARCHAR(20);
    
    -- Obtenir le niveau de l'élève
    SELECT niveau INTO niveau_eleve FROM eleves WHERE id = p_eleve_id;
    
    -- Obtenir la mensualité pour ce niveau
    SELECT t.mensualite INTO mensualite 
    FROM tarifs t 
    WHERE t.niveau = niveau_eleve 
    LIMIT 1;
    
    -- Calculer le total payé
    SELECT COALESCE(SUM(montant), 0) INTO total_paye
    FROM paiements
    WHERE eleve_id = p_eleve_id 
    AND type_paiement = 'mensualite'
    AND statut IN ('complete', 'partiel')
    AND annee_scolaire = '2024-2025';
    
    -- Calculer les arriérés
    SET total_arrieres = (mensualite * mois_scolarite) - total_paye;
    
    IF total_arrieres < 0 THEN
        SET total_arrieres = 0;
    END IF;
END//

-- Procédure pour statistiques du tableau de bord
CREATE PROCEDURE statistiques_dashboard()
BEGIN
    -- Total élèves actifs
    SELECT COUNT(*) as total_eleves FROM eleves WHERE statut = 'actif';
    
    -- Répartition par sexe
    SELECT sexe, COUNT(*) as nombre 
    FROM eleves 
    WHERE statut = 'actif' 
    GROUP BY sexe;
    
    -- Répartition par niveau
    SELECT niveau, COUNT(*) as nombre 
    FROM eleves 
    WHERE statut = 'actif' 
    GROUP BY niveau 
    ORDER BY FIELD(niveau, 'PPS', 'PS', 'MS', 'GS', 'CI', 'CP', 'CE1', 'CE2', 'CM1', 'CM2', '6eme', '5eme', '4eme', '3eme', '2nd', 'Hifz');
    
    -- Nouvelles inscriptions (30 derniers jours)
    SELECT COUNT(*) as nouvelles_inscriptions 
    FROM eleves 
    WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);
    
    -- Services souscrits
    SELECT s.nom, COUNT(se.id) as nombre
    FROM services s
    LEFT JOIN services_eleves se ON s.id = se.service_id AND se.statut = 'actif'
    GROUP BY s.id, s.nom;
    
    -- Paiements du jour
    SELECT 
        COUNT(*) as nombre_paiements,
        SUM(montant) as total_montant
    FROM paiements
    WHERE DATE(date_paiement) = CURDATE()
    AND statut = 'complete';
END//

DELIMITER ;

-- Triggers pour l'audit

DELIMITER //

-- Trigger pour enregistrer les modifications sur les élèves
CREATE TRIGGER log_eleves_update
AFTER UPDATE ON eleves
FOR EACH ROW
BEGIN
    INSERT INTO logs_activites (
        user_id, 
        action, 
        table_name, 
        record_id, 
        old_values, 
        new_values
    ) VALUES (
        NEW.updated_by,
        'UPDATE',
        'eleves',
        NEW.id,
        JSON_OBJECT(
            'nom', OLD.nom,
            'prenom', OLD.prenom,
            'niveau', OLD.niveau,
            'statut', OLD.statut
        ),
        JSON_OBJECT(
            'nom', NEW.nom,
            'prenom', NEW.prenom,
            'niveau', NEW.niveau,
            'statut', NEW.statut
        )
    );
END//

-- Trigger pour générer automatiquement le numéro de reçu
CREATE TRIGGER generer_numero_recu
BEFORE INSERT ON paiements
FOR EACH ROW
BEGIN
    DECLARE dernier_numero INT;
    DECLARE nouveau_numero VARCHAR(50);
    
    -- Obtenir le dernier numéro
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero_recu, 5) AS UNSIGNED)), 0) INTO dernier_numero
    FROM paiements
    WHERE YEAR(date_paiement) = YEAR(NEW.date_paiement);
    
    -- Générer le nouveau numéro: ANNÉE-NUMÉRO (ex: 2024-00001)
    SET nouveau_numero = CONCAT(YEAR(NEW.date_paiement), '-', LPAD(dernier_numero + 1, 5, '0'));
    
    SET NEW.numero_recu = nouveau_numero;
END//

DELIMITER ;

-- Index supplémentaires pour optimiser les performances
CREATE INDEX idx_paiements_eleve_date ON paiements(eleve_id, date_paiement);
CREATE INDEX idx_paiements_type_statut ON paiements(type_paiement, statut);
CREATE INDEX idx_services_eleves_active ON services_eleves(eleve_id, statut, service_id);

-- Utilisateurs par défaut
INSERT INTO users (username, password, role, nom_complet) VALUES
('admin', '$2b$10$YourHashedPasswordHere', 'admin', 'Administrateur'),
('secretaire1', '$2b$10$YourHashedPasswordHere', 'secretaire', 'Secrétaire Principal'),
('comptable1', '$2b$10$YourHashedPasswordHere', 'comptable', 'Comptable Principal');

-- Permissions (optionnel - pour une gestion plus fine des droits)
CREATE TABLE IF NOT EXISTS permissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role ENUM('admin', 'secretaire', 'comptable', 'directeur') NOT NULL,
    resource VARCHAR(50) NOT NULL,
    can_create BOOLEAN DEFAULT FALSE,
    can_read BOOLEAN DEFAULT TRUE,
    can_update BOOLEAN DEFAULT FALSE,
    can_delete BOOLEAN DEFAULT FALSE,
    UNIQUE KEY unique_role_resource (role, resource)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Définir les permissions par rôle
INSERT INTO permissions (role, resource, can_create, can_read, can_update, can_delete) VALUES
-- Admin a tous les droits
('admin', 'eleves', TRUE, TRUE, TRUE, TRUE),
('admin', 'paiements', TRUE, TRUE, TRUE, TRUE),
('admin', 'users', TRUE, TRUE, TRUE, TRUE),
('admin', 'services', TRUE, TRUE, TRUE, TRUE),
-- Secrétaire peut gérer les élèves mais pas supprimer
('secretaire', 'eleves', TRUE, TRUE, TRUE, FALSE),
('secretaire', 'paiements', FALSE, TRUE, FALSE, FALSE),
('secretaire', 'services', FALSE, TRUE, FALSE, FALSE),
-- Comptable gère les paiements
('comptable', 'eleves', FALSE, TRUE, FALSE, FALSE),
('comptable', 'paiements', TRUE, TRUE, TRUE, FALSE),
('comptable', 'services', FALSE, TRUE, TRUE, FALSE);

-- Fonction pour vérifier les permissions
DELIMITER //

CREATE FUNCTION check_permission(
    p_user_id INT,
    p_resource VARCHAR(50),
    p_action VARCHAR(10)
) RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE user_role VARCHAR(20);
    DECLARE has_permission BOOLEAN DEFAULT FALSE;
    
    -- Obtenir le rôle de l'utilisateur
    SELECT role INTO user_role FROM users WHERE id = p_user_id;
    
    -- Vérifier la permission
    CASE p_action
        WHEN 'create' THEN
            SELECT can_create INTO has_permission 
            FROM permissions 
            WHERE role = user_role AND resource = p_resource;
        WHEN 'read' THEN
            SELECT can_read INTO has_permission 
            FROM permissions 
            WHERE role = user_role AND resource = p_resource;
        WHEN 'update' THEN
            SELECT can_update INTO has_permission 
            FROM permissions 
            WHERE role = user_role AND resource = p_resource;
        WHEN 'delete' THEN
            SELECT can_delete INTO has_permission 
            FROM permissions 
            WHERE role = user_role AND resource = p_resource;
    END CASE;
    
    RETURN COALESCE(has_permission, FALSE);
END//

DELIMITER ;

-- Rapport des impayés
CREATE OR REPLACE VIEW vue_impayes AS
SELECT 
    e.matricule,
    CONCAT(e.prenom, ' ', e.nom) as eleve_nom,
    e.niveau,
    p.nom_complet as parent_nom,
    p.telephone as parent_telephone,
    t.mensualite,
    (t.mensualite * 9) as total_annuel,
    COALESCE(SUM(pay.montant), 0) as total_paye,
    ((t.mensualite * 9) - COALESCE(SUM(pay.montant), 0)) as montant_du
FROM eleves e
JOIN tarifs t ON e.niveau = t.niveau
LEFT JOIN paiements pay ON e.id = pay.eleve_id 
    AND pay.type_paiement = 'mensualite' 
    AND pay.statut IN ('complete', 'partiel')
    AND pay.annee_scolaire = '2024-2025'
LEFT JOIN eleves_parents ep ON e.id = ep.eleve_id AND ep.is_primary = 1
LEFT JOIN parents p ON ep.parent_id = p.id
WHERE e.statut = 'actif'
GROUP BY e.id, e.matricule, e.prenom, e.nom, e.niveau, p.nom_complet, p.telephone, t.mensualite
HAVING montant_du > 0
ORDER BY montant_du DESC;

-- Table pour les rappels de paiement
CREATE TABLE IF NOT EXISTS rappels_paiement (
    id INT AUTO_INCREMENT PRIMARY KEY,
    eleve_id INT NOT NULL,
    montant_du DECIMAL(10,2) NOT NULL,
    type_rappel ENUM('sms', 'email', 'courrier', 'appel') NOT NULL,
    contenu TEXT,
    destinataire VARCHAR(200),
    date_envoi DATETIME DEFAULT CURRENT_TIMESTAMP,
    statut ENUM('envoye', 'echec', 'en_attente') DEFAULT 'en_attente',
    created_by INT,
    FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_eleve (eleve_id),
    INDEX idx_date (date_envoi)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Statistiques financières
CREATE OR REPLACE VIEW vue_statistiques_financieres AS
SELECT 
    MONTH(date_paiement) as mois,
    MONTHNAME(date_paiement) as nom_mois,
    YEAR(date_paiement) as annee,
    type_paiement,
    COUNT(*) as nombre_paiements,
    SUM(montant) as total_montant,
    SUM(CASE WHEN mode_paiement = 'especes' THEN montant ELSE 0 END) as total_especes,
    SUM(CASE WHEN mode_paiement = 'cheque' THEN montant ELSE 0 END) as total_cheques,
    SUM(CASE WHEN mode_paiement = 'virement' THEN montant ELSE 0 END) as total_virements,
    SUM(CASE WHEN mode_paiement = 'mobile_money' THEN montant ELSE 0 END) as total_mobile
FROM paiements
WHERE statut = 'complete'
GROUP BY YEAR(date_paiement), MONTH(date_paiement), type_paiement
ORDER BY annee DESC, mois DESC;

-- Procédure pour générer un rapport financier mensuel
DELIMITER //

CREATE PROCEDURE rapport_financier_mensuel(
    IN p_mois INT,
    IN p_annee INT
)
BEGIN
    DECLARE debut_mois DATE;
    DECLARE fin_mois DATE;
    
    SET debut_mois = CONCAT(p_annee, '-', LPAD(p_mois, 2, '0'), '-01');
    SET fin_mois = LAST_DAY(debut_mois);
    
    -- Résumé général
    SELECT 
        COUNT(DISTINCT eleve_id) as nombre_eleves_payants,
        COUNT(*) as nombre_paiements,
        SUM(montant) as recettes_totales,
        SUM(CASE WHEN type_paiement = 'inscription' THEN montant ELSE 0 END) as recettes_inscriptions,
        SUM(CASE WHEN type_paiement = 'mensualite' THEN montant ELSE 0 END) as recettes_mensualites,
        SUM(CASE WHEN type_paiement = 'service' THEN montant ELSE 0 END) as recettes_services
    FROM paiements
    WHERE DATE(date_paiement) BETWEEN debut_mois AND fin_mois
    AND statut = 'complete';
    
    -- Détail par jour
    SELECT 
        DATE(date_paiement) as jour,
        COUNT(*) as nombre_paiements,
        SUM(montant) as total_jour
    FROM paiements
    WHERE DATE(date_paiement) BETWEEN debut_mois AND fin_mois
    AND statut = 'complete'
    GROUP BY DATE(date_paiement)
    ORDER BY jour;
    
    -- Top 10 des payeurs
    SELECT 
        e.matricule,
        CONCAT(e.prenom, ' ', e.nom) as eleve_nom,
        COUNT(p.id) as nombre_paiements,
        SUM(p.montant) as total_paye
    FROM paiements p
    JOIN eleves e ON p.eleve_id = e.id
    WHERE DATE(p.date_paiement) BETWEEN debut_mois AND fin_mois
    AND p.statut = 'complete'
    GROUP BY e.id
    ORDER BY total_paye DESC
    LIMIT 10;
END//

DELIMITER ;

-- Grant des privilèges minimum nécessaires à l'utilisateur de l'application
-- À exécuter en tant que root MySQL
-- GRANT SELECT, INSERT, UPDATE ON inscription_scolaire.* TO 'inscription_user'@'localhost';
-- GRANT DELETE ON inscription_scolaire.logs_activites TO 'inscription_user'@'localhost';
-- GRANT DELETE ON inscription_scolaire.documents TO 'inscription_user'@'localhost';
-- GRANT EXECUTE ON inscription_scolaire.* TO 'inscription_user'@'localhost';

-- Fin du script
