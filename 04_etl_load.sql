-- 1. IDEMPOTENT GARANTİSİ: Script her çalıştığında tabloyu temizler ve baştan doldurur.
TRUNCATE TABLE dwh.fct_order_items, dwh.fct_orders, dwh.dim_customer, dwh.dim_product, dwh.dim_date RESTART IDENTITY CASCADE;

-- 2. DIM_DATE (Tarih Boyutu) DOLDURMA
INSERT INTO dwh.dim_date (date_id, full_date, day_of_week, day_name, month, month_name, quarter, year, is_weekend)
SELECT DISTINCT
    TO_CHAR(created_at, 'YYYYMMDD')::INT AS date_id,
    created_at::DATE AS full_date,
    EXTRACT(ISODOW FROM created_at) AS day_of_week,
    TO_CHAR(created_at, 'Day') AS day_name,
    EXTRACT(MONTH FROM created_at) AS month,
    TO_CHAR(created_at, 'Month') AS month_name,
    EXTRACT(QUARTER FROM created_at) AS quarter,
    EXTRACT(YEAR FROM created_at) AS year,
    CASE WHEN EXTRACT(ISODOW FROM created_at) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend
FROM public.orders;

-- 3. DIM_PRODUCT (Ürün Boyutu) DOLDURMA
INSERT INTO dwh.dim_product (product_id, category_name, product_name, current_price)
SELECT 
    p.id,
    c.name,
    p.name,
    p.price
FROM public.products p
JOIN public.categories c ON p.category_id = c.id;

-- 4. DIM_CUSTOMER (Müşteri Boyutu - SCD2 Başlangıç Durumu) DOLDURMA
INSERT INTO dwh.dim_customer (user_id, full_name, email, gender, city, valid_from, valid_to, is_current)
SELECT 
    id,
    SPLIT_PART(email, '@', 1), -- E-postanın '@' işaretinden önceki kısmını geçici isim olarak aldık
    email,
    'Unknown', -- Cinsiyet verisi olmadığı için
    'Unknown', -- Şehir verisi olmadığı için
    '1900-01-01'::TIMESTAMP, 
    NULL,
    TRUE
FROM public.users;

-- 5. FCT_ORDERS (Siparişler Gerçek Tablosu) DOLDURMA
INSERT INTO dwh.fct_orders (order_id, customer_sk, date_id, status, total_amount, shipping_cost)
SELECT 
    o.id,
    dc.customer_sk,
    TO_CHAR(o.created_at, 'YYYYMMDD')::INT,
    o.status,
    o.total_amount,
    0 
FROM public.orders o
JOIN dwh.dim_customer dc ON o.user_id = dc.user_id AND dc.is_current = TRUE;

-- 6. FCT_ORDER_ITEMS (Sipariş Detayları) DOLDURMA
INSERT INTO dwh.fct_order_items (order_item_id, order_id, product_sk, date_id, quantity, unit_price, line_total)
SELECT 
    oi.id,
    oi.order_id,
    dp.product_sk,
    TO_CHAR(o.created_at, 'YYYYMMDD')::INT,
    oi.quantity,
    oi.unit_price,
    (oi.quantity * oi.unit_price)
FROM public.order_items oi
JOIN public.orders o ON oi.order_id = o.id
JOIN dwh.dim_product dp ON oi.product_id = dp.product_id;