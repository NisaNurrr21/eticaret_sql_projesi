-- Analitik katman için ayrı bir şema oluşturalım ki OLTP ile karışmasın
CREATE SCHEMA IF NOT EXISTS dwh;

-- 1. DIM_DATE (Tarih Boyutu)
-- Grain: Bu tablodaki her bir satır, takvimdeki 1 tek günü temsil eder.
CREATE TABLE IF NOT EXISTS dwh.dim_date (
    date_id INT PRIMARY KEY,           -- Örn: 20260911
    full_date DATE NOT NULL,           -- Örn: '2026-09-11'
    day_of_week INT,                   -- 1 (Pazartesi) - 7 (Pazar)
    day_name VARCHAR(10),              -- Monday, Tuesday...
    month INT,
    month_name VARCHAR(10),
    quarter INT,
    year INT,
    is_weekend BOOLEAN
);

-- 2. DIM_PRODUCT (Ürün Boyutu)
-- Grain: Bu tablodaki her bir satır, e-ticaret sistemimizdeki tek 1 ürünü temsil eder.
CREATE TABLE IF NOT EXISTS dwh.dim_product (
    product_sk SERIAL PRIMARY KEY,     -- Surrogate Key (Analitik DB'ye özel ID)
    product_id INT NOT NULL,           -- OLTP'deki gerçek ID
    category_name VARCHAR(100),
    product_name VARCHAR(255),
    current_price DECIMAL(10,2)
);

-- 3. DIM_CUSTOMER (Müşteri Boyutu - SCD2 Uyumlu!)
-- Grain: Bu tablodaki her bir satır, bir müşterinin BELİRLİ BİR ZAMAN ARALIĞINDAKİ profil durumunu temsil eder.
CREATE TABLE IF NOT EXISTS dwh.dim_customer (
    customer_sk SERIAL PRIMARY KEY,    -- Surrogate Key (SCD2 için şart!)
    user_id INT NOT NULL,              -- OLTP'deki gerçek ID
    full_name VARCHAR(255),
    email VARCHAR(255),
    gender VARCHAR(10),
    city VARCHAR(100),
    -- SCD2 Kolonları
    valid_from TIMESTAMP NOT NULL,
    valid_to TIMESTAMP,
    is_current BOOLEAN NOT NULL DEFAULT TRUE
);

-- 4. FCT_ORDERS (Siparişler Gerçek Tablosu)
-- Grain: Bu tablodaki her bir satır, tamamlanmış 1 tek siparişi (faturayı) temsil eder.
CREATE TABLE IF NOT EXISTS dwh.fct_orders (
    order_id INT PRIMARY KEY,
    customer_sk INT REFERENCES dwh.dim_customer(customer_sk),
    date_id INT REFERENCES dwh.dim_date(date_id),
    status VARCHAR(50),
    total_amount DECIMAL(10,2),
    shipping_cost DECIMAL(10,2)
);

-- 5. FCT_ORDER_ITEMS (Sipariş Detayları Gerçek Tablosu)
-- Grain: Bu tablodaki her bir satır, bir siparişin içindeki 1 tek ürün kalemini (satırını) temsil eder.
CREATE TABLE IF NOT EXISTS dwh.fct_order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT REFERENCES dwh.fct_orders(order_id),
    product_sk INT REFERENCES dwh.dim_product(product_sk),
    date_id INT REFERENCES dwh.dim_date(date_id),
    quantity INT,
    unit_price DECIMAL(10,2),
    line_total DECIMAL(10,2)
);