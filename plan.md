# RentalCore → WarehouseCore Feature Migration Plan

## Kontext

RentalCore (Go 1.23) enthält aktuell sowohl Jobmanagement als auch zahlreiche Lager-/Produktfunktionen. Ziel ist eine Trennung:

- **RentalCore**: reines Job-/Kundenverwaltungssystem. Keine Produkt-, Gerät-, Kabel-, Case-, Scanner- oder Warehouse-spezifischen Funktionen mehr.
- **WarehouseCore**: komplette Lagerverwaltung inklusive Produkt-/Geräteanlage, Kabel-/Case-Management, Scanner-Workflows etc.

Beide Services nutzen dieselbe MySQL-Datenbank. Migration erfolgt funktionsweise: Logik, UI, Routen, Tests und Dokumentation müssen aus RentalCore entfernt bzw. deaktiviert und in WarehouseCore ergänzt/übernommen werden.

Wichtige Artefakte:

- `rentalcore/cmd/server/main.go`: Routenregistrierung
- `rentalcore/internal/handlers/*`: Handler (z.B. `product_handler.go`, `device_handler.go`, `cable_handler.go`, `case_handler.go`, `scanner_handler.go`)
- `rentalcore/internal/repository/*`: Repositories für DB-Zugriff
- `rentalcore/web/templates/*`: HTML-Templates
- `rentalcore/web/static/js/css`: Scripts/Styles für UI
- `warehousecore/web/src/*`: React-Frontend (Admin-Module)
- `warehousecore/internal/...`: API-/Service-Layer

## Vorgeschlagene Migrationsphasen

> Jede Phase enthält Analyse, Implementierung (WarehouseCore), Entfernung/Deaktivierung (RentalCore), Tests, Dokumentation, Docker-Release.

### Phase 1 – Produkverwaltung
- [x] **Analyse RentalCore**
  - [x] Kernkomponenten identifiziert: Handler `internal/handlers/product_handler.go`, Repository `internal/repository/product_repository.go`, Template `web/templates/products_standalone.html`, API-Routen (`/products`, `/products/new`, `/api/v1/products`, Kategorie-/Brand-/Hersteller-Endpunkte), Job-/UI-Verknüpfungen (Navbar etc.).
  - [x] Detailprüfung weiterer Abhängigkeiten (Job-Formulare, Invoices, Device-Listen per Produkt, Breadcrumbs etc.).
    - Server: Produktdaten fließen in `cmd/server/main.go` (Routen + Handler-Wiring), `internal/handlers/device_handler.go`, `internal/handlers/invoice_handler.go`, `internal/handlers/job_handler.go`, `internal/handlers/analytics_handler.go`, `internal/repository/device_repository.go`, `internal/repository/job_repository.go`, `internal/database/migrations/001_performance_indexes.sql` sowie `RentalCore.sql` (Tabellen + Views).
    - UI: Produktbezug in `web/templates/navbar.html`, `web/templates/products_standalone.html`, `web/templates/devices_standalone.html`, `web/templates/device_form.html`, `web/templates/job_form.html`, `web/templates/jobs.html`, `web/templates/job_detail.html`, `web/templates/invoice_form.html`, `web/templates/analytics_dashboard*.html`, `web/templates/scan_job.html`.
  - [x] RBAC-/Permission-Einträge und Tests lokalisieren.
    - Keine dedizierte `products.*`-Permission; Rollen in `RentalCore.sql` (`roles`-Seed ab Zeile 3445) geben Produktzugriff implizit über `jobs/device`-Scopes bzw. `warehouse.*`.
    - Bestehende Tests weiterhin im Go-/UI-Bereich verteilt; zusätzliche Testfälle bei Feature-Abschaltung erforderlich.
- [x] **Analyse WarehouseCore**
  - [x] Bestehende Module: Admin `ProductsTab` (React), Backend `internal/handlers/product_handlers.go` inkl. Geräte-Bulk-Erstellung.
  - [x] Abgleich der Felder/Validierungen mit RentalCore (z.B. Brands/Manufacturer, Kategorienbaum, DeviceCreateOptionen).
    - Backend `warehousecore/internal/handlers/product_handlers.go:16-357` akzeptiert alle Felder aus RentalCore (`categoryID`, `brandID`, Maße, PowerConsumption, MaintenanceInterval, PosInCategory) und ergänzt `/admin/products/{id}/devices` für Bulk-Device-Anlage.
    - Lookup-APIs für Kategorien, Marken und Hersteller stehen bereit (`warehousecore/internal/handlers/category_handlers.go:33-211`, `warehousecore/internal/handlers/brand_handlers.go:14-356`).
    - Validierung derzeit minimal (nur Name-Pflicht in `CreateProduct`); entspricht RentalCore, weitere Prüfungen (z.B. Kategorie + Subcategory-Konsistenz) könnten ergänzt werden.
- [ ] **WarehouseCore Implementierung**
- [ ] Produkt-Tab/Frontend erweitern (ggf. Layout/UX an RentalCore angleichen).
   - [x] Formularfelder ergänzen (Brand, Manufacturer, physische Maße, technische Specs, Maintenance, PosInCategory, Geräte-Batchanlage).
     - Modal deckt komplette Stammdaten inkl. Bulk-Geräteanlage (`warehousecore/web/src/components/admin/ProductsTab.tsx`).
   - [x] Bearbeiten-Modus implementieren (Produkt laden, Werte füllen, Update-Flow).
     - Edit-/View-Buttons rufen `/admin/products/:id` auf und füllen Formular/Detailansicht.
   - [x] Form-Validierung/UX anpassen (Fehleranzeigen, Pflichtfelder).
     - Such-/Filterleiste, Listen-/Karten-View, Detailmodale und Reset-Buttons spiegeln RentalCore UX.
- [ ] Backend-API anpassen (POST/PUT/DELETE Produkte, Dropdown-Daten etc.).
   - [x] Endpunkte für Brands/Manufacturer anbieten (`GET /brands`, `GET /manufacturers`).
  - [x] Sicherstellen, dass Create/Update alle Felder speichern (inkl. optionaler Geräteanlage).
    - SQL-Einfüge-/Update-Statements setzen sämtliche Pflicht- und optionalen Felder (`warehousecore/internal/handlers/product_handlers.go:235-321`), Bulk-Geräteanlage via `/admin/products/{id}/devices` bleibt verfügbar (`warehousecore/internal/handlers/product_handlers.go:359-529`).
  - [x] Response-Modelle angleichen (IDs, Names für Dropdowns).
    - API liefert konsistente Felder inkl. `brand_name` und `manufacturer_name` (`warehousecore/internal/handlers/product_handlers.go:39-226`), Frontend konsumiert direkt (`warehousecore/web/src/components/admin/ProductsTab.tsx`).
- [ ] Tests aktualisieren/ergänzen.
- [ ] **RentalCore deaktivieren**
  - [ ] Entferne /products-Routen + Templates.
  - [ ] Entferne/disable Handler & Repository-Aufrufe (ggf. Feature-Flag für Restbestände).
  - [ ] Navigations-/UI-Verweise (Navbar, Dashboard, Job-Formen, Analytics) bereinigen bzw. Link auf WarehouseCore setzen.
  - [ ] Lesezugriffe beibehalten bzw. neu implementieren (Jobs benötigen Produkt-/Geräte-Infos weiterhin read-only).
  - [ ] API-Clients anpassen (Status 410 oder Redirect, falls Drittsysteme?).
  - [ ] Tests & Dokumentation anpassen (README, Makefile, Tour).
- [ ] **Verifikation**
  - [x] Go-Tests (beide Services).
    - `go test ./...` in `warehousecore` (bestehend).
  - [x] Frontend-Build WarehouseCore (`npm run build`).
  - [ ] Docker Builds + Push.
  - [ ] README/Docs aktualisieren.
- [ ] **RentalCore deaktivieren**
  - [ ] Entferne /products-Routen + Templates.
  - [ ] Entferne/disable Handler & Repository-Aufrufe (ggf. Feature-Flag für Restbestände).
  - [ ] Navigations-/UI-Verweise (Navbar, Dashboard, Job-Formen, Analytics) bereinigen bzw. Link auf WarehouseCore setzen.
  - [ ] Lesezugriffe beibehalten bzw. neu implementieren (Jobs benötigen Produkt-/Geräte-Infos weiterhin read-only).
  - [ ] API-Clients anpassen (Status 410 oder Redirect, falls Drittsysteme?).
  - [ ] Tests & Dokumentation anpassen (README, Makefile, Tour).
- [ ] **Verifikation**
  - [x] Go-Tests (beide Services).
    - `go test ./...` in `warehousecore` (bestehend).
  - [x] Frontend-Build WarehouseCore (`npm run build`).
  - [ ] Docker Builds + Push.
  - [ ] README/Docs aktualisieren.

### Phase 2 – Geräteverwaltung
- [ ] Ähnlicher Ablauf wie Phase 1 (Analyse → Migration → Deaktivierung → Tests).
- [ ] Berücksichtige Geräte-spezifische APIs (Bulk-Erstellung, QR-Codes etc.).
- [ ] UI: WarehouseCore Admin-Module für Geräte erweitern.

### Phase 3 – Scanner/Barcode Workflows
- [ ] Identifiziere `scanner_handler.go`, `web/templates/scan_*`, WASM-Decoder etc.
- [ ] Prüfe, wie WarehouseCore die Scanner-Funktion nutzen soll (z.B. vorhandenes React UI?).
- [ ] Migriere APIs + Frontend, deaktiviere RentalCore Routen.

### Phase 4 – Kabel-Management
- [ ] Handler/Routes (z.B. `/cables`), Templates, Services.
- [ ] WarehouseCore Module erstellen (Admin UI + API).
- [ ] Entferne aus RentalCore.

### Phase 5 – Case-Management
- [ ] Handler/Routes (z.B. `/cases`), Templates.
- [ ] WarehouseCore UI + API.
- [ ] Entferne aus RentalCore.

### Phase 6 – Sonstige Warehouse-Funktionalität
- [ ] Prüfen, ob weitere Warehouse-Funktionalitäten existieren (Bestände, Monitoring, LED etc).
- [ ] Konsolidieren in WarehouseCore.

## Querschnittsaufgaben

- **RBAC/Permissions:** Rollen anpassen (RentalCore soll keine „warehouse“ Berechtigungen mehr haben; WarehouseCore Admin muss neue Features sehen).
- **Dokumentation:** README, Deployment-Anleitungen, Makefiles, Docker Compose.
- **Navigation:** Cross-Link (RentalCore → WarehouseCore) klar ersichtlich (z.B. Buttons statt eigenem Management).
- **Tests:** Jede Phase erfordert Go-Tests & ggf. Integrationstests. WarehouseCore Frontend-Build muss laufen.
- **Docker:** Nach jeder Phase neue Images (z.B. `nobentie/rentalcore:<version>`, `nobentie/warehousecore:<version>`).
- **Monitoring/Logging:** Anpassung falls nötig (z.B. tags, Prometheus).

## Aktueller Stand (Chronologisch)

### ✅ Vorarbeiten
- [x] Branding-Divergenzen aus RentalCore entfernt, Header zeigt dynamischen Firmennamen (`company_provider`).
- [x] Manager dürfen Passwörter zurücksetzen; Force Password Change aktiv.
- [x] RentalCore: Produktmodal fixiert (zentriert, Scroll-Lock), Docker Push `nobentie/rentalcore:1.6`.
- [x] WarehouseCore: Produktmodal aktualisiert, Scroll-Lock, Docker Push `nobentie/warehousecore:1.6`.
- [x] Code auf `main` → GitLab, Docker Hub aktualisiert.

### ⏳ Phase 1 – Produkverwaltung (noch nicht gestartet)
- [ ] (Analyse) Funktionsumfang aufnehmen.
- [ ] (WarehouseCore) Anforderungsabgleich / Implementierung.
- [ ] (RentalCore) Deaktivieren.
  - [ ] (Tests/Docker) Ausstehend.

### ⏳ Weitere Phasen
- [ ] Geräteverwaltung
- [ ] Scanner/Barcode
- [ ] Kabelmanagement
- [ ] Case-Management
- [ ] Restliche Warehouse-Funktionen

## Nächste Schritte

1. **Analyse Phase 1:** Detaillierte Auflistung aller Produkt-bezogenen Ressourcen in RentalCore.  
2. **Design Entscheidung:** WarehouseCore UI/UX für Produktanlage vereinheitlichen (falls abweichend).  
3. **Implementierung WarehouseCore:** API + Frontend.  
4. **RentalCore deaktivieren:** Routen, Handler, Templates entfernen.  
5. **Tests + Docker**: Go-Tests, `npm run build`, Docker build/push.  
6. **Plan.md aktualisieren:** Fortschritt mit Kontext/Verweis auf Commits & Images dokumentieren.  
7. **Phase 2 vorbereiten** (Geräteverwaltung).

> Bei jedem Schritt Plan aktualisieren, damit andere Agenten sofort sehen, wo wir stehen (Commits, Images, offene Punkte).
