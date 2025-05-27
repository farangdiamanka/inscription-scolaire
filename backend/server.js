// server.js - Backend API pour le système d'inscription
const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Configuration de la base de données
const db = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'inscription_scolaire',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// Promisify pour async/await
const promiseDb = db.promise();

// Configuration pour l'upload de fichiers
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        const uploadDir = 'uploads/documents';
        if (!fs.existsSync(uploadDir)) {
            fs.mkdirSync(uploadDir, { recursive: true });
        }
        cb(null, uploadDir);
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({ 
    storage: storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max
    fileFilter: (req, file, cb) => {
        const allowedTypes = /jpeg|jpg|png|pdf|doc|docx/;
        const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
        const mimetype = allowedTypes.test(file.mimetype);
        
        if (mimetype && extname) {
            return cb(null, true);
        } else {
            cb('Error: Images and documents only!');
        }
    }
});

// Middleware d'authentification
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
        return res.sendStatus(401);
    }
    
    jwt.verify(token, process.env.JWT_SECRET || 'votre_secret_key', (err, user) => {
        if (err) return res.sendStatus(403);
        req.user = user;
        next();
    });
};

// Routes d'authentification
app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        
        const [users] = await promiseDb.execute(
            'SELECT * FROM users WHERE username = ?',
            [username]
        );
        
        if (users.length === 0) {
            return res.status(401).json({ error: 'Identifiants invalides' });
        }
        
        const user = users[0];
        const validPassword = await bcrypt.compare(password, user.password);
        
        if (!validPassword) {
            return res.status(401).json({ error: 'Identifiants invalides' });
        }
        
        const token = jwt.sign(
            { id: user.id, username: user.username, role: user.role },
            process.env.JWT_SECRET || 'votre_secret_key',
            { expiresIn: '24h' }
        );
        
        res.json({ 
            token, 
            user: { 
                id: user.id, 
                username: user.username, 
                role: user.role 
            } 
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// Routes pour les inscriptions
app.post('/api/inscriptions', authenticateToken, upload.array('documents', 5), async (req, res) => {
    const connection = await promiseDb.getConnection();
    
    try {
        await connection.beginTransaction();
        
        // Générer le matricule
        const [[{ max_matricule }]] = await connection.execute(
            'SELECT MAX(CAST(matricule AS UNSIGNED)) as max_matricule FROM eleves'
        );
        const newMatricule = (max_matricule || 240000) + 1;
        
        // Insérer l'élève
        const [eleveResult] = await connection.execute(
            `INSERT INTO eleves (
                matricule, prenom, nom, date_naissance, sexe, nationalite, 
                lieu_naissance, niveau, ecole_precedente, groupe_sanguin,
                conditions_medicales, medicaments, medecin_nom, created_by
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                newMatricule.toString(),
                req.body.prenom,
                req.body.nom,
                req.body.date_naissance,
                req.body.sexe,
                req.body.nationalite,
                req.body.lieu_naissance,
                req.body.niveau,
                req.body.ecole_precedente,
                req.body.groupe_sanguin,
                req.body.conditions_medicales,
                req.body.medicaments,
                req.body.medecin_nom,
                req.user.id
            ]
        );
        
        const eleveId = eleveResult.insertId;
        
        // Insérer les parents
        const [parent1Result] = await connection.execute(
            `INSERT INTO parents (
                nom_complet, telephone, email, profession, adresse, relation
            ) VALUES (?, ?, ?, ?, ?, ?)`,
            [
                req.body.parent1_nom,
                req.body.parent1_telephone,
                req.body.parent1_email,
                req.body.parent1_profession,
                req.body.parent1_adresse,
                req.body.parent1_relation
            ]
        );
        
        // Lier parent et élève
        await connection.execute(
            'INSERT INTO eleves_parents (eleve_id, parent_id, is_primary) VALUES (?, ?, ?)',
            [eleveId, parent1Result.insertId, true]
        );
        
        // Parent 2 si fourni
        if (req.body.parent2_nom) {
            const [parent2Result] = await connection.execute(
                `INSERT INTO parents (
                    nom_complet, telephone, email, profession, relation
                ) VALUES (?, ?, ?, ?, ?)`,
                [
                    req.body.parent2_nom,
                    req.body.parent2_telephone,
                    req.body.parent2_email,
                    req.body.parent2_profession,
                    'Parent 2'
                ]
            );
            
            await connection.execute(
                'INSERT INTO eleves_parents (eleve_id, parent_id, is_primary) VALUES (?, ?, ?)',
                [eleveId, parent2Result.insertId, false]
            );
        }
        
        // Contact d'urgence
        await connection.execute(
            `INSERT INTO contacts_urgence (
                eleve_id, nom, telephone, relation
            ) VALUES (?, ?, ?, ?)`,
            [
                eleveId,
                req.body.urgence_nom,
                req.body.urgence_telephone,
                req.body.urgence_relation
            ]
        );
        
        // Services
        const services = JSON.parse(req.body.services || '[]');
        for (const service of services) {
            await connection.execute(
                'INSERT INTO services_eleves (eleve_id, service_type, details) VALUES (?, ?, ?)',
                [eleveId, service, req.body[`${service}_details`] || '{}']
            );
        }
        
        // Paiement
        await connection.execute(
            `INSERT INTO paiements (
                eleve_id, type_paiement, montant, mode_paiement, 
                reference, statut, created_by
            ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [
                eleveId,
                'inscription',
                req.body.montant_total,
                req.body.mode_paiement,
                req.body.reference_paiement,
                'complete',
                req.user.id
            ]
        );
        
        // Documents uploadés
        if (req.files) {
            for (const file of req.files) {
                await connection.execute(
                    'INSERT INTO documents (eleve_id, type, filename, path) VALUES (?, ?, ?, ?)',
                    [eleveId, file.fieldname, file.originalname, file.path]
                );
            }
        }
        
        await connection.commit();
        
        res.json({ 
            success: true, 
            matricule: newMatricule,
            message: 'Inscription réussie'
        });
        
    } catch (error) {
        await connection.rollback();
        console.error(error);
        res.status(500).json({ error: 'Erreur lors de l\'inscription' });
    } finally {
        connection.release();
    }
});

// Route pour la réinscription
app.post('/api/reinscriptions/:matricule', authenticateToken, async (req, res) => {
    const connection = await promiseDb.getConnection();
    
    try {
        await connection.beginTransaction();
        
        // Vérifier que l'élève existe
        const [[eleve]] = await connection.execute(
            'SELECT id FROM eleves WHERE matricule = ?',
            [req.params.matricule]
        );
        
        if (!eleve) {
            return res.status(404).json({ error: 'Élève non trouvé' });
        }
        
        // Mettre à jour le niveau
        await connection.execute(
            'UPDATE eleves SET niveau = ? WHERE id = ?',
            [req.body.nouveau_niveau, eleve.id]
        );
        
        // Enregistrer la réinscription
        await connection.execute(
            `INSERT INTO reinscriptions (
                eleve_id, ancien_niveau, nouveau_niveau, annee_scolaire, created_by
            ) VALUES (?, ?, ?, ?, ?)`,
            [
                eleve.id,
                req.body.ancien_niveau,
                req.body.nouveau_niveau,
                req.body.annee_scolaire,
                req.user.id
            ]
        );
        
        // Enregistrer le paiement
        await connection.execute(
            `INSERT INTO paiements (
                eleve_id, type_paiement, montant, mode_paiement, 
                reference, statut, created_by
            ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [
                eleve.id,
                'reinscription',
                req.body.montant_total,
                req.body.mode_paiement,
                req.body.reference_paiement,
                'complete',
                req.user.id
            ]
        );
        
        await connection.commit();
        
        res.json({ 
            success: true, 
            message: 'Réinscription réussie'
        });
        
    } catch (error) {
        await connection.rollback();
        console.error(error);
        res.status(500).json({ error: 'Erreur lors de la réinscription' });
    } finally {
        connection.release();
    }
});

// Route de recherche
app.get('/api/eleves/search', authenticateToken, async (req, res) => {
    try {
        let query = `
            SELECT e.*, 
                   GROUP_CONCAT(DISTINCT s.service_type) as services,
                   p.nom_complet as parent_nom,
                   p.telephone as parent_telephone
            FROM eleves e
            LEFT JOIN services_eleves s ON e.id = s.eleve_id
            LEFT JOIN eleves_parents ep ON e.id = ep.eleve_id AND ep.is_primary = 1
            LEFT JOIN parents p ON ep.parent_id = p.id
            WHERE 1=1
        `;
        
        const params = [];
        
        if (req.query.matricule) {
            query += ' AND e.matricule LIKE ?';
            params.push(`%${req.query.matricule}%`);
        }
        
        if (req.query.nom) {
            query += ' AND (e.nom LIKE ? OR e.prenom LIKE ?)';
            params.push(`%${req.query.nom}%`, `%${req.query.nom}%`);
        }
        
        if (req.query.niveau) {
            query += ' AND e.niveau = ?';
            params.push(req.query.niveau);
        }
        
        query += ' GROUP BY e.id';
        
        const [results] = await promiseDb.execute(query, params);
        
        res.json(results);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Erreur lors de la recherche' });
    }
});

// Route pour les statistiques
app.get('/api/statistiques', authenticateToken, async (req, res) => {
    try {
        const [totalEleves] = await promiseDb.execute(
            'SELECT COUNT(*) as total FROM eleves'
        );
        
        const [parSexe] = await promiseDb.execute(
            'SELECT sexe, COUNT(*) as count FROM eleves GROUP BY sexe'
        );
        
        const [parNiveau] = await promiseDb.execute(
            'SELECT niveau, COUNT(*) as count FROM eleves GROUP BY niveau'
        );
        
        const [nouveauxInscrits] = await promiseDb.execute(
            'SELECT COUNT(*) as total FROM eleves WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)'
        );
        
        const [services] = await promiseDb.execute(
            'SELECT service_type, COUNT(*) as count FROM services_eleves GROUP BY service_type'
        );
        
        res.json({
            total: totalEleves[0].total,
            parSexe: parSexe,
            parNiveau: parNiveau,
            nouveaux: nouveauxInscrits[0].total,
            services: services
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Erreur lors de la récupération des statistiques' });
    }
});

// Route pour exporter en Excel
app.get('/api/export/excel', authenticateToken, async (req, res) => {
    try {
        const ExcelJS = require('exceljs');
        const workbook = new ExcelJS.Workbook();
        const worksheet = workbook.addWorksheet('Inscriptions');
        
        // En-têtes
        worksheet.columns = [
            { header: 'Matricule', key: 'matricule', width: 15 },
            { header: 'Prénom', key: 'prenom', width: 20 },
            { header: 'Nom', key: 'nom', width: 20 },
            { header: 'Date Naissance', key: 'date_naissance', width: 15 },
            { header: 'Sexe', key: 'sexe', width: 10 },
            { header: 'Niveau', key: 'niveau', width: 10 },
            { header: 'Parent', key: 'parent_nom', width: 25 },
            { header: 'Téléphone', key: 'parent_telephone', width: 15 },
            { header: 'Services', key: 'services', width: 30 }
        ];
        
        // Données
        const [eleves] = await promiseDb.execute(`
            SELECT e.*, 
                   GROUP_CONCAT(DISTINCT s.service_type) as services,
                   p.nom_complet as parent_nom,
                   p.telephone as parent_telephone
            FROM eleves e
            LEFT JOIN services_eleves s ON e.id = s.eleve_id
            LEFT JOIN eleves_parents ep ON e.id = ep.eleve_id AND ep.is_primary = 1
            LEFT JOIN parents p ON ep.parent_id = p.id
            GROUP BY e.id
        `);
        
        worksheet.addRows(eleves);
        
        // Style
        worksheet.getRow(1).font = { bold: true };
        worksheet.getRow(1).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: 'FF3498DB' }
        };
        
        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        res.setHeader('Content-Disposition', 'attachment; filename=inscriptions.xlsx');
        
        await workbook.xlsx.write(res);
        res.end();
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Erreur lors de l\'export' });
    }
});

// Route pour les tarifs
app.get('/api/tarifs', async (req, res) => {
    try {
        const [tarifs] = await promiseDb.execute('SELECT * FROM tarifs');
        res.json(tarifs);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Erreur lors de la récupération des tarifs' });
    }
});

// Démarrage du serveur
app.listen(PORT, () => {
    console.log(`Serveur démarré sur le port ${PORT}`);
});

// Script d'initialisation de la base de données
const initDatabase = async () => {
    try {
        // Créer la base de données si elle n'existe pas
        await promiseDb.execute(`CREATE DATABASE IF NOT EXISTS inscription_scolaire`);
        
        // Tables
        await promiseDb.execute(`
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                password VARCHAR(255) NOT NULL,
                role ENUM('admin', 'secretaire', 'comptable') DEFAULT 'secretaire',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);
        
        await promiseDb.execute(`
            CREATE TABLE IF NOT EXISTS eleves (
                id INT AUTO_INCREMENT PRIMARY KEY,
                matricule VARCHAR(20) UNIQUE NOT NULL,
                prenom VARCHAR(100) NOT NULL,
                nom VARCHAR(100) NOT NULL,
                date_naissance DATE,
                sexe ENUM('M', 'F'),
                nationalite VARCHAR(50),
                lieu_naissance VARCHAR(100),
                niveau VARCHAR(20),
                ecole_precedente VARCHAR(200),
                groupe_sanguin VARCHAR(5),
                conditions_medicales TEXT,
                medicaments TEXT,
                medecin_nom VARCHAR(200),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                created_by INT,
                INDEX idx_matricule (matricule),
                INDEX idx_nom (nom, prenom)
            )
        `);
        
        await promiseDb.execute(`
            CREATE TABLE IF NOT EXISTS parents (
                id INT AUTO_INCREMENT PRIMARY KEY,
                nom_complet VARCHAR(200) NOT NULL,
                telephone VARCHAR(20),
                email VARCHAR(100),
                profession VARCHAR(100),
                adresse TEXT,
                relation VARCHAR(50),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);
        
        await promiseDb.execute(`
            CREATE TABLE IF NOT EXISTS eleves_parents (
                eleve_id INT,
                parent_id INT,
                is_primary BOOLEAN DEFAULT FALSE,
                PRIMARY KEY (eleve_id, parent_id),
                FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE,
                FOREIGN KEY (parent_id) REFERENCES parents(id) ON DELETE CASCADE
            )
        `);
        
        await promiseDb.execute(`
            CREATE TABLE IF NOT EXISTS contacts_urgence (
                id INT AUTO_INCREMENT PRIMARY KEY,
                eleve_id INT,
                nom VARCHAR(200),
                telephone VARCHAR(20),
                relation VARCHAR(50),
                FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE
            )
        `);
        
        await promiseDb.execute(`
            CREATE TABLE IF NOT EXISTS services_eleves (
                id INT AUTO_INCREMENT PRIMARY KEY,
                eleve_id INT,
                service_type ENUM('transport', 'cantine', 'taekwondo', 'fournitures'),
                details JSON,
                date_debut DATE DEFAULT CURRENT_DATE,
                date_fin DATE,
                statut ENUM('actif', 'suspendu', 'termine') DEFAULT 'actif',
                FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE
            )
        `);
        
        await promiseDb.execute(`
            CREATE TABLE IF NOT EXISTS paiements (
                id INT AUTO_INCREMENT PRIMARY KEY,
                eleve_id INT,
                type_paiement VARCHAR(50),
                montant DECIMAL(10, 2),
                mode_paiement VARCHAR(50),
                reference VARCHAR(100),
                statut ENUM('en_attente', 'complete', 'annule') DEFAULT 'complete',
                date_paiement TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                created_by INT,
                FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE
            )
        `);
        
        await promiseDb.execute(`
            CREATE TABLE IF NOT EXISTS documents (
                id INT AUTO_INCREMENT PRIMARY KEY,
                eleve_id INT,
                type VARCHAR(50),
                filename VARCHAR(255),
                path VARCHAR(500),
                uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE
            )
        `);
        
        await promiseDb.execute(`
            CREATE TABLE IF NOT EXISTS reinscriptions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                eleve_id INT,
                ancien_niveau VARCHAR(20),
                nouveau_niveau VARCHAR(20),
                annee_scolaire VARCHAR(20),
                date_reinscription TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                created_by INT,
                FOREIGN KEY (eleve_id) REFERENCES eleves(id) ON DELETE CASCADE
            )
        `);
        
        await promiseDb.execute(`
            CREATE TABLE IF NOT EXISTS tarifs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                niveau VARCHAR(20) UNIQUE,
                frais_inscription DECIMAL(10, 2),
                mensualite DECIMAL(10, 2),
                frais_reinscription DECIMAL(10, 2)
            )
        `);
        
        // Insérer les tarifs par défaut
        const tarifs = [
            ['PPS', 30000, 120000, 20000],
            ['PS', 30000, 120000, 20000],
            ['MS', 30000, 120000, 20000],
            ['GS', 30000, 120000, 20000],
            ['CI', 30000, 130000, 20000],
            ['CP', 30000, 130000, 20000],
            ['CE1', 30000, 130000, 20000],
            ['CE2', 30000, 130000, 20000],
            ['CM1', 30000, 130000, 20000],
            ['CM2', 30000, 130000, 20000],
            ['6eme', 30000, 140000, 20000],
            ['5eme', 30000, 140000, 20000],
            ['4eme', 30000, 140000, 20000],
            ['3eme', 30000, 140000, 20000],
            ['2nd', 30000, 150000, 20000],
            ['Hifz', 30000, 100000, 20000]
        ];
        
        for (const tarif of tarifs) {
            await promiseDb.execute(
                'INSERT IGNORE INTO tarifs (niveau, frais_inscription, mensualite, frais_reinscription) VALUES (?, ?, ?, ?)',
                tarif
            );
        }
        
        // Créer un utilisateur admin par défaut
        const hashedPassword = await bcrypt.hash('admin123', 10);
        await promiseDb.execute(
            'INSERT IGNORE INTO users (username, password, role) VALUES (?, ?, ?)',
            ['admin', hashedPassword, 'admin']
        );
        
        console.log('Base de données initialisée avec succès');
    } catch (error) {
        console.error('Erreur lors de l\'initialisation de la base de données:', error);
    }
};

// Appeler initDatabase au démarrage
initDatabase();
