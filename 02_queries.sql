-- Soru 1: Kategori bazlı top 3 ürün (ROW_NUMBER)
WITH KategoriSatis AS (
    -- Adım 1: Her ürünün toplam gelirini hesapla ve kategorisiyle eşleştir
    SELECT 
        c.name AS kategori_adi,
        p.name AS urun_adi,
        SUM(oi.quantity * oi.unit_price) AS toplam_gelir
    FROM categories c
    JOIN products p ON c.id = p.category_id
    JOIN order_items oi ON p.id = oi.product_id
    JOIN orders o ON oi.order_id = o.id
    WHERE o.status = 'completed' -- Sadece tamamlanmış siparişleri baz alıyoruz
    GROUP BY c.id, c.name, p.id, p.name
),
Siralama AS (
    -- Adım 2: Kategorilere göre bölüp (PARTITION BY) gelire göre azalan sırada numaralandır
    SELECT 
        kategori_adi,
        urun_adi,
        toplam_gelir,
        ROW_NUMBER() OVER(PARTITION BY kategori_adi ORDER BY toplam_gelir DESC) as sira
    FROM KategoriSatis
)
-- Adım 3: Sadece ilk 3 sıradakileri filtrele
SELECT 
    kategori_adi,
    sira,
    urun_adi,
    toplam_gelir
FROM Siralama
WHERE sira <= 3
ORDER BY kategori_adi, sira;

-- Soru 2: Aylık Büyüme Oranı (LAG)
WITH AylikCiro AS (
    -- Adım 1: Siparişleri aylara göre gruplayıp toplam ciroyu bul
    SELECT 
        DATE_TRUNC('month', created_at) AS ay,
        SUM(total_amount) AS ciro
    FROM orders
    WHERE status = 'completed'
    GROUP BY DATE_TRUNC('month', created_at)
),
AylikKiyaslama AS (
    -- Adım 2: LAG fonksiyonu ile bir önceki ayın cirosunu aynı satıra getir
    SELECT 
        ay,
        ciro,
        LAG(ciro) OVER(ORDER BY ay) AS onceki_ay_cirosu
    FROM AylikCiro
)
-- Adım 3: Büyüme/Küçülme oranını yüzde olarak hesapla
SELECT 
    ay,
    ciro,
    onceki_ay_cirosu,
    ROUND(((ciro - onceki_ay_cirosu) / onceki_ay_cirosu) * 100, 2) AS buyume_orani_yuzde
FROM AylikKiyaslama
ORDER BY ay;

-- Soru 3: RFM Segmentasyonu (NTILE)
WITH RFM_Degerleri AS (
    -- Adım 1: Her kullanıcının R, F, M temel metriklerini hesapla
    SELECT
        user_id,
        MAX(created_at) AS son_siparis_tarihi,
        COUNT(id) AS siparis_sayisi,
        SUM(total_amount) AS toplam_harcama
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
),
RFM_Skorlari AS (
    -- Adım 2: NTILE(4) ile her metriği 1 (En Kötü) ile 4 (En İyi) arasında skorla
    SELECT
        user_id,
        son_siparis_tarihi,
        siparis_sayisi,
        toplam_harcama,
        NTILE(4) OVER(ORDER BY son_siparis_tarihi ASC) AS r_skor,
        NTILE(4) OVER(ORDER BY siparis_sayisi ASC) AS f_skor,
        NTILE(4) OVER(ORDER BY toplam_harcama ASC) AS m_skor
    FROM RFM_Degerleri
)
-- Adım 3: Skorları yan yana getirip segment etiketlerini yapıştır
SELECT
    user_id,
    r_skor,
    f_skor,
    m_skor,
    CONCAT(r_skor, f_skor, m_skor) AS rfm_kodu,
    CASE
        WHEN r_skor = 4 AND f_skor = 4 AND m_skor = 4 THEN 'Sampiyonlar'
        WHEN r_skor >= 3 AND f_skor >= 3 THEN 'Sadik Musteriler'
        WHEN r_skor <= 2 AND f_skor >= 3 THEN 'Riskli (Kaybedilmek Uzere)'
        WHEN r_skor = 1 AND f_skor <= 2 THEN 'Kaybedilenler'
        ELSE 'Digerleri'
    END as segment
FROM RFM_Skorlari
ORDER BY rfm_kodu DESC;

-- Soru 4: 7 Günlük Hareketli Ortalama
WITH GunlukSatis AS (
    -- Adım 1: Her ürünün günlük toplam satış adedini bul
    SELECT 
        product_id,
        DATE_TRUNC('day', o.created_at) AS satis_tarihi,
        SUM(oi.quantity) AS gunluk_adet
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    WHERE o.status = 'completed'
    GROUP BY product_id, DATE_TRUNC('day', o.created_at)
)
-- Adım 2: ROWS BETWEEN ile kendisi ve önceki 6 satırın ortalamasını hesapla
SELECT 
    product_id,
    satis_tarihi,
    gunluk_adet,
    ROUND(AVG(gunluk_adet) OVER(
        PARTITION BY product_id 
        ORDER BY satis_tarihi 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS yedi_gunluk_ort_satis
FROM GunlukSatis
ORDER BY product_id, satis_tarihi;

-- Soru 5: Ardışık Günlerde Alışveriş Serileri (Gaps and Islands)
WITH DistinctDays AS (
    -- Adım 1: Kullanıcıların alışveriş yaptığı günleri tekilleştir (Aynı gün 2 sipariş varsa 1 sayılır)
    SELECT DISTINCT 
        user_id, 
        DATE_TRUNC('day', created_at) AS islem_gunu
    FROM orders
    WHERE status = 'completed'
),
GroupedDays AS (
    -- Adım 2: Gaps & Islands Matematiği 
    -- İşlem gününden, o günün sıra numarası kadar gün çıkarıyoruz. 
    -- Ardışık günlerde bu çıkarma işleminin sonucu (island_group) hep AYNI tarihi verir!
    SELECT 
        user_id,
        islem_gunu,
        islem_gunu - (ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY islem_gunu) * INTERVAL '1 day') AS island_group
    FROM DistinctDays
)
-- Adım 3: Aynı gruba sahip olanları topla ve sadece serisi 2 gün ve üstü olanları listele
SELECT 
    user_id,
    MIN(islem_gunu) AS seri_baslangic_tarihi,
    MAX(islem_gunu) AS seri_bitis_tarihi,
    COUNT(*) AS ardisik_gun_sayisi
FROM GroupedDays
GROUP BY user_id, island_group
HAVING COUNT(*) > 1 
ORDER BY ardisik_gun_sayisi DESC, seri_baslangic_tarihi DESC;

-- Soru 6: Funnel Dönüşüm Oranları (Sipariş -> Ödeme -> Kargo)
WITH Funnel_Verisi AS (
    -- Adım 1: Tüm aşamalardaki tekil sipariş sayılarını LEFT JOIN ile topla
    SELECT 
        COUNT(DISTINCT o.id) AS toplam_siparis,
        COUNT(DISTINCT p.order_id) AS odenen_siparis,
        COUNT(DISTINCT s.order_id) AS kargolanan_siparis
    FROM orders o
    LEFT JOIN payments p ON o.id = p.order_id AND p.status = 'success'
    LEFT JOIN shipments s ON o.id = s.order_id
)
-- Adım 2: Her bir aşamanın bir öncekine göre başarı yüzdesini hesapla
SELECT 
    toplam_siparis,
    odenen_siparis,
    ROUND((odenen_siparis::numeric / NULLIF(toplam_siparis, 0)) * 100, 2) AS odeme_donusum_orani_yuzde,
    kargolanan_siparis,
    ROUND((kargolanan_siparis::numeric / NULLIF(odenen_siparis, 0)) * 100, 2) AS kargo_donusum_orani_yuzde
FROM Funnel_Verisi;

--Soru 7: En Çok Sipariş Veren 10 Müşteri
SELECT 
    u.email,
    COUNT(o.id) AS toplam_siparis_sayisi,
    SUM(o.total_amount) AS toplam_harcama
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE o.status = 'completed'
GROUP BY u.id, u.email
ORDER BY toplam_siparis_sayisi DESC
LIMIT 10;

--Soru 8: Hiç Alışveriş Yapmayan Kullanıcılar
SELECT
    u.email,
    u.created_at AS kayit_tarihi
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE o.id IS NULL
ORDER BY u.created_at DESC
LIMIT 50;

--Soru 9: Kategorilere Göre Ortalama Fiyat ve Stok Durumu
SELECT 
    c.name AS kategori_adi,
    ROUND(AVG(p.price), 2) AS ortalama_fiyat,
    SUM(p.stock) AS toplam_stok_adedi
FROM categories c
JOIN products p ON c.id = p.category_id
GROUP BY c.id, c.name
ORDER BY ortalama_fiyat DESC;

--Soru 10: En Çok İade Edilen Ürünler (Top 10)
SELECT 
    p.name AS urun_adi,
    c.name AS kategori_adi,
    COUNT(oi.id) AS iade_edilme_sayisi,
    SUM(oi.quantity) AS iade_edilen_toplam_adet
FROM products p
JOIN categories c ON p.category_id = c.id
JOIN order_items oi ON p.id = oi.product_id
JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'returned'
GROUP BY p.id, p.name, c.name
ORDER BY iade_edilen_toplam_adet DESC
LIMIT 10;

--Soru 11: Kupon Performansı ve Ciro Katkısı
SELECT 
    c.code AS kupon_kodu,
    c.discount_pct AS indirim_yuzdesi,
    COUNT(o.id) AS kullanim_sayisi,
    COALESCE(SUM(o.total_amount), 0) AS kuponla_gelen_toplam_ciro
FROM coupons c
LEFT JOIN orders o 
    ON c.id = o.coupon_id
    AND o.status = 'completed'
GROUP BY c.id, c.code, c.discount_pct
ORDER BY kullanim_sayisi DESC;

--Soru 12: Hiç Satılmayan (Stokta Bekleyen) Ürünler
SELECT 
    p.name AS urun_adi,
    c.name AS kategori_adi,
    p.stock AS mevcut_stok,
    p.price AS birim_fiyat
FROM products p
JOIN categories c ON p.category_id = c.id
LEFT JOIN order_items oi ON p.id = oi.product_id
WHERE oi.product_id IS NULL
ORDER BY p.stock DESC
LIMIT 50;

--Soru 13: Ortalama Sepet Tutarı (AOV - Average Order Value)
SELECT 
    ROUND(AVG(total_amount), 2) AS ortalama_sepet_tutari,
    MIN(total_amount) AS en_dusuk_sepet,
    MAX(total_amount) AS en_yuksek_sepet
FROM orders
WHERE status = 'completed';

--Soru 14: Günün Saatlerine Göre Sipariş Yoğunluğu
SELECT 
    EXTRACT(HOUR FROM created_at) AS siparis_saati,
    COUNT(id) AS toplam_siparis_adedi,
    SUM(total_amount) AS saatlik_toplam_ciro
FROM orders
WHERE status = 'completed'
GROUP BY EXTRACT(HOUR FROM created_at)
ORDER BY toplam_siparis_adedi DESC;

--Soru 15: Sepetteki Ortalama Ürün Adedi
SELECT 
    ROUND(AVG(sepetteki_urun_sayisi), 2) AS siparis_basina_ortalama_urun
FROM (
    SELECT 
        o.id,
        SUM(oi.quantity) AS sepetteki_urun_sayisi
    FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY o.id
) AltSorgu;

--Soru 16: Tekrarlayan Müşteriler (Sadakat Analizi)
SELECT 
    u.id AS user_id,
    u.email,
    COUNT(o.id) AS toplam_siparis_sayisi,
    SUM(o.total_amount) AS yasam_boyu_deger
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE o.status = 'completed'
GROUP BY u.id, u.email
HAVING COUNT(o.id) > 1
ORDER BY toplam_siparis_sayisi DESC;

--Soru 17: Tek Seferlik Müşteriler (One-Time Buyers)
SELECT 
    u.id AS user_id,
    u.email,
    SUM(o.total_amount) AS biraktigi_ciro
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE o.status = 'completed'
GROUP BY u.id, u.email
HAVING COUNT(o.id) = 1
ORDER BY biraktigi_ciro DESC
LIMIT 50;

--Soru 18: Kargo Durum Dağılımı
SELECT 
    status AS kargo_durumu,
    COUNT(id) AS kargo_sayisi
FROM shipments
GROUP BY status
ORDER BY kargo_sayisi DESC;

--19: Aylara Göre İptal Edilen Siparişlerin Maliyeti
SELECT 
    DATE_TRUNC('month', created_at) AS ay,
    COUNT(id) AS iptal_sayisi,
    SUM(total_amount) AS kaybedilen_ciro
FROM orders
WHERE status = 'cancelled'
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY ay DESC;

--Soru 20: Kategorilerin Toplam Ciroya Katkısı
SELECT 
    c.name AS kategori_adi,
    COUNT(oi.product_id) AS satilan_urun_adedi,
    SUM(oi.quantity * oi.unit_price) AS toplam_ciro
FROM categories c
JOIN products p ON c.id = p.category_id
JOIN order_items oi ON p.id = oi.product_id
JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'completed'
GROUP BY c.id, c.name
ORDER BY toplam_ciro DESC;

--Soru 21: Stokta Yatan Sermaye (Tied Capital)
SELECT 
    p.name AS urun_adi,
    c.name AS kategori_adi,
    p.stock AS stok_adedi,
    p.price AS birim_fiyat,
    (p.stock * p.price) AS depodaki_toplam_deger
FROM products p
JOIN categories c ON p.category_id = c.id
WHERE p.stock > 0
ORDER BY depodaki_toplam_deger DESC
LIMIT 20;

--Soru 22: Kohort Retention Tablosu (Aylık)
WITH user_cohort AS (
    SELECT 
        id AS user_id,
        DATE_TRUNC('month', created_at) AS cohort_month
    FROM users
),
user_orders AS (
    SELECT DISTINCT
        user_id,
        DATE_TRUNC('month', created_at) AS order_month
    FROM orders
    WHERE status = 'completed'
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(user_id) AS total_users
    FROM user_cohort
    GROUP BY cohort_month
)
SELECT 
    uc.cohort_month,
    EXTRACT(YEAR FROM AGE(uo.order_month, uc.cohort_month)) * 12 + 
    EXTRACT(MONTH FROM AGE(uo.order_month, uc.cohort_month)) AS month_number,
    COUNT(DISTINCT uo.user_id) AS retained_users,
    cs.total_users
FROM user_cohort uc
JOIN user_orders uo ON uc.user_id = uo.user_id
JOIN cohort_sizes cs ON uc.cohort_month = cs.cohort_month
GROUP BY uc.cohort_month, month_number, cs.total_users
ORDER BY uc.cohort_month, month_number;

--Soru 23: Kupon Kullanmadan En Çok Harcama Yapan Müşteriler
SELECT 
    u.email,
    COUNT(o.id) AS siparis_sayisi,
    SUM(o.total_amount) AS toplam_harcama
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE o.status = 'completed' AND o.coupon_id IS NULL
GROUP BY u.id, u.email
ORDER BY toplam_harcama DESC
LIMIT 10;

--Soru 24: En Çok İptal Edilen Sipariş Saatleri
SELECT 
    EXTRACT(HOUR FROM created_at) AS siparis_saati,
    COUNT(id) AS iptal_sayisi
FROM orders
WHERE status = 'cancelled'
GROUP BY EXTRACT(HOUR FROM created_at)
ORDER BY iptal_sayisi DESC;

--Soru 25: Kategorilerdeki En Yüksek ve En Düşük Fiyatlar
SELECT 
    c.name AS kategori_adi,
    MAX(p.price) AS en_pahali_urun_fiyati,
    MIN(p.price) AS en_ucuz_urun_fiyati,
    ROUND(AVG(p.price), 2) AS ortalama_fiyat
FROM categories c
JOIN products p ON c.id = p.category_id
GROUP BY c.id, c.name
ORDER BY en_pahali_urun_fiyati DESC;

--Soru 26: Aylık Yeni Müşteri Kazanımı (Growth)
SELECT 
    DATE_TRUNC('month', created_at) AS kayit_ayi,
    COUNT(id) AS yeni_musteri_sayisi
FROM users
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY kayit_ayi DESC;

--Soru 27: İndirim Oranlarına Göre Ortalama Sepet Tutarı
SELECT 
    c.discount_pct AS indirim_yuzdesi,
    COUNT(o.id) AS siparis_sayisi,
    ROUND(AVG(o.total_amount), 2) AS ortalama_sepet_tutari
FROM orders o
JOIN coupons c ON o.coupon_id = c.id
WHERE o.status = 'completed'
GROUP BY c.discount_pct
ORDER BY indirim_yuzdesi DESC;

--Soru 28: Kritik Stok Seviyesindeki Ürünler
SELECT 
    p.name AS urun_adi,
    cat.name AS kategori_adi,
    p.stock AS kalan_stok,
    p.price AS birim_fiyat
FROM products p
JOIN categories cat ON p.category_id = cat.id
WHERE p.stock < 20
ORDER BY p.stock ASC
LIMIT 30;

--Soru 29: Günlük Ortalama Sipariş Hacmi
SELECT 
    ROUND(AVG(gunluk_siparis_sayisi)) AS gunluk_ortalama_siparis
FROM (
    SELECT 
        DATE_TRUNC('day', created_at) AS gunluk_tarih,
        COUNT(id) AS gunluk_siparis_sayisi
    FROM orders
    GROUP BY DATE_TRUNC('day', created_at)
) AltSorgu;

--Soru 30: Tarihin En Pahalı Tekil Siparişi (Balina Müşteri)
SELECT 
    u.email,
    o.id AS siparis_numarasi,
    o.total_amount AS sepet_tutari,
    o.created_at AS siparis_tarihi
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.status = 'completed'
ORDER BY o.total_amount DESC
LIMIT 1;

--Soru 31: En Çok Satılan İlk 5 Ürün (Adet Bazında)
SELECT 
    p.name AS urun_adi,
    c.name AS kategori_adi,
    SUM(oi.quantity) AS toplam_satilan_adet
FROM products p
JOIN categories c ON p.category_id = c.id
JOIN order_items oi ON p.id = oi.product_id
JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'completed'
GROUP BY p.id, p.name, c.name
ORDER BY toplam_satilan_adet DESC
LIMIT 5;

--Soru 32: Kategorilere Göre İptal Oranları
SELECT 
    c.name AS kategori_adi,
    COUNT(o.id) AS toplam_siparis_sayisi,
    SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END) AS iptal_sayisi,
    ROUND((SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END)::numeric / COUNT(o.id)) * 100, 2) AS iptal_orani_yuzde
FROM categories c
JOIN products p ON c.id = p.category_id
JOIN order_items oi ON p.id = oi.product_id
JOIN orders o ON oi.order_id = o.id
GROUP BY c.id, c.name
ORDER BY iptal_orani_yuzde DESC;

--Soru 33: Aylara Göre Kupon Kullanım Trendleri
SELECT 
    DATE_TRUNC('month', created_at) AS kampanya_ayi,
    COUNT(id) AS kuponlu_siparis_sayisi,
    SUM(total_amount) AS kuponlu_siparis_cirosu
FROM orders
WHERE status = 'completed' AND coupon_id IS NOT NULL
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY kampanya_ayi DESC;

--Soru 34: En Çok Ciro Getiren Günler (Top 10)
SELECT 
    DATE_TRUNC('day', created_at) AS satis_gunu,
    SUM(total_amount) AS gunluk_toplam_ciro,
    COUNT(id) AS gunluk_siparis_sayisi
FROM orders
WHERE status = 'completed'
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY gunluk_toplam_ciro DESC
LIMIT 10;

--Soru 35: Hiç Sipariş Almayan (Ölü) Kategoriler
SELECT 
    c.name AS kategori_adi,
    COUNT(p.id) AS kategoriye_ait_urun_sayisi
FROM categories c
LEFT JOIN products p ON c.id = p.category_id
LEFT JOIN order_items oi ON p.id = oi.product_id
WHERE oi.product_id IS NULL
GROUP BY c.id, c.name;

--Soru 36: Kullanıcı Başına Ortalama Gelir (ARPU - Average Revenue Per User)
SELECT 
    ROUND(SUM(total_amount) / COUNT(DISTINCT user_id), 2) AS arpu_kullanici_basina_gelir
FROM orders
WHERE status = 'completed';

--Soru 37: Haftanın En Yoğun Sipariş Günleri
SELECT 
    TO_CHAR(created_at, 'Day') AS siparis_gunu,
    COUNT(id) AS toplam_siparis_sayisi,
    ROUND(SUM(total_amount), 2) AS gunluk_toplam_ciro
FROM orders
WHERE status = 'completed'
GROUP BY TO_CHAR(created_at, 'Day')
ORDER BY toplam_siparis_sayisi DESC;

--Soru 38: Aynı Kullanıcının Aynı Ürünü Tekrar Alma Oranı
WITH user_product_purchases AS (
    SELECT DISTINCT
        o.user_id,
        oi.product_id,
        COUNT(o.id) AS purchase_count
    FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY o.user_id, oi.product_id
)
SELECT 
    ROUND((CAST(SUM(CASE WHEN purchase_count > 1 THEN 1 ELSE 0 END) AS numeric) / COUNT(*)) * 100, 2) AS tekrar_alinan_urun_yuzdesi
FROM user_product_purchases;

--Soru 39: Ödeme Yöntemlerine Göre Ciro Dağılımı
SELECT 
    status AS odeme_durumu,
    COUNT(id) AS islem_sayisi,
    SUM(amount) AS toplam_hacim
FROM payments
GROUP BY status
ORDER BY toplam_hacim DESC;

--Soru 40: En Çok İade Yapan Riskli Müşteriler
SELECT 
    u.id AS user_id,
    u.email,
    COUNT(o.id) AS iade_siparis_sayisi,
    SUM(o.total_amount) AS firmaya_maliyeti
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE o.status = 'returned'
GROUP BY u.id, u.email
ORDER BY iade_siparis_sayisi DESC, firmaya_maliyeti DESC
LIMIT 15;

--Soru 41: Sepeti Terk Eden / Ödeme Bekleyen Müşteriler (Abandoned Cart)
SELECT 
    u.email,
    o.id AS siparis_numarasi,
    o.total_amount AS sepet_tutari,
    o.created_at AS sepete_eklenme_tarihi
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE o.status = 'pending'
ORDER BY o.created_at DESC
LIMIT 50;

--Soru 42: Zaman İçinde Fiyat Değişimi (SCD2 Tablosundan Geçerli Fiyatı Bulma)
SELECT 
    o.id AS siparis_id,
    p.id AS urun_id,
    o.created_at AS siparis_tarihi,
    s.price AS gecerli_tarihteki_fiyat
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
JOIN product_price_history s ON p.id = s.product_id
  AND o.created_at >= s.valid_from 
  AND (o.created_at < s.valid_to OR s.valid_to IS NULL);
  
--Soru 43: Tek Seferde En Çok Ürün Alınan Sepetler (Hacim Analizi)
SELECT 
    o.id AS siparis_numarasi,
    u.email,
    SUM(oi.quantity) AS sepet_icindeki_toplam_adet,
    o.total_amount AS odenen_tutar
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN order_items oi ON o.id = oi.order_id
WHERE o.status = 'completed'
GROUP BY o.id, u.email, o.total_amount
ORDER BY sepet_icindeki_toplam_adet DESC
LIMIT 10;

--Soru 44: En Çok Farklı Kategori İçeren Siparişler (Çapraz Satış - Cross-Sell)
SELECT 
    o.id AS siparis_numarasi,
    COUNT(DISTINCT p.category_id) AS farkli_kategori_sayisi,
    SUM(oi.quantity) AS toplam_urun_adedi,
    o.total_amount AS ciro
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
WHERE o.status = 'completed'
GROUP BY o.id, o.total_amount
ORDER BY farkli_kategori_sayisi DESC, ciro DESC
LIMIT 15;

--Soru 45: RFM Segmentasyonu (NTILE ile)
WITH rfm_base AS (
    SELECT 
        user_id,
        MAX(created_at) AS last_order_date,
        COUNT(id) AS frequency,
        SUM(total_amount) AS monetary
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
)
SELECT 
    user_id,
    frequency,
    monetary,
    NTILE(4) OVER (ORDER BY last_order_date DESC) AS recency_score, 
    NTILE(4) OVER (ORDER BY frequency DESC) AS frequency_score,
    NTILE(4) OVER (ORDER BY monetary DESC) AS monetary_score
FROM rfm_base;

--Soru 46: Her Kategoride En Çok Satan İlk 3 Ürün (ROW_NUMBER ile)
WITH RankedProducts AS (
    SELECT 
        c.name AS category_name,
        p.name AS product_name,
        SUM(oi.quantity) AS total_sold,
        ROW_NUMBER() OVER(PARTITION BY c.id ORDER BY SUM(oi.quantity) DESC) AS rank_no
    FROM categories c
    JOIN products p ON c.id = p.category_id
    JOIN order_items oi ON p.id = oi.product_id
    JOIN orders o ON oi.order_id = o.id
    WHERE o.status = 'completed'
    GROUP BY c.id, c.name, p.id, p.name
)
SELECT category_name, product_name, total_sold, rank_no
FROM RankedProducts
WHERE rank_no <= 3;

--Soru 47: Ay Bazında Büyüme Oranı (LAG ile)
WITH MonthlyRevenue AS (
    SELECT 
        DATE_TRUNC('month', created_at) AS order_month,
        SUM(total_amount) AS revenue
    FROM orders
    WHERE status = 'completed'
    GROUP BY DATE_TRUNC('month', created_at)
)
SELECT 
    order_month,
    revenue,
    LAG(revenue) OVER(ORDER BY order_month) AS prev_month_revenue,
    ROUND(((revenue - LAG(revenue) OVER(ORDER BY order_month)) / LAG(revenue) OVER(ORDER BY order_month)) * 100, 2) AS growth_rate_percentage
FROM MonthlyRevenue;

--Soru 48: Ürün Başına 7 Günlük Hareketli Ortalama Satış (Rolling Average)
WITH DailyProductSales AS (
    SELECT 
        p.id AS product_id,
        p.name AS product_name,
        DATE_TRUNC('day', o.created_at) AS sale_date,
        SUM(oi.quantity) AS daily_qty
    FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    JOIN products p ON oi.product_id = p.id
    WHERE o.status = 'completed'
    GROUP BY p.id, p.name, DATE_TRUNC('day', o.created_at)
)
SELECT 
    product_name,
    sale_date,
    daily_qty,
    ROUND(AVG(daily_qty) OVER(
        PARTITION BY product_id 
        ORDER BY sale_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_7_day_avg
FROM DailyProductSales
ORDER BY product_name, sale_date DESC;

--Soru 49: Ardışık Günlerde Alışveriş Yapan Müşteriler (Gaps-and-Islands Problemi)
WITH ordered_customer_days AS (
    SELECT DISTINCT
        user_id,
        CAST(created_at AS DATE) AS order_date,
        ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY CAST(created_at AS DATE)) AS rn
    FROM orders
    WHERE status = 'completed'
),
island_groups AS (
    SELECT 
        user_id,
        order_date,
        order_date - (rn * INTERVAL '1 day') AS island_group
    FROM ordered_customer_days
)
SELECT 
    user_id,
    MIN(order_date) AS streak_start_date,
    MAX(order_date) AS streak_end_date,
    COUNT(*) AS consecutive_days
FROM island_groups
GROUP BY user_id, island_group
HAVING COUNT(*) > 1
ORDER BY consecutive_days DESC;

--Soru 50: İlk Sipariş ile İkinci Sipariş Arasındaki Medyan Süre (Müşteri Alışkanlığı)
•WITH ranked_orders AS (
SELECT
user_id, created_at,
ROW_NUMBER ( )
FROM orders
WHERE status = 'completed'
口
OVER(PARTITION BY user_id ORDER BY created_at ASC) AS order_seq
order_diffs AS (
SELECT
o1.user_id,
EXTRACT EPOCH FROM (o2. created_at - 01. created_at)) / 86400 AS days_between
FROM ranked_orders 01
JOIN ranked_orders 02 ON o1. user_id = o2. user_id AND o2. order_seq = 01. order_seq + 1
SELECT
ROUND (PERCENTILE_CONT (0.5) WITHIN GROUP (ORDER BY days_between) ::numeric, 1) AS median_days_
FROM order_diffs;
