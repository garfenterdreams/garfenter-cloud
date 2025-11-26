-- ============================================
-- Garfenter Cloud - PostgreSQL Database Init
-- Creates all 7 PostgreSQL databases for products
-- ============================================

-- Keycloak SSO
CREATE DATABASE keycloak;
GRANT ALL PRIVILEGES ON DATABASE keycloak TO garfenter;

-- Tienda (Saleor E-commerce)
CREATE DATABASE garfenter_tienda;
GRANT ALL PRIVILEGES ON DATABASE garfenter_tienda TO garfenter;

-- Clientes (Twenty CRM)
CREATE DATABASE garfenter_clientes;
GRANT ALL PRIVILEGES ON DATABASE garfenter_clientes TO garfenter;

-- Contable (Bigcapital Accounting)
CREATE DATABASE garfenter_contable;
GRANT ALL PRIVILEGES ON DATABASE garfenter_contable TO garfenter;

-- ERP (Odoo)
CREATE DATABASE garfenter_erp;
GRANT ALL PRIVILEGES ON DATABASE garfenter_erp TO garfenter;

-- Inmuebles (Condo Real Estate)
CREATE DATABASE garfenter_inmuebles;
GRANT ALL PRIVILEGES ON DATABASE garfenter_inmuebles TO garfenter;

-- Campo (farmOS Agriculture)
CREATE DATABASE garfenter_campo;
GRANT ALL PRIVILEGES ON DATABASE garfenter_campo TO garfenter;

-- Educacion (Canvas LMS)
CREATE DATABASE garfenter_educacion;
GRANT ALL PRIVILEGES ON DATABASE garfenter_educacion TO garfenter;

-- Log completion
\echo 'Garfenter PostgreSQL databases created successfully (8 databases)'
