-- 1. ADIM: Eski kaydı pasife çekip geçerlilik tarihini sonlandırıyoruz
UPDATE dwh.dim_customer
SET is_current = FALSE, 
    valid_to = CURRENT_TIMESTAMP
WHERE user_id = 1 AND is_current = TRUE;

-- 2. ADIM: Müşteri 1'in yeni bilgilerini güncel tarihle sisteme ekliyoruz
INSERT INTO dwh.dim_customer (user_id, full_name, email, gender, city, valid_from, valid_to, is_current)
VALUES (1, 'yildirimsatrettin', 'yeni_email@example.com', 'Unknown', 'İstanbul', CURRENT_TIMESTAMP, NULL, TRUE);

-- 3. ADIM: Zaman yolculuğunu (History) kanıtlayan test sorgusu
SELECT * FROM dwh.dim_customer WHERE user_id = 1 ORDER BY valid_from;