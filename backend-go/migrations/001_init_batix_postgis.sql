-- ============================================================================
-- BATIX v3.1 — Schéma PostgreSQL + PostGIS (Section 20.2 du Cahier des Charges)
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Comptes et Rôles (Section 2 & 15)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(160) NOT NULL,
    phone VARCHAR(32) UNIQUE NOT NULL,
    phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
    roles TEXT[] NOT NULL DEFAULT ARRAY['client_particulier'],
    kyc_level VARCHAR(32) NOT NULL DEFAULT 'visiteur', -- visiteur, contact_verifie, identite_verifiee, entreprise_verifiee, renforce
    two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Entrepôts Fournisseurs & Stocks (Section 7)
CREATE TABLE warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL REFERENCES users(id),
    name VARCHAR(120) NOT NULL,
    quartier VARCHAR(80) NOT NULL,
    landmark TEXT NOT NULL,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    opening_hours VARCHAR(80) NOT NULL,
    max_truck_tonnage NUMERIC(5,2) NOT NULL DEFAULT 20.0,
    loading_equipment TEXT[] NOT NULL DEFAULT ARRAY['manuel']
);

CREATE TABLE warehouse_stocks (
    warehouse_id UUID NOT NULL REFERENCES warehouses(id),
    product_code VARCHAR(64) NOT NULL,
    physical_qty INTEGER NOT NULL CHECK (physical_qty >= 0),
    reserved_qty INTEGER NOT NULL DEFAULT 0 CHECK (reserved_qty >= 0),
    unit_price_fcfa INTEGER NOT NULL CHECK (unit_price_fcfa > 0),
    last_confirmed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (warehouse_id, product_code),
    CONSTRAINT available_non_negative CHECK (physical_qty >= reserved_qty)
);

-- 3. Commandes & Sous-commandes (Section 3 & 6)
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES users(id),
    chantier_quartier VARCHAR(120) NOT NULL,
    chantier_location GEOGRAPHY(POINT, 4326) NOT NULL,
    receptionnaire_name VARCHAR(160) NOT NULL,
    receptionnaire_phone VARCHAR(32) NOT NULL,
    materials_total_fcfa INTEGER NOT NULL,
    transport_total_fcfa INTEGER NOT NULL,
    manutention_total_fcfa INTEGER NOT NULL DEFAULT 0,
    service_fee_fcfa INTEGER NOT NULL,
    advantage_discount_fcfa INTEGER NOT NULL DEFAULT 0,
    grand_total_fcfa INTEGER NOT NULL,
    state VARCHAR(40) NOT NULL DEFAULT 'brouillon',
    idempotency_key VARCHAR(120) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Preuves de Livraison Anti-Fraude (Section 9 & 20.5)
CREATE TABLE delivery_proofs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id),
    driver_id UUID NOT NULL REFERENCES users(id),
    photo1_plate_url TEXT NOT NULL,
    photo1_sha256 CHAR(64) UNIQUE NOT NULL, -- Empêche la réutilisation d'une photo sur 2 missions
    photo1_distance_m NUMERIC(6,2) NOT NULL CHECK (photo1_distance_m <= 150.0),
    photo2_cargo_url TEXT NOT NULL,
    photo2_sha256 CHAR(64) UNIQUE NOT NULL,
    photo2_distance_m NUMERIC(6,2) NOT NULL CHECK (photo2_distance_m <= 150.0),
    photo3_ground_url TEXT NOT NULL,
    photo3_sha256 CHAR(64) UNIQUE NOT NULL,
    photo3_distance_m NUMERIC(6,2) NOT NULL CHECK (photo3_distance_m <= 150.0),
    signature_image_url TEXT NOT NULL,
    sms_otp_verified BOOLEAN NOT NULL DEFAULT FALSE,
    received_qty INTEGER NOT NULL,
    ordered_qty INTEGER NOT NULL,
    server_received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Double Validation des Mouvements Manuels (Section 10.4 & 16.3)
CREATE TABLE manual_payout_approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id),
    amount_fcfa INTEGER NOT NULL CHECK (amount_fcfa > 0),
    reason TEXT NOT NULL,
    requested_by UUID NOT NULL REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    CONSTRAINT dual_control_distinct_actors CHECK (requested_by <> approved_by),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    approved_at TIMESTAMPTZ
);

-- 6. Journal des Actions Immuable Chaîné par Empreinte (Section 11.1 & 20.4)
CREATE TABLE immutable_audit_log (
    seq BIGSERIAL PRIMARY KEY,
    actor_id UUID,
    actor_role VARCHAR(64) NOT NULL,
    action_type VARCHAR(80) NOT NULL,
    reason TEXT NOT NULL,
    prev_hash CHAR(64) NOT NULL,
    entry_hash CHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Interdiction stricte de UPDATE ou DELETE sur les commandes, paiements et le journal (Section 3.2 & 11.1)
CREATE OR REPLACE FUNCTION forbid_mutation() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'Modification ou suppression interdite sur la table sécurisée BATIX (%)', TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_immutable_audit_log
BEFORE UPDATE OR DELETE ON immutable_audit_log
FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
