-- 1. Kategorilere Göre Toplam Satış (Ciro)
-- OLTP (3 JOIN, anlık matematik)
SELECT c.name, SUM(oi.quantity * oi.unit_price) 
FROM public.order_items oi 
JOIN public.products p ON oi.product_id = p.id 
JOIN public.categories c ON p.category_id = c.id 
GROUP BY c.name;

-- DWH (1 JOIN, önceden hesaplanmış)
SELECT dp.category_name, SUM(foi.line_total) 
FROM dwh.fct_order_items foi 
JOIN dwh.dim_product dp ON foi.product_sk = dp.product_sk 
GROUP BY dp.category_name;

-- 2. Aylara Göre Toplam Sipariş Sayısı
-- OLTP (Tarih fonksiyonu çalıştırma maliyeti)
SELECT EXTRACT(MONTH FROM created_at) as ay, COUNT(id) 
FROM public.orders 
GROUP BY 1;

-- DWH (Doğrudan boyut tablosundan okuma)
SELECT dd.month, COUNT(fo.order_id) 
FROM dwh.fct_orders fo 
JOIN dwh.dim_date dd ON fo.date_id = dd.date_id 
GROUP BY dd.month;

-- 3. En Çok Ciro Yapan 5 Ürün
-- OLTP
SELECT p.name, SUM(oi.quantity * oi.unit_price) as ciro 
FROM public.order_items oi 
JOIN public.products p ON oi.product_id = p.id 
GROUP BY p.name ORDER BY ciro DESC LIMIT 5;

-- DWH
SELECT dp.product_name, SUM(foi.line_total) as ciro 
FROM dwh.fct_order_items foi 
JOIN dwh.dim_product dp ON foi.product_sk = dp.product_sk 
GROUP BY dp.product_name ORDER BY ciro DESC LIMIT 5;

-- 4. Hafta Sonu vs Hafta İçi Sipariş Dağılımı
-- OLTP
SELECT CASE WHEN EXTRACT(ISODOW FROM created_at) IN (6, 7) THEN TRUE ELSE FALSE END as is_weekend, COUNT(id) 
FROM public.orders GROUP BY 1;

-- DWH
SELECT dd.is_weekend, COUNT(fo.order_id) 
FROM dwh.fct_orders fo 
JOIN dwh.dim_date dd ON fo.date_id = dd.date_id 
GROUP BY dd.is_weekend;

-- 5. Çeyreklere (Quarter) Göre Satış Tutarı
-- OLTP
SELECT EXTRACT(QUARTER FROM o.created_at) as ceyrek, SUM(oi.quantity * oi.unit_price) 
FROM public.orders o 
JOIN public.order_items oi ON o.id = oi.order_id GROUP BY 1;

-- DWH
SELECT dd.quarter, SUM(foi.line_total) 
FROM dwh.fct_order_items foi 
JOIN dwh.fct_orders fo ON foi.order_id = fo.order_id 
JOIN dwh.dim_date dd ON fo.date_id = dd.date_id GROUP BY dd.quarter;

-- 6. Sipariş Durumuna (Status) Göre Ortalama Sepet Tutarı
-- OLTP
SELECT status, AVG(total_amount) FROM public.orders GROUP BY status;
-- DWH
SELECT status, AVG(total_amount) FROM dwh.fct_orders GROUP BY status;

-- 7. En Fazla Sipariş Veren 5 Müşteri
-- OLTP
SELECT u.email, COUNT(o.id) 
FROM public.users u 
JOIN public.orders o ON u.id = o.user_id 
GROUP BY u.email ORDER BY COUNT(o.id) DESC LIMIT 5;

-- DWH
SELECT dc.email, COUNT(fo.order_id) 
FROM dwh.dim_customer dc 
JOIN dwh.fct_orders fo ON dc.customer_sk = fo.customer_sk 
GROUP BY dc.email ORDER BY COUNT(fo.order_id) DESC LIMIT 5;

-- 8. Kategorilere Göre Satılan Toplam Ürün Adedi
-- OLTP
SELECT c.name, SUM(oi.quantity) 
FROM public.order_items oi 
JOIN public.products p ON oi.product_id = p.id 
JOIN public.categories c ON p.category_id = c.id GROUP BY c.name;

-- DWH
SELECT dp.category_name, SUM(foi.quantity) 
FROM dwh.fct_order_items foi 
JOIN dwh.dim_product dp ON foi.product_sk = dp.product_sk GROUP BY dp.category_name;

-- 9. Haftanın Günlerine Göre Sipariş Yoğunluğu
-- OLTP
SELECT TO_CHAR(created_at, 'Day') as gun, COUNT(id) 
FROM public.orders GROUP BY gun;

-- DWH
SELECT dd.day_name, COUNT(fo.order_id) 
FROM dwh.fct_orders fo 
JOIN dwh.dim_date dd ON fo.date_id = dd.date_id GROUP BY dd.day_name;

-- 10. Müşterilerin Toplam Harcaması (LTV)
-- OLTP
SELECT u.email, SUM(o.total_amount) as total_spend 
FROM public.users u 
JOIN public.orders o ON u.id = o.user_id 
GROUP BY u.email ORDER BY total_spend DESC LIMIT 5;

-- DWH
SELECT dc.email, SUM(fo.total_amount) as total_spend 
FROM dwh.dim_customer dc 
JOIN dwh.fct_orders fo ON dc.customer_sk = fo.customer_sk 
GROUP BY dc.email ORDER BY total_spend DESC LIMIT 5;