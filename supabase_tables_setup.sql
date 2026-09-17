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
-- 4. Enables Row Level Security (RLS) and grants anonymous/authenticated access.
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
    module TEXT DEFAULT 'Lot Acceptance Test'
);

-- Ensure latest columns exist if ballistic_records was created previously
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS gp6_serial TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS user_role TEXT;
ALTER TABLE public.ballistic_records ADD COLUMN IF NOT EXISTS module TEXT DEFAULT 'Lot Acceptance Test';

-- 2. Create the 18 Dedicated Tables across Daily Report and Lot Acceptance
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
        'lot_acceptance_primer_sensitivity_test'
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
                module TEXT
            );
            
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
        tbl, tbl, tbl, tbl, tbl,
        'idx_' || tbl || '_lot_no', tbl,
        'idx_' || tbl || '_caliber', tbl,
        'idx_' || tbl || '_created_at', tbl
        );
    END LOOP;
END $$;

-- 3. Set RLS and Permissions on the master ballistic_records table as well
ALTER TABLE public.ballistic_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access policy" ON public.ballistic_records;
CREATE POLICY "Public access policy" ON public.ballistic_records
    FOR ALL
    USING (true)
    WITH CHECK (true);
GRANT ALL ON TABLE public.ballistic_records TO anon, authenticated, service_role;
CREATE INDEX IF NOT EXISTS idx_ballistic_records_lot_no ON public.ballistic_records (lot_no);
CREATE INDEX IF NOT EXISTS idx_ballistic_records_created_at ON public.ballistic_records (created_at DESC);

-- Output confirmation
SELECT 'Successfully created all 18 test tables and configured RLS permissions for Daily Report and Lot Acceptance Test modules.' as result;
