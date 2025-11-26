-- ============================================
-- Garfenter Cloud - MySQL Database Init
-- Creates all 4 MySQL databases for products
-- ============================================

-- Create garfenter user if not exists
CREATE USER IF NOT EXISTS 'garfenter'@'%' IDENTIFIED BY 'garfenter2024';

-- Mercado (Spurt Commerce Marketplace)
CREATE DATABASE IF NOT EXISTS garfenter_mercado CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON garfenter_mercado.* TO 'garfenter'@'%';

-- POS (OpenSourcePOS)
CREATE DATABASE IF NOT EXISTS garfenter_pos CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON garfenter_pos.* TO 'garfenter'@'%';

-- Banco (Apache Fineract Banking)
CREATE DATABASE IF NOT EXISTS garfenter_banco CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON garfenter_banco.* TO 'garfenter'@'%';

-- Salud (HMIS Healthcare)
CREATE DATABASE IF NOT EXISTS garfenter_salud CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON garfenter_salud.* TO 'garfenter'@'%';

-- Apply privileges
FLUSH PRIVILEGES;

-- Log completion
SELECT 'Garfenter MySQL databases created successfully (4 databases)' AS status;
