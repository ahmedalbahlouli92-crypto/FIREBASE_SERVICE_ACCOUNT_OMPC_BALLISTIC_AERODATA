-- ==============================================================================
-- OMPC Ballistic AeroData - Supabase Database Schema Setup
-- Project URL: https://dygzkvhvuxoukbgtjxfa.supabase.co
-- SQL Editor: https://supabase.com/dashboard/project/dygzkvhvuxoukbgtjxfa/sql/new
--
-- This script creates:
-- 1. Master Table: ballistic_records (Consolidated master log)
-- 2. Daily Report Module: 9 Dedicated Test Tables
--    - daily_waterproof_test
--    - daily_extraction_force_test
--    - daily_accuracy_test
--    - daily_epvat_test
--    - daily_function_test
--    - daily_residual_stress_test
--    - daily_terminal_effect_test
--    - daily_firing_rate_cycle_test
--    - daily_primer_sensitivity_test
-- 3. Lot Acceptance Module: 9 Dedicated Test Tables
--    - lot_acceptance_waterproof_test
--    - lot_acceptance_extraction_force_test
--    - lot_acceptance_accuracy_test
--    - lot_acceptance_epvat_test
--    - lot_acceptance_function_test
--    - lot_acceptance_residual_stress_test
--    - lot_acceptance_terminal_effect_test
--    - lot_acceptance_firing_rate_cycle_test
--    - lot_acceptance_primer_sensitivity_test
-- 4. Component Module: 2 Dedicated Test Tables
--    - component_propellant_test
--    - component_primer_sensitivity_test
-- 5. Component Inventory Tables:
--    - component_inventory
--    - component_propellant_inventory
--    - component_primer_inventory
-- 6. Consumables System: Master Inventory, Categories, Usage Logs & 8 Category Tables
--    - consumables_inventory
--    - consumables_categories
--    - consumables_usage_log
--    - consumables_shooting_system
--    - consumables_closed_vessel_and_calibration_unit
--    - consumables_manual_loading_tools
--    - consumables_primer_equipment
--    - consumables_weapon_cleaning_item
--    - consumables_residual_stress_items
--    - consumables_styer_rifle_spare_part
--    - consumables_m16_m4_spare_part
-- 7. Admin Control System:
--    - admin_control
--    - admin_users
--    - admin_suppliers
--    - admin_audit_log
-- 8. Enables Row Level Security (RLS) and grants anonymous/authenticated access.
-- ==============================================================================

-- 1. Ensure master table ballistic_records exists and has latest columns
CREATE TABLE IF NOT EXISTS public.ballistic_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    timestamp TEXT,
    operators TEXT,
    shift TEXT,
    caliber TEXT,
    lot_no TEXT,
    produced INTEGER DEFAULT 0,
    defects INTEGER DEFAULT 0,
    notes TEXT,
    status TEXT,
    test_name TEXT,
    pressure_bar TEXT,
    viscosity TEXT,
    test_time TEXT,
    sampling_location TEXT,
    mouth_slow INTEGER DEFAULT 0,
    mouth_fast INTEGER DEFAULT 0,
    primer_slow INTEGER DEFAULT 0,
    primer_fast INTEGER DEFAULT 0,
    hopper_no TEXT,
    box_no TEXT,
    requirement TEXT,
    barrel_sn TEXT,
    barrel_type TEXT,
    velocity_distance TEXT,
    acc_mean_x TEXT,
    acc_max_x TEXT,
    acc_min_x TEXT,
    acc_range_x TEXT,
    acc_sd_x TEXT,
    acc_mean_y TEXT,
    acc_max_y TEXT,
    acc_min_y TEXT,
    acc_range_y TEXT,
    acc_sd_y TEXT,
    vel_mean TEXT,
    vel_min TEXT,
    vel_max TEXT,
    vel_range TEXT,
    vel_sd TEXT,
    acc_mean_radius TEXT,
    extraction_force_type TEXT,
    extraction_force_rounds TEXT,
    cartridge_temp TEXT,
    epvat_pressure_type TEXT,
    epvat_pressure_unit TEXT,
    epvat_pressure_rounds TEXT,
    epvat_mean_pressure TEXT,
    epvat_max_pressure TEXT,
    epvat_min_pressure TEXT,
    epvat_range_pressure TEXT,
    epvat_sd_pressure TEXT,
    epvat_p2_mean_pressure TEXT,
    epvat_p2_max_pressure TEXT,
    epvat_p2_min_pressure TEXT,
    epvat_p2_range_pressure TEXT,
    epvat_p2_sd_pressure TEXT,
    epvat_p2_pressure_rounds TEXT,
    epvat_vel_rounds TEXT,
    epvat_sensor_1 TEXT,
    epvat_sensor_2 TEXT,
    cyclic_rate_weapon_type TEXT,
    cyclic_rate_ammo_type TEXT,
    cyclic_rate_value TEXT,
    cyclic_rate_min TEXT,
    cyclic_rate_max TEXT,
    terminal_hole_diameter TEXT,
    terminal_steel_penetration TEXT,
    terminal_aluminum_penetration TEXT,
    terminal_velocity TEXT,
    neck_slow INTEGER DEFAULT 0,
    neck_fast INTEGER DEFAULT 0,
    shoulder_slow INTEGER DEFAULT 0,
    shoulder_fast INTEGER DEFAULT 0,
    body_slow INTEGER DEFAULT 0,
    body_fast INTEGER DEFAULT 0,
    head_slow INTEGER DEFAULT 0,
    head_fast INTEGER DEFAULT 0,
    room_temp TEXT,
    function_level1 INTEGER DEFAULT 0,
    function_level2 INTEGER DEFAULT 0,
    function_level3 INTEGER DEFAULT 0,
    function_level4 INTEGER DEFAULT 0,
    attachment_name TEXT,
    attachment_base64 TEXT,
    function_defect_details TEXT,
    action_time_mean TEXT,
    action_time_min TEXT,
    action_time_max TEXT,
    action_time_range TEXT,
    action_time_sd TEXT,
    action_time_rounds TEXT,
    primer_drop_heights TEXT,
    primer_fire_results TEXT,
    primer_hbar TEXT,
    primer_sd TEXT,
    primer_all_fire_h TEXT,
    primer_no_fire_h TEXT,
    gp6_serial TEXT,
    user_role TEXT,
    module TEXT DEFAULT 'Lot Acceptance Test',
    primer_lot TEXT,
    primer_supplier TEXT,
    primer_insertion_depth TEXT,
    propellant_supplier TEXT,
    propellant_code TEXT,
    propellant_lot TEXT,
    propellant_charge TEXT,
    is_retest BOOLEAN DEFAULT false,
    retest_timestamp TEXT,
    retest_operator TEXT,
    retest_notes TEXT,
    retest_status TEXT,
    original_status TEXT,
    retest_produced INTEGER DEFAULT 0,
    retest_defects INTEGER DEFAULT 0,
    retest_metrics TEXT DEFAULT '{}'
);

-- Ensure all newest columns exist on ballistic_records
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS gp6_serial TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS user_role TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS module TEXT DEFAULT 'Lot Acceptance Test';
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS primer_lot TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS primer_supplier TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS primer_insertion_depth TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS propellant_supplier TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS propellant_code TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS propellant_lot TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS propellant_charge TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS is_retest BOOLEAN DEFAULT false;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS retest_timestamp TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS retest_operator TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS retest_notes TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS retest_status TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS original_status TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS retest_produced INTEGER DEFAULT 0;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS retest_defects INTEGER DEFAULT 0;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS retest_metrics TEXT DEFAULT '{}';
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p1_mean_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p1_max_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p1_min_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p1_sd_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p1_mean_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p1_max_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p1_min_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p1_sd_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p1_mean_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p1_max_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p1_min_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p1_sd_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p2_mean_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p2_max_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p2_min_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p2_sd_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p2_mean_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p2_max_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p2_min_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p2_sd_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p2_mean_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p2_max_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p2_min_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS p2_sd_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS vel_mean_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS vel_max_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS vel_min_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS vel_sd_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS vel_mean_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS vel_max_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS vel_min_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS vel_sd_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS vel_mean_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS vel_max_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS vel_min_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS vel_sd_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS action_time_mean_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS action_time_sd_21 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS action_time_mean_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS action_time_sd_52 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS action_time_mean_54 NUMERIC DEFAULT NULL;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS action_time_sd_54 NUMERIC DEFAULT NULL;

-- 2. Create the 20 Dedicated Tables across Daily Report, Lot Acceptance, and Component Test
DO $$
DECLARE
    tbl TEXT;
    tables TEXT[] := ARRAY[
        -- Daily Report Module Tables
        'daily_waterproof_test',
        'daily_extraction_force_test',
        'daily_accuracy_test',
        'daily_epvat_test',
        'daily_function_test',
        'daily_residual_stress_test',
        'daily_terminal_effect_test',
        'daily_firing_rate_cycle_test',
        'daily_primer_sensitivity_test',

        -- Lot Acceptance Test Module Tables
        'lot_acceptance_waterproof_test',
        'lot_acceptance_extraction_force_test',
        'lot_acceptance_accuracy_test',
        'lot_acceptance_epvat_test',
        'lot_acceptance_function_test',
        'lot_acceptance_residual_stress_test',
        'lot_acceptance_terminal_effect_test',
        'lot_acceptance_firing_rate_cycle_test',
        'lot_acceptance_primer_sensitivity_test',

        -- Component Module Tables
        'component_propellant_test',
        'component_primer_sensitivity_test'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables
    LOOP
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS public.%I (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                created_at TIMESTAMPTZ DEFAULT now(),
                timestamp TEXT,
                operators TEXT,
                shift TEXT,
                caliber TEXT,
                lot_no TEXT,
                produced INTEGER DEFAULT 0,
                defects INTEGER DEFAULT 0,
                notes TEXT,
                status TEXT,
                test_name TEXT,
                pressure_bar TEXT,
                viscosity TEXT,
                test_time TEXT,
                sampling_location TEXT,
                mouth_slow INTEGER DEFAULT 0,
                mouth_fast INTEGER DEFAULT 0,
                primer_slow INTEGER DEFAULT 0,
                primer_fast INTEGER DEFAULT 0,
                hopper_no TEXT,
                box_no TEXT,
                requirement TEXT,
                barrel_sn TEXT,
                barrel_type TEXT,
                velocity_distance TEXT,
                acc_mean_x TEXT,
                acc_max_x TEXT,
                acc_min_x TEXT,
                acc_range_x TEXT,
                acc_sd_x TEXT,
                acc_mean_y TEXT,
                acc_max_y TEXT,
                acc_min_y TEXT,
                acc_range_y TEXT,
                acc_sd_y TEXT,
                vel_mean TEXT,
                vel_min TEXT,
                vel_max TEXT,
                vel_range TEXT,
                vel_sd TEXT,
                acc_mean_radius TEXT,
                extraction_force_type TEXT,
                extraction_force_rounds TEXT,
                cartridge_temp TEXT,
                epvat_pressure_type TEXT,
                epvat_pressure_unit TEXT,
                epvat_pressure_rounds TEXT,
                epvat_mean_pressure TEXT,
                epvat_max_pressure TEXT,
                epvat_min_pressure TEXT,
                epvat_range_pressure TEXT,
                epvat_sd_pressure TEXT,
                epvat_p2_mean_pressure TEXT,
                epvat_p2_max_pressure TEXT,
                epvat_p2_min_pressure TEXT,
                epvat_p2_range_pressure TEXT,
                epvat_p2_sd_pressure TEXT,
                epvat_p2_pressure_rounds TEXT,
                epvat_vel_rounds TEXT,
                epvat_sensor_1 TEXT,
                epvat_sensor_2 TEXT,
                cyclic_rate_weapon_type TEXT,
                cyclic_rate_ammo_type TEXT,
                cyclic_rate_value TEXT,
                cyclic_rate_min TEXT,
                cyclic_rate_max TEXT,
                terminal_hole_diameter TEXT,
                terminal_steel_penetration TEXT,
                terminal_aluminum_penetration TEXT,
                terminal_velocity TEXT,
                neck_slow INTEGER DEFAULT 0,
                neck_fast INTEGER DEFAULT 0,
                shoulder_slow INTEGER DEFAULT 0,
                shoulder_fast INTEGER DEFAULT 0,
                body_slow INTEGER DEFAULT 0,
                body_fast INTEGER DEFAULT 0,
                head_slow INTEGER DEFAULT 0,
                head_fast INTEGER DEFAULT 0,
                room_temp TEXT,
                function_level1 INTEGER DEFAULT 0,
                function_level2 INTEGER DEFAULT 0,
                function_level3 INTEGER DEFAULT 0,
                function_level4 INTEGER DEFAULT 0,
                attachment_name TEXT,
                attachment_base64 TEXT,
                function_defect_details TEXT,
                action_time_mean TEXT,
                action_time_min TEXT,
                action_time_max TEXT,
                action_time_range TEXT,
                action_time_sd TEXT,
                action_time_rounds TEXT,
                primer_drop_heights TEXT,
                primer_fire_results TEXT,
                primer_hbar TEXT,
                primer_sd TEXT,
                primer_all_fire_h TEXT,
                primer_no_fire_h TEXT,
                gp6_serial TEXT,
                user_role TEXT,
                module TEXT,
                primer_lot TEXT,
                primer_supplier TEXT,
                primer_insertion_depth TEXT,
                propellant_supplier TEXT,
                propellant_code TEXT,
                propellant_lot TEXT,
                propellant_charge TEXT,
                is_retest BOOLEAN DEFAULT false,
                retest_timestamp TEXT,
                retest_operator TEXT,
                retest_notes TEXT,
                retest_status TEXT,
                original_status TEXT
            );
            
            -- Ensure newest columns exist if table was previously created
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS primer_lot TEXT;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS primer_supplier TEXT;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS primer_insertion_depth TEXT;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS propellant_supplier TEXT;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS propellant_code TEXT;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS propellant_lot TEXT;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS propellant_charge TEXT;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS is_retest BOOLEAN DEFAULT false;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS retest_timestamp TEXT;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS retest_operator TEXT;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS retest_notes TEXT;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS retest_status TEXT;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS original_status TEXT;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS retest_produced INTEGER DEFAULT 0;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS retest_defects INTEGER DEFAULT 0;
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS retest_metrics TEXT DEFAULT '{}';
            ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';

            -- Enable Row Level Security (RLS)
            ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;

            -- Create Open Policy for Web & Desktop Client Access
            DROP POLICY IF EXISTS "Public access policy" ON public.%I;
            CREATE POLICY "Public access policy" ON public.%I
                FOR ALL
                USING (true)
                WITH CHECK (true);

            -- Grant database privileges
            GRANT ALL ON TABLE public.%I TO anon, authenticated, service_role;

            -- High performance indexes
            CREATE INDEX IF NOT EXISTS %I ON public.%I (lot_no);
            CREATE INDEX IF NOT EXISTS %I ON public.%I (caliber);
            CREATE INDEX IF NOT EXISTS %I ON public.%I (created_at DESC);
        ', 
        tbl,
        tbl, tbl, tbl, tbl, tbl, tbl, tbl,
        tbl, tbl, tbl, tbl,
        'idx_' || tbl || '_lot_no', tbl,
        'idx_' || tbl || '_caliber', tbl,
        'idx_' || tbl || '_created_at', tbl
        );
    END LOOP;
END $$;

-- 3. Master Consumables & Component Inventory Tables
CREATE TABLE IF NOT EXISTS public.consumables_inventory (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    name TEXT NOT NULL,
    serial TEXT DEFAULT '',
    category TEXT NOT NULL,
    quantity NUMERIC DEFAULT 0,
    unit TEXT DEFAULT 'pcs',
    min_safe_threshold NUMERIC DEFAULT 0,
    supplier TEXT DEFAULT '',
    location TEXT DEFAULT '',
    image_base64 TEXT DEFAULT '',
    notes TEXT DEFAULT ''
);
ALTER TABLE public.consumables_inventory ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.consumables_inventory;
CREATE POLICY "Public access policy" ON public.consumables_inventory FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.consumables_inventory TO anon, authenticated, service_role;
CREATE INDEX IF NOT EXISTS idx_consumables_category ON public.consumables_inventory (category);
CREATE INDEX IF NOT EXISTS idx_consumables_serial ON public.consumables_inventory (serial);

-- Consumables Categories Registry
CREATE TABLE IF NOT EXISTS public.consumables_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    name TEXT UNIQUE NOT NULL
);
ALTER TABLE public.consumables_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.consumables_categories;
CREATE POLICY "Public access policy" ON public.consumables_categories FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.consumables_categories TO anon, authenticated, service_role;

-- Consumables Usage Transaction Log
CREATE TABLE IF NOT EXISTS public.consumables_usage_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    item_id TEXT NOT NULL,
    item_name TEXT NOT NULL,
    quantity_used NUMERIC NOT NULL,
    user_name TEXT DEFAULT '',
    reason TEXT DEFAULT '',
    timestamp TEXT NOT NULL
);
ALTER TABLE public.consumables_usage_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.consumables_usage_log;
CREATE POLICY "Public access policy" ON public.consumables_usage_log FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.consumables_usage_log TO anon, authenticated, service_role;

-- Dedicated Tables for Each of the 8 Consumable Categories
DO $$
DECLARE
    cat_tbl TEXT;
    cat_tables TEXT[] := ARRAY[
        'consumables_shooting_system',
        'consumables_closed_vessel_and_calibration_unit',
        'consumables_manual_loading_tools',
        'consumables_primer_equipment',
        'consumables_weapon_cleaning_item',
        'consumables_residual_stress_items',
        'consumables_styer_rifle_spare_part',
        'consumables_m16_m4_spare_part'
    ];
BEGIN
    FOREACH cat_tbl IN ARRAY cat_tables
    LOOP
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS public.%I (
                id TEXT PRIMARY KEY,
                created_at TIMESTAMPTZ DEFAULT now(),
                updated_at TIMESTAMPTZ DEFAULT now(),
                name TEXT NOT NULL,
                serial TEXT DEFAULT '''',
                category TEXT NOT NULL,
                quantity NUMERIC DEFAULT 0,
                unit TEXT DEFAULT ''pcs'',
                min_safe_threshold NUMERIC DEFAULT 0,
                supplier TEXT DEFAULT '''',
                location TEXT DEFAULT '''',
                image_base64 TEXT DEFAULT '''',
                notes TEXT DEFAULT ''''
            );
            ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;
            DROP POLICY IF EXISTS "Public access policy" ON public.%I;
            CREATE POLICY "Public access policy" ON public.%I FOR ALL USING (true) WITH CHECK (true);
            GRANT ALL ON TABLE public.%I TO anon, authenticated, service_role;
            CREATE INDEX IF NOT EXISTS %I ON public.%I (serial);
        ',
        cat_tbl, cat_tbl, cat_tbl, cat_tbl, cat_tbl,
        'idx_' || cat_tbl || '_serial', cat_tbl
        );
    END LOOP;
END $$;

-- 4. Component Inventory Tables
CREATE TABLE IF NOT EXISTS public.component_inventory (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    component_type TEXT NOT NULL, -- e.g. "Propellant", "Primer", "Bullet", "Case"
    lot_number TEXT NOT NULL,
    supplier TEXT DEFAULT '',
    quantity NUMERIC DEFAULT 0,
    unit TEXT DEFAULT 'pcs',
    powder_code TEXT DEFAULT '',
    insertion_depth TEXT DEFAULT '',
    notes TEXT DEFAULT ''
);
ALTER TABLE public.component_inventory ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.component_inventory;
CREATE POLICY "Public access policy" ON public.component_inventory FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.component_inventory TO anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.component_propellant_inventory (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT now(),
    lot_number TEXT NOT NULL,
    supplier TEXT NOT NULL,
    powder_code TEXT NOT NULL,
    powder_charge_gram NUMERIC DEFAULT 0,
    quantity_kg NUMERIC DEFAULT 0,
    notes TEXT DEFAULT ''
);
ALTER TABLE public.component_propellant_inventory ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.component_propellant_inventory;
CREATE POLICY "Public access policy" ON public.component_propellant_inventory FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.component_propellant_inventory TO anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.component_primer_inventory (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT now(),
    lot_number TEXT NOT NULL,
    supplier TEXT NOT NULL,
    insertion_depth_mm NUMERIC DEFAULT 0,
    quantity_pcs NUMERIC DEFAULT 0,
    notes TEXT DEFAULT ''
);
ALTER TABLE public.component_primer_inventory ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.component_primer_inventory;
CREATE POLICY "Public access policy" ON public.component_primer_inventory FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.component_primer_inventory TO anon, authenticated, service_role;

-- 5. Admin Control System
CREATE TABLE IF NOT EXISTS public.admin_control (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    config_key TEXT UNIQUE NOT NULL,
    config_value JSONB NOT NULL,
    updated_by TEXT DEFAULT 'admin'
);
ALTER TABLE public.admin_control ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_control;
CREATE POLICY "Public access policy" ON public.admin_control FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_control TO anon, authenticated, service_role;
CREATE INDEX IF NOT EXISTS idx_admin_control_key ON public.admin_control (config_key);

CREATE TABLE IF NOT EXISTS public.admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT DEFAULT 'admin',
    name TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT true
);
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_users;
CREATE POLICY "Public access policy" ON public.admin_users FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_users TO anon, authenticated, service_role;

-- Seed default laboratory personnel and admin accounts
INSERT INTO public.admin_users (username, password_hash, role, name, is_active)
VALUES
    ('admin', 'admin123', 'admin', 'System Administrator', true),
    ('manager', 'manager123', 'manager', 'Quality Manager', true),
    ('supervisor', 'supervisor123', 'supervisor', 'Shift Supervisor', true),
    ('technician', 'technician123', 'technician', 'Ballistics Technician', true),
    ('operator', 'operator123', 'operator', 'Ahmed Said', true)
ON CONFLICT (username) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role,
    name = EXCLUDED.name,
    is_active = true;

CREATE TABLE IF NOT EXISTS public.admin_suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    type TEXT NOT NULL, -- 'propellant' or 'primer'
    supplier_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true
);
ALTER TABLE public.admin_suppliers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_suppliers;
CREATE POLICY "Public access policy" ON public.admin_suppliers FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_suppliers TO anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.admin_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    action TEXT NOT NULL,
    performed_by TEXT NOT NULL,
    details JSONB DEFAULT '{}'::jsonb
);
ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_audit_log;
CREATE POLICY "Public access policy" ON public.admin_audit_log FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_audit_log TO anon, authenticated, service_role;

-- Dedicated Tables for Each Admin Control Input

-- 1. Weapons Fleet Input Table
CREATE TABLE IF NOT EXISTS public.admin_weapons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    category TEXT NOT NULL DEFAULT 'Rifle', -- 'Rifle', 'Machine Gun', 'Pistol'
    model TEXT NOT NULL,
    serial_number TEXT DEFAULT '',
    manufacturer TEXT DEFAULT '',
    round_count INTEGER DEFAULT 0,
    max_rounds INTEGER DEFAULT 5000,
    is_active BOOLEAN DEFAULT true
);
ALTER TABLE public.admin_weapons ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_weapons;
CREATE POLICY "Public access policy" ON public.admin_weapons FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_weapons TO anon, authenticated, service_role;

-- 2. EPVAT Barrels Input Table (by Caliber)
CREATE TABLE IF NOT EXISTS public.admin_epvat_barrels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    serial_number TEXT NOT NULL,
    caliber TEXT NOT NULL,
    round_count INTEGER DEFAULT 0,
    max_rounds INTEGER DEFAULT 2500,
    is_active BOOLEAN DEFAULT true,
    CONSTRAINT unq_admin_epvat_barrel UNIQUE (serial_number, caliber)
);
ALTER TABLE public.admin_epvat_barrels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_epvat_barrels;
CREATE POLICY "Public access policy" ON public.admin_epvat_barrels FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_epvat_barrels TO anon, authenticated, service_role;

-- 3. Accuracy Barrels Input Table (by Caliber)
CREATE TABLE IF NOT EXISTS public.admin_accuracy_barrels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    serial_number TEXT NOT NULL,
    caliber TEXT NOT NULL,
    round_count INTEGER DEFAULT 0,
    max_rounds INTEGER DEFAULT 3000,
    is_active BOOLEAN DEFAULT true,
    CONSTRAINT unq_admin_accuracy_barrel UNIQUE (serial_number, caliber)
);
ALTER TABLE public.admin_accuracy_barrels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_accuracy_barrels;
CREATE POLICY "Public access policy" ON public.admin_accuracy_barrels FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_accuracy_barrels TO anon, authenticated, service_role;

-- 4. GP1 Chamber Transducers Input Table
CREATE TABLE IF NOT EXISTS public.admin_gp1_transducers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    serial_number TEXT UNIQUE NOT NULL,
    brand TEXT DEFAULT 'PCB Piezotronics',
    calibration_date TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT true
);
ALTER TABLE public.admin_gp1_transducers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_gp1_transducers;
CREATE POLICY "Public access policy" ON public.admin_gp1_transducers FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_gp1_transducers TO anon, authenticated, service_role;

-- 5. GP6 Port Transducers Input Table
CREATE TABLE IF NOT EXISTS public.admin_gp6_transducers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    serial_number TEXT UNIQUE NOT NULL,
    brand TEXT DEFAULT 'PCB Piezotronics',
    calibration_date TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT true
);
ALTER TABLE public.admin_gp6_transducers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_gp6_transducers;
CREATE POLICY "Public access policy" ON public.admin_gp6_transducers FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_gp6_transducers TO anon, authenticated, service_role;

-- 6. Propellant Suppliers Input Table
CREATE TABLE IF NOT EXISTS public.admin_propellant_suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    name TEXT UNIQUE NOT NULL,
    country TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT true
);
ALTER TABLE public.admin_propellant_suppliers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_propellant_suppliers;
CREATE POLICY "Public access policy" ON public.admin_propellant_suppliers FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_propellant_suppliers TO anon, authenticated, service_role;

-- 7. Primer Suppliers Input Table
CREATE TABLE IF NOT EXISTS public.admin_primer_suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    name TEXT UNIQUE NOT NULL,
    country TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT true
);
ALTER TABLE public.admin_primer_suppliers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_primer_suppliers;
CREATE POLICY "Public access policy" ON public.admin_primer_suppliers FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_primer_suppliers TO anon, authenticated, service_role;

-- 8. Propellant Codes Input Table
CREATE TABLE IF NOT EXISTS public.admin_propellant_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    code TEXT NOT NULL,
    supplier TEXT NOT NULL,
    caliber TEXT DEFAULT '',
    charge_weight_grains NUMERIC DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    CONSTRAINT unq_admin_propellant_code UNIQUE (code, supplier)
);
ALTER TABLE public.admin_propellant_codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_propellant_codes;
CREATE POLICY "Public access policy" ON public.admin_propellant_codes FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_propellant_codes TO anon, authenticated, service_role;

-- 9. Function Test Defect Levels Input Table
CREATE TABLE IF NOT EXISTS public.admin_function_levels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    caliber TEXT NOT NULL,
    level_number INTEGER NOT NULL, -- 1, 2, 3, 4
    level_name TEXT NOT NULL,
    max_allowed INTEGER DEFAULT 0,
    description TEXT DEFAULT '',
    CONSTRAINT unq_admin_function_level UNIQUE (caliber, level_number)
);
ALTER TABLE public.admin_function_levels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_function_levels;
CREATE POLICY "Public access policy" ON public.admin_function_levels FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_function_levels TO anon, authenticated, service_role;

-- 10. Sampling Inspection Locations Input Table
CREATE TABLE IF NOT EXISTS public.admin_sampling_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    location_name TEXT UNIQUE NOT NULL,
    default_for_module TEXT DEFAULT '',
    default_for_test TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT true
);
ALTER TABLE public.admin_sampling_locations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_sampling_locations;
CREATE POLICY "Public access policy" ON public.admin_sampling_locations FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_sampling_locations TO anon, authenticated, service_role;

-- 11. Role Permissions Input Table
CREATE TABLE IF NOT EXISTS public.admin_role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    role TEXT NOT NULL,
    permission_key TEXT NOT NULL,
    permission_title TEXT NOT NULL,
    is_enabled BOOLEAN DEFAULT true,
    CONSTRAINT unq_admin_role_perm UNIQUE (role, permission_key)
);
ALTER TABLE public.admin_role_permissions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_role_permissions;
CREATE POLICY "Public access policy" ON public.admin_role_permissions FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_role_permissions TO anon, authenticated, service_role;

-- 12. Test Rules & Tolerances Input Table
CREATE TABLE IF NOT EXISTS public.admin_test_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    caliber TEXT NOT NULL,
    test_name TEXT NOT NULL,
    rules_data JSONB NOT NULL,
    updated_by TEXT DEFAULT 'admin',
    CONSTRAINT unq_admin_test_rule UNIQUE (caliber, test_name)
);
ALTER TABLE public.admin_test_rules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_test_rules;
CREATE POLICY "Public access policy" ON public.admin_test_rules FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_test_rules TO anon, authenticated, service_role;

-- 6. Master Table Permissions & Default Indexes
ALTER TABLE public.ballistic_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.ballistic_records;
CREATE POLICY "Public access policy" ON public.ballistic_records FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.ballistic_records TO anon, authenticated, service_role;
CREATE INDEX IF NOT EXISTS idx_ballistic_records_lot_no ON public.ballistic_records (lot_no);
CREATE INDEX IF NOT EXISTS idx_ballistic_records_created_at ON public.ballistic_records (created_at DESC);

-- 13. Witness Storage Lots Table
CREATE TABLE IF NOT EXISTS public.witness_storage_lots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    lot_no TEXT UNIQUE NOT NULL,
    caliber TEXT NOT NULL,
    initial_qty INTEGER NOT NULL DEFAULT 0,
    consumed_qty INTEGER NOT NULL DEFAULT 0,
    remaining_qty INTEGER NOT NULL DEFAULT 0,
    powder_lot TEXT DEFAULT '',
    powder_supplier TEXT DEFAULT '',
    powder_type TEXT DEFAULT '',
    charge_weight TEXT DEFAULT '',
    primer_lot TEXT DEFAULT '',
    primer_supplier TEXT DEFAULT '',
    primer_type TEXT DEFAULT '',
    storage_location TEXT DEFAULT '',
    registered_by TEXT DEFAULT '',
    registered_at TIMESTAMPTZ DEFAULT now(),
    notes TEXT DEFAULT '',
    status TEXT DEFAULT 'ACTIVE'
);
ALTER TABLE public.witness_storage_lots ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.witness_storage_lots;
CREATE POLICY "Public access policy" ON public.witness_storage_lots FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.witness_storage_lots TO anon, authenticated, service_role;
CREATE INDEX IF NOT EXISTS idx_witness_lots_lot_no ON public.witness_storage_lots (lot_no);
CREATE INDEX IF NOT EXISTS idx_witness_lots_caliber ON public.witness_storage_lots (caliber);

-- 14. Witness Storage Consumptions Audit Trail Table
CREATE TABLE IF NOT EXISTS public.witness_storage_consumptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    lot_id TEXT NOT NULL,
    lot_no TEXT NOT NULL,
    caliber TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    purpose TEXT NOT NULL,
    order_ref TEXT DEFAULT '',
    consumed_by TEXT NOT NULL,
    consumed_at TIMESTAMPTZ DEFAULT now(),
    remaining_after INTEGER NOT NULL,
    notes TEXT DEFAULT ''
);
ALTER TABLE public.witness_storage_consumptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.witness_storage_consumptions;
CREATE POLICY "Public access policy" ON public.witness_storage_consumptions FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.witness_storage_consumptions TO anon, authenticated, service_role;
CREATE INDEX IF NOT EXISTS idx_witness_consumptions_lot_no ON public.witness_storage_consumptions (lot_no);
CREATE INDEX IF NOT EXISTS idx_witness_consumptions_lot_id ON public.witness_storage_consumptions (lot_id);

-- Migration: Ensure reference_no exists on all test tables
ALTER TABLE IF EXISTS public.ballistic_records ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.lot_acceptance_waterproof_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.lot_acceptance_extraction_force_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.lot_acceptance_accuracy_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.lot_acceptance_epvat_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.lot_acceptance_function_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.lot_acceptance_residual_stress_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.lot_acceptance_terminal_effect_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.lot_acceptance_firing_rate_cycle_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.lot_acceptance_primer_sensitivity_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.daily_waterproof_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.daily_extraction_force_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.daily_accuracy_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.daily_epvat_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.daily_function_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.daily_residual_stress_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.daily_terminal_effect_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.daily_firing_rate_cycle_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.daily_primer_sensitivity_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.component_propellant_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.component_primer_sensitivity_test ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '';

-- 15. Equipment Issues & Maintenance Log Table
CREATE TABLE IF NOT EXISTS public.equipment_issues (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT now(),
    timestamp TEXT DEFAULT '',
    date TEXT DEFAULT '',
    equipment TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    severity TEXT DEFAULT 'Minor',
    status TEXT DEFAULT 'Open',
    reporter TEXT DEFAULT '',
    action_taken TEXT DEFAULT '',
    resolved_at TIMESTAMPTZ
);
ALTER TABLE public.equipment_issues ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.equipment_issues;
CREATE POLICY "Public access policy" ON public.equipment_issues FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.equipment_issues TO anon, authenticated, service_role;
CREATE INDEX IF NOT EXISTS idx_equipment_issues_equipment ON public.equipment_issues (equipment);
CREATE INDEX IF NOT EXISTS idx_equipment_issues_status ON public.equipment_issues (status);

-- 16. EPVAT Dedicated Multi-Temperature & Parameter Columns Migration
DO $$
DECLARE
    epv_tbl TEXT;
    epv_tables TEXT[] := ARRAY[
        'daily_epvat_test',
        'lot_acceptance_epvat_test'
    ];
BEGIN
    FOREACH epv_tbl IN ARRAY epv_tables
    LOOP
        -- Chamber P1 (+21 °C, +52 °C, -54 °C)
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p1_mean_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p1_max_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p1_min_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p1_sd_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p1_mean_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p1_max_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p1_min_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p1_sd_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p1_mean_54 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p1_max_54 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p1_min_54 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p1_sd_54 NUMERIC DEFAULT NULL;', epv_tbl);

        -- Port P2 (+21 °C, +52 °C, -54 °C)
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p2_mean_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p2_max_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p2_min_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p2_sd_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p2_mean_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p2_max_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p2_min_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p2_sd_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p2_mean_54 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p2_max_54 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p2_min_54 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS p2_sd_54 NUMERIC DEFAULT NULL;', epv_tbl);

        -- Velocity (+21 °C, +52 °C, -54 °C)
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS vel_mean_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS vel_max_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS vel_min_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS vel_sd_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS vel_mean_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS vel_max_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS vel_min_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS vel_sd_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS vel_mean_54 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS vel_max_54 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS vel_min_54 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS vel_sd_54 NUMERIC DEFAULT NULL;', epv_tbl);

        -- Action Time (+21 °C, +52 °C, -54 °C)
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS action_time_mean_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS action_time_sd_21 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS action_time_mean_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS action_time_sd_52 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS action_time_mean_54 NUMERIC DEFAULT NULL;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS action_time_sd_54 NUMERIC DEFAULT NULL;', epv_tbl);

        -- Retest, reference number & audit columns
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS reference_no TEXT DEFAULT '''';', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS is_retest BOOLEAN DEFAULT false;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS retest_timestamp TEXT DEFAULT '''';', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS retest_operator TEXT DEFAULT '''';', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS retest_notes TEXT DEFAULT '''';', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS retest_status TEXT DEFAULT '''';', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS original_status TEXT DEFAULT '''';', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS retest_produced INTEGER DEFAULT 0;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS retest_defects INTEGER DEFAULT 0;', epv_tbl);
        EXECUTE format('ALTER TABLE IF EXISTS public.%I ADD COLUMN IF NOT EXISTS retest_metrics TEXT DEFAULT ''{}'';', epv_tbl);
    END LOOP;
END $$;

-- 17. Consumables Category Tables (8 specific category tables)
DO $$
DECLARE
    tbl_name TEXT;
    inv_tables TEXT[] := ARRAY[
        'inventory_primers',
        'inventory_propellants',
        'inventory_cases',
        'inventory_bullets',
        'inventory_packaging',
        'inventory_chemical',
        'inventory_tooling',
        'inventory_calibration'
    ];
BEGIN
    FOREACH tbl_name IN ARRAY inv_tables
    LOOP
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS public.%I (
                id TEXT PRIMARY KEY,
                created_at TIMESTAMPTZ DEFAULT now(),
                updated_at TIMESTAMPTZ DEFAULT now(),
                name TEXT NOT NULL DEFAULT '''',
                lot_number TEXT DEFAULT '''',
                serial TEXT DEFAULT '''',
                category TEXT DEFAULT '''',
                quantity NUMERIC DEFAULT 0,
                unit TEXT DEFAULT ''pcs'',
                min_safe_threshold NUMERIC DEFAULT 0,
                supplier TEXT DEFAULT '''',
                location TEXT DEFAULT '''',
                image_base64 TEXT DEFAULT '''',
                notes TEXT DEFAULT ''''
            );
            ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;
            DROP POLICY IF EXISTS "Public access policy" ON public.%I;
            CREATE POLICY "Public access policy" ON public.%I FOR ALL USING (true) WITH CHECK (true);
            GRANT ALL ON TABLE public.%I TO anon, authenticated, service_role;
            CREATE INDEX IF NOT EXISTS %I ON public.%I (serial);
            CREATE INDEX IF NOT EXISTS %I ON public.%I (lot_number);
        ',
        tbl_name, tbl_name, tbl_name, tbl_name, tbl_name,
        'idx_' || tbl_name || '_serial', tbl_name,
        'idx_' || tbl_name || '_lot', tbl_name
        );
    END LOOP;
END $$;

-- 18. Witness Storage System Tables
CREATE TABLE IF NOT EXISTS public.witness_samples (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    sample_id TEXT DEFAULT '',
    lot_no TEXT NOT NULL,
    caliber TEXT NOT NULL,
    quantity INTEGER DEFAULT 0,
    storage_location TEXT DEFAULT '',
    status TEXT DEFAULT 'Stored',
    notes TEXT DEFAULT '',
    registered_by TEXT DEFAULT '',
    registered_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.witness_samples ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.witness_samples;
CREATE POLICY "Public access policy" ON public.witness_samples FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.witness_samples TO anon, authenticated, service_role;
CREATE INDEX IF NOT EXISTS idx_witness_samples_lot ON public.witness_samples (lot_no);

CREATE TABLE IF NOT EXISTS public.witness_dispositions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    sample_id TEXT DEFAULT '',
    lot_no TEXT NOT NULL,
    disposition_type TEXT DEFAULT '',
    quantity INTEGER DEFAULT 0,
    reason TEXT DEFAULT '',
    authorized_by TEXT DEFAULT '',
    disposed_at TIMESTAMPTZ DEFAULT now(),
    notes TEXT DEFAULT ''
);
ALTER TABLE public.witness_dispositions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.witness_dispositions;
CREATE POLICY "Public access policy" ON public.witness_dispositions FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.witness_dispositions TO anon, authenticated, service_role;
CREATE INDEX IF NOT EXISTS idx_witness_dispositions_lot ON public.witness_dispositions (lot_no);

-- 19. Admin Control Master Tables
CREATE TABLE IF NOT EXISTS public.admin_calibers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    name TEXT UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT true
);
ALTER TABLE public.admin_calibers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_calibers;
CREATE POLICY "Public access policy" ON public.admin_calibers FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_calibers TO anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.admin_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    name TEXT UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT true
);
ALTER TABLE public.admin_shifts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_shifts;
CREATE POLICY "Public access policy" ON public.admin_shifts FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_shifts TO anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.admin_operators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    name TEXT UNIQUE NOT NULL,
    role TEXT DEFAULT 'Operator',
    is_active BOOLEAN DEFAULT true
);
ALTER TABLE public.admin_operators ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.admin_operators;
CREATE POLICY "Public access policy" ON public.admin_operators FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.admin_operators TO anon, authenticated, service_role;

-- Confirmation output

-- ==============================================================================
-- 9. Component Module Test Catalog
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.component_tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    test_name TEXT NOT NULL,
    caliber TEXT NOT NULL,
    description TEXT DEFAULT '',
    standard_reference TEXT DEFAULT 'NATO / MIL-STD',
    sample_size INTEGER DEFAULT 50,
    CONSTRAINT unique_component_test_caliber UNIQUE (test_name, caliber)
);
ALTER TABLE public.component_tests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.component_tests;
CREATE POLICY "Public access policy" ON public.component_tests FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.component_tests TO anon, authenticated, service_role;

-- Seed component tests table for calibers: 5.56, 7.62, 9mm
INSERT INTO public.component_tests (test_name, caliber, description, standard_reference, sample_size)
VALUES
    ('Primer Sensitivity Test', '5.56', 'Run-down primer sensitivity H-bar test for 5.56mm ammunition', 'NATO AC/225 D/14', 50),
    ('Primer Sensitivity Test', '7.62', 'Run-down primer sensitivity H-bar test for 7.62mm ammunition', 'NATO AC/225 D/14', 50),
    ('Primer Sensitivity Test', '9mm',  'Run-down primer sensitivity H-bar test for 9mm Luger ammunition', 'NATO AC/225 D/14', 50),
    ('Propellant Test', '5.56', 'Propellant charge lot qualification, visual & closed vessel analysis for 5.56mm', 'MIL-STD-286C', 20),
    ('Propellant Test', '7.62', 'Propellant charge lot qualification, visual & closed vessel analysis for 7.62mm', 'MIL-STD-286C', 20),
    ('Propellant Test', '9mm',  'Propellant charge lot qualification, visual & closed vessel analysis for 9mm', 'MIL-STD-286C', 20)
ON CONFLICT (test_name, caliber) DO UPDATE
SET description = EXCLUDED.description,
    standard_reference = EXCLUDED.standard_reference,
    sample_size = EXCLUDED.sample_size;

SELECT 'Successfully created all 21 test tables, 8 consumable category tables, component inventory, component tests catalog, witness storage tables, equipment issues, and admin control tables.' as result;


