# 🚀 Deployment-Ready System Implementation Plan

**Erstellt:** 2026-01-09
**Ziel:** RentalCore und WarehouseCore auf jedem neuen System mit einem einzigen Docker Compose Befehl deploybar machen

---

## 📋 Übersicht der Aufgaben

### Phase 1: Standard-User & Berechtigungsmanagement ✅
- [ ] 1.1 Standard Admin-User in Migration erweitern (höchste Rechte für beide Systeme)
- [ ] 1.2 Unified RBAC System implementieren (ein Berechtigungsmanagement für beide Systeme)
- [ ] 1.3 Force Password Change bei erstem Login
- [ ] 1.4 Admin-Rollen erweitern für beide Systeme

### Phase 2: Admin-Seiten für System-Konfiguration
- [ ] 2.1 RentalCore Admin-Seite erstellen
  - [ ] Company Settings (UI für Unternehmenseinstellungen)
  - [ ] Status Management (Job-Status verwalten)
  - [ ] User Management (Benutzer verwalten)
  - [ ] Role Management (Rollen verwalten)
- [ ] 2.2 WarehouseCore Admin-Seite erweitern
  - [ ] Storage Zone Types Management
  - [ ] LED Defaults
  - [ ] User & Role Management (shared mit RentalCore)

### Phase 3: Docker Compose & ENV Optimierung
- [ ] 3.1 .env.example aktualisieren und vervollständigen
- [ ] 3.2 docker-compose.yml prüfen und optimieren
- [ ] 3.3 Alle notwendigen Migrationen in `/migrations/postgresql/` integrieren
- [ ] 3.4 Sicherstellen, dass Fresh Deploy funktioniert

### Phase 4: Docker Images bauen & pushen
- [ ] 4.1 RentalCore Build & Push (neue Version: 5.3.0)
- [ ] 4.2 WarehouseCore Build & Push (neue Version: 5.8.0)
- [ ] 4.3 Beide mit `latest` Tag versehen

### Phase 5: READMEs & Dokumentation aktualisieren
- [ ] 5.1 cores/README.md aktualisieren
- [ ] 5.2 rentalcore/README.md aktualisieren
- [ ] 5.3 warehousecore/README.md aktualisieren
- [ ] 5.4 DEPLOYMENT_GUIDE.md aktualisieren
- [ ] 5.5 CLAUDE.md und GEMINI.md bereinigen

### Phase 6: Repos aufräumen
- [ ] 6.1 Nicht mehr benötigte Dateien löschen
- [ ] 6.2 Veraltete Dokumentation entfernen/aktualisieren
- [ ] 6.3 .gitignore prüfen

### Phase 7: Security Check
- [ ] 7.1 Code auf Vulnerabilities prüfen
- [ ] 7.2 Exposed Credentials prüfen
- [ ] 7.3 Dependencies auf bekannte Schwachstellen prüfen

### Phase 8: Git Push
- [ ] 8.1 Cores Repo pushen
- [ ] 8.2 RentalCore Repo pushen
- [ ] 8.3 WarehouseCore Repo pushen

---

## 📊 Aktueller Stand

### Docker Hub Versionen (aktuell):
- **RentalCore:** `5.2.8` (latest am 2025-12-25)
- **WarehouseCore:** `1.0.1` (latest am 2025-12-25)

### Neue Versionen:
- **RentalCore:** `5.3.0` (nach Änderungen)
- **WarehouseCore:** `5.8.0` (nach Änderungen)

---

## 🔧 Technische Details

### Standard Admin-User:
- **Username:** `admin`
- **Password:** `admin` (muss beim ersten Login geändert werden)
- **Email:** `admin@example.com`
- **Rollen:** `super_admin`, `admin`, `warehouse_admin`

### RBAC Rollen (Unified):
| Rolle | Scope | Beschreibung |
|-------|-------|--------------|
| `super_admin` | Global | Vollzugriff auf beide Systeme |
| `admin` | RentalCore | RentalCore Administration |
| `manager` | RentalCore | Jobs, Kunden, Geräte |
| `operator` | RentalCore | Operative Aufgaben |
| `viewer` | RentalCore | Nur-Lese-Zugriff |
| `warehouse_admin` | Warehouse | Warehouse Administration |
| `warehouse_manager` | Warehouse | Warehouse Operationen |
| `warehouse_worker` | Warehouse | Tägliche Aufgaben |
| `warehouse_viewer` | Warehouse | Nur-Lese-Zugriff |

### Database-Tabellen für Admin-Konfiguration:
- `company_settings` - Unternehmenseinstellungen
- `statuses` - Job-Status
- `roles` - RBAC Rollen
- `user_roles` - Benutzer-Rollen-Zuordnung
- `app_settings` - Anwendungs-spezifische Einstellungen

---

## 📝 Fortschritt

### ✅ Abgeschlossen
- [x] Analyse der bestehenden Struktur
- [x] Docker Hub Versionen geprüft
- [x] Plan erstellt

### 🔄 In Bearbeitung
- [ ] Phase 1: Standard-User & Berechtigungsmanagement

### ⏳ Ausstehend
- [ ] Phase 2-8

---

## 📌 Notizen

- **WICHTIG:** Docker03 nicht berühren! Nur lesen erlaubt.
- Alle Änderungen in lokalen Repos, dann Docker Images builden und zu DockerHub pushen
- Nach jedem Build: Git Push zu allen drei Repos

---

*Letzte Aktualisierung: 2026-01-09 17:26 CET*
