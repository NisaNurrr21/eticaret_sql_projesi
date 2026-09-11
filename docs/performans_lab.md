# Ödev 3.3 — Performans Laboratuvarı ve İndeks Optimizasyonu

Bu laboratuvar çalışmasında, veri tabanımız üzerinde kasten yazılmış yavaş (maliyeti yüksek) sorgular tespit edilmiş, `EXPLAIN ANALYZE` ile darboğazlar teşhis edilmiş ve uygun indeksleme/sorgu yazım teknikleriyle (SARGable) optimize edilmiştir. 

---

## BÖLÜM 1: 5 Yavaş Sorgu ve Optimizasyonları

### Senaryo 1: Fonksiyon Uygulanmış Kolon (Kötü Pratik)
**Kasten Kötü Yazılmış Sorgu:**
`created_at` kolonuna `EXTRACT()` fonksiyonu uygulayarak veritabanını tüm tabloyu okumaya (Seq Scan) zorluyoruz.

```sql
EXPLAIN ANALYZE
SELECT * FROM orders
WHERE EXTRACT(MONTH FROM created_at) = 7;
```

**EXPLAIN ANALYZE Çıktısı (Röntgen):**
```txt
Gather (cost=1000.00..9136.00 rows=2500 width=37) (actual time=0.363..26.238 rows=93922 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  -> Parallel Seq Scan on orders (cost=0.00..7886.00 rows=1042 width=37) (actual time=0.022..22.173 rows=31307 loops=3)
       Filter: (EXTRACT(month FROM created_at) = '7'::numeric)
       Rows Removed by Filter: 135359
Planning Time: 0.206 ms
Execution Time: 28.046 ms
```

**Teşhis ve Analiz:**
Sorgu planında açıkça görüldüğü üzere Parallel Seq Scan (Paralel Sıralı Tarama) yapılmıştır. Veritabanı, WHERE bloğunda kolona bir fonksiyon (EXTRACT) uygulandığı için mevcut indeksleri kullanamamış ve "kör" olmuştur (Non-SARGable yapı). İşlem o kadar maliyetli olmuştur ki, veritabanı tabloyu tarayabilmek için arka planda ekstra işçiler (Workers Launched: 2) devreye sokmak zorunda kalmıştır.

**Optimize Edilmiş Sorgu ve İndeksleme (Doğru Pratik):**
Sorguyu EXTRACT fonksiyonundan kurtarıp net bir tarih aralığı (range) koşuluna (SARGable format) çevirdik ve created_at kolonu üzerine bir B-Tree indeksi ekledik.

```sql
-- 1. İndeks Oluşturma
CREATE INDEX idx_orders_created_at ON orders(created_at);

-- 2. Optimize Sorgu
EXPLAIN ANALYZE
SELECT * FROM orders
WHERE created_at >= '2025-07-01' AND created_at < '2025-08-01';
```

**EXPLAIN ANALYZE Çıktısı (Yeni):**
```txt
Index Scan using idx_orders_created_at on orders (cost=0.42..8.44 rows=1 width=37) (actual time=0.002..0.002 rows=0 loops=1)
  Index Cond: ((created_at >= '2025-07-01 00:00:00'::timestamp without time zone) AND (created_at < '2025-08-01 00:00:00'::timestamp without time zone))
Planning Time: 0.131 ms
Execution Time: 0.013 ms
```

**Tedavi ve Sonuç:**
İlgili kolona indeks eklenmesi ve sorgunun fonksiyondan arındırılıp SARGable formata getirilmesiyle doğrudan Index Scan'e (İndeks Taraması) dönülmüştür. Paralel tarama külfeti ortadan kalkmıştır.

| Durum | Tarama Tipi | Çalışma Süresi |
| :--- | :--- | :--- |
| 🔴 **Optimizasyon Öncesi** | `Parallel Seq Scan` | 28.046 ms |
| 🟢 **Optimizasyon Sonrası** | `Index Scan` | 0.013 ms |
| ⚡ **Hızlanma Oranı** | - | **~2157 Kat Daha Hızlı** |

---

### Senaryo 2: Baştaki Yüzde İşareti / Leading Wildcard (Kötü Pratik ve PostgreSQL Sürprizi)

**Kasten Kötü Yazılmış Sorgu:**
Müşteri e-postalarında arama yaparken `%` (wildcard) işaretini kelimenin başına koyarak, veritabanının indeksleri kullanmasını en baştan engelliyoruz.

```sql
EXPLAIN ANALYZE
SELECT * FROM users
WHERE email LIKE '%example.com';
```

**EXPLAIN ANALYZE Çıktısı (Röntgen):**
```txt
Seq Scan on users (cost=0.00..288.00 rows=2828 width=99) (actual time=0.022..1.637 rows=3224 loops=1)
  Filter: ((email)::text ~~ '%example.com'::text)
  Rows Removed by Filter: 6776
Planning Time: 0.113 ms
Execution Time: 1.746 ms
```

**Teşhis ve Analiz:**
Normalde email kolonumuzda UNIQUE constraint olduğu için arkada gizli bir B-Tree indeksi vardır. Ancak LIKE operatöründe % işareti başa konduğunda (Leading Wildcard), veritabanı kelimenin hangi harfle başlayacağını bilemez. Tıpkı bir sözlükte sonu "mek" ile biten kelimeleri aramak için tüm sözlüğü sayfa sayfa okumak zorunda kalmak gibi, Seq Scan yaparak tüm tabloyu taramıştır.

**Optimize Edilmiş Sorgu (SARGable Formata Geçiş):**
Arama mantığını, indeksin devreye girebilmesi umuduyla kelimenin başından başlayacak şekilde (LIKE 'a%') değiştirdik.

```sql
EXPLAIN ANALYZE
SELECT * FROM users
WHERE email LIKE 'a%';
```

**EXPLAIN ANALYZE Çıktısı (Yeni):**
```txt
Seq Scan on users (cost=0.00..288.00 rows=1010 width=99) (actual time=0.022..0.991 rows=1056 loops=1)
  Filter: ((email)::text ~~ 'a%'::text)
  Rows Removed by Filter: 8944
Planning Time: 0.108 ms
Execution Time: 1.044 ms
```

**Tedavi, İleri Seviye Analiz ve Sonuç:**
Baştaki % işaretini kaldırmak, string eşleştirme algoritmasını hafiflettiği için sorgu hızlanmıştır (1.746 ms'den 1.044 ms'ye düştü). Ancak planlayıcı (Query Optimizer) hala Seq Scan yapmıştır! Bunun iki önemli teknik sebebi vardır:
**PostgreSQL Mimarisi:** PostgreSQL'de standart B-Tree indeksleri LIKE operatörü ile çalışmaz. Bunun çalışabilmesi için indeksin açıkça varchar_pattern_ops operatör sınıfı ile (CREATE INDEX ... ON users(email varchar_pattern_ops);) oluşturulması gerekir.
**Tablo Boyutu ve Seçicilik (Selectivity):** users tablomuzda 10.000 kayıt vardır ve 'a' harfiyle başlayan e-postalar tablonun yaklaşık %10'unu (1056 satır) oluşturmaktadır. Optimizer, bu boyuttaki bir tablo için Index'e gidip gelme IO maliyeti yerine, veriyi sıradan okumanın daha ucuz (Cost: 288.00) olduğuna karar vermiştir.

Bu senaryo, "sorguyu doğru yazsanız bile veritabanı motorunun kendi maliyet matematiğine (Cost-Based Optimizer) göre karar vereceğini" kanıtlayan mükemmel bir laboratuvar bulgusudur.

| Durum | Tarama Tipi | Çalışma Süresi |
| :--- | :--- | :--- |
| 🔴 **Optimizasyon Öncesi** | `Seq Scan` (Leading Wildcard) | 1.746 ms |
| 🟢 **Optimizasyon Sonrası** | `Seq Scan` (SARGable) | 1.044 ms |
| ⚡ **Hızlanma Oranı** | - | **~1.6 Kat Daha Hızlı** |

---

### Senaryo 3: Foreign Key Üzerinde Eksik İndeks (Gizli Tehlike)

**Kasten Kötü Yazılmış Sorgu:**
`order_items` tablosu `orders` tablosuna bağlıdır (Foreign Key). Ancak `order_id` kolonunda indeks olmadığı için belirli bir siparişin detaylarını getirmek veritabanı için bir felakete dönüşür.

```sql
EXPLAIN ANALYZE
SELECT * FROM order_items
WHERE order_id = 250000;
```

**EXPLAIN ANALYZE Çıktısı (Röntgen):**
```txt
Gather (cost=1000.00..18366.29 rows=4 width=22) (actual time=35.362..36.657 rows=3 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  -> Parallel Seq Scan on order_items (cost=0.00..17365.89 rows=2 width=22) (actual time=28.330..32.605 rows=1 loops=3)
       Filter: (order_id = 250000)
       Rows Removed by Filter: 499960
Planning Time: 0.169 ms
Execution Time: 36.670 ms
```

**Teşhis ve Analiz:**
PostgreSQL, Primary Key'ler için otomatik indeks oluştururken, Foreign Key'ler için otomatik indeks oluşturmaz. Müşteri bir siparişin detayına (faturasına) tıkladığında, order_items tablosu devasa boyutta olmasına rağmen baştan sona (Parallel Seq Scan) taranmaktadır. Sadece 3 adet satır bulabilmek için tam 499.960 satır (Rows Removed by Filter) gereksiz yere okunmuştur. Yüksek trafikli bir e-ticaret sitesinde bu durum CPU'yu anında %100'e kilitleyecek bir darboğazdır.

**Optimize Edilmiş Sorgu ve İndeksleme:**
Foreign key (order_id) kolonuna açıkça bir B-Tree indeksi ekliyoruz.
```sql
-- 1. İndeks Oluşturma
CREATE INDEX idx_order_items_order_id ON order_items(order_id);

-- 2. Optimize Sorgu
EXPLAIN ANALYZE
SELECT * FROM order_items
WHERE order_id = 250000;
```

**EXPLAIN ANALYZE Çıktısı (Yeni):**
```txt
Index Scan using idx_order_items_order_id on order_items (cost=0.43..8.50 rows=4 width=22) (actual time=0.029..0.030 rows=3 loops=1)
  Index Cond: (order_id = 250000)
Planning Time: 0.080 ms
Execution Time: 0.036 ms
```

**Tedavi ve Sonuç:**
Ağır yük altında çalışan Parallel Seq Scan gitmiş, yerine nokta atışı yapan Index Scan gelmiştir. Süre milisaniyenin bile altına düşerek kusursuz bir optimizasyon sağlanmıştır.

| Durum | Tarama Tipi | Çalışma Süresi |
| :--- | :--- | ---: |
| 🔴 **Optimizasyon Öncesi** | `Parallel Seq Scan` | 36.670 ms |
| 🟢 **Optimizasyon Sonrası** | `Index Scan` | 0.036 ms |
| ⚡ **Hızlanma Oranı** | - | **~1018 Kat Daha Hızlı** |

---

### Senaryo 4: Ağır Sıralama (Sorting) Maliyeti ve Bellek Tüketimi

**Kasten Kötü Yazılmış Sorgu:**
Platformun en pahalı 20 siparişini bulmak için, herhangi bir indeksleme yapmadan tüm tabloyu RAM üzerinde sıralamaya (`ORDER BY`) zorluyoruz.

```sql
EXPLAIN ANALYZE
SELECT id, user_id, total_amount 
FROM orders
ORDER BY total_amount DESC
LIMIT 20;
```

**EXPLAIN ANALYZE Çıktısı (Röntgen):**
```txt
Limit (cost=13388.02..13390.36 rows=20 width=16) (actual time=31.190..32.512 rows=20 loops=1)
  -> Gather Merge (cost=13388.02..62002.45 rows=416666 width=16) (actual time=31.189..32.510 rows=20 loops=1)
       Workers Planned: 2
       Workers Launched: 2
       -> Sort (cost=12388.00..12908.83 rows=208333 width=16) (actual time=29.041..29.042 rows=15 loops=3)
            Sort Key: total_amount DESC
            Sort Method: top-N heapsort  Memory: 27kB
            Worker 0:  Sort Method: top-N heapsort  Memory: 27kB
            Worker 1:  Sort Method: top-N heapsort  Memory: 27kB
            -> Parallel Seq Scan on orders (cost=0.00..6844.33 rows=208333 width=16) (actual time=0.041..13.976 rows=166667 loops=3)
Planning Time: 0.070 ms
Execution Time: 32.547 ms
```

**Teşhis ve Analiz:**
Sorgu, sadece en yüksek tutarlı 20 kaydı getirmek için 500.000 satırlık tablonun tamamını okumuş (Parallel Seq Scan) ve paralelde çalışan işçilerle (Workers Launched: 2) verileri RAM üzerinde pahalı bir sıralama algoritması olan top-N heapsort ile sıralamak zorunda kalmıştır. En son aşamada Gather Merge ile bu sonuçlar birleştirilmiştir. İndekslenmemiş kolonlarda yapılan ORDER BY işlemleri yüksek trafik altında ciddi bir bellek (RAM) ve işlemci (CPU) israfına yol açar.

**Optimize Edilmiş Sorgu ve İndeksleme:**
Sıralama yönünü de belirterek (DESC) özel bir B-Tree indeksi tanımlıyoruz.
```sql
-- 1. İndeks Oluşturma
CREATE INDEX idx_orders_total_amount_desc ON orders(total_amount DESC);

-- 2. Optimize Sorgu
EXPLAIN ANALYZE
SELECT id, user_id, total_amount 
FROM orders
ORDER BY total_amount DESC
LIMIT 20;
```

**EXPLAIN ANALYZE Çıktısı (Yeni):**
```txt
Limit (cost=0.42..1.76 rows=20 width=16) (actual time=0.046..0.070 rows=20 loops=1)
  -> Index Scan using idx_orders_total_amount_desc on orders (cost=0.42..33416.27 rows=500000 width=16) (actual time=0.045..0.068 rows=20 loops=1)
Planning Time: 0.119 ms
Execution Time: 0.079 ms
```

**Tedavi ve Sonuç:**
İndeks oluşturduğumuzda veritabanı bu kolonun verilerini arka planda zaten sıralı (pre-sorted) şekilde tutmaya başlar. Bu sayede veritabanı çalışma anında Sort (sıralama) işlemi yapmaktan tamamen kurtulur; indeks ağacının en üstünden ilk 20 dalı koparır (Limit + Index Scan) ve işlemi saniyenin binde biri gibi bir sürede bitirir.

| Durum | Tarama Tipi | Çalışma Süresi |
| :--- | :--- | ---: |
| 🔴 **Optimizasyon Öncesi** | `Parallel Seq Scan` + `Sort` | 32.547 ms |
| 🟢 **Optimizasyon Sonrası** | `Index Scan` (No Sort) | 0.079 ms |
| ⚡ **Hızlanma Oranı** | - | **~412 Kat Daha Hızlı** |

---

### Senaryo 5: Çoklu Şartlarda Kapsayan (Composite) İndeks Eksikliği

**Kasten Kötü Yazılmış Sorgu:**
İptal edilen ('cancelled') ve 2025 yılından sonraki siparişleri arıyoruz. İki farklı filtre koşulumuz olmasına rağmen indeksimiz olmadığı için veritabanını zorluyoruz.

```sql
EXPLAIN ANALYZE
SELECT id, total_amount 
FROM orders 
WHERE status = 'cancelled' AND created_at >= '2025-01-01';
```

**EXPLAIN ANALYZE Çıktısı (Röntgen):**
```txt
Gather (cost=1000.00..11322.70 rows=24367 width=12) (actual time=0.395..21.900 rows=25040 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  -> Parallel Seq Scan on orders (cost=0.00..7886.00 rows=10153 width=12) (actual time=0.030..16.714 rows=8347 loops=3)
       Filter: ((created_at >= '2025-01-01 00:00:00'::timestamp without time zone) AND ((status)::text = 'cancelled'::text))
       Rows Removed by Filter: 158320
Planning Time: 0.304 ms
Execution Time: 22.677 ms
```

**Teşhis ve Analiz:**
Ayrı ayrı kolonlarda arama yaptığımız ve indeks bulunmadığı için veritabanı yine tam tablo taramasına (Parallel Seq Scan) başvurmuştur. İki farklı filtre koşulunu (status ve created_at) aynı anda sağlamak için tabloyu baştan sona okumak, yüksek kaynak tüketimine ve 158.320 satırın gereksiz yere okunup (Rows Removed by Filter) çöpe atılmasına neden olmuştur.

**Optimize Edilmiş Sorgu ve İndeksleme:**
Her iki koşulu (filtreyi) aynı anda kapsayacak bir Kompozit (Composite) B-Tree indeksi oluşturuyoruz.

```sql
-- 1. İndeks Oluşturma
CREATE INDEX idx_orders_status_date ON orders(status, created_at);

-- 2. Optimize Sorgu
EXPLAIN ANALYZE
SELECT id, total_amount 
FROM orders 
WHERE status = 'cancelled' AND created_at >= '2025-01-01';
```

**EXPLAIN ANALYZE Çıktısı (Yeni):**
```txt
Bitmap Heap Scan on orders (cost=734.18..5860.69 rows=24367 width=12) (actual time=1.795..6.505 rows=25040 loops=1)
  Recheck Cond: (((status)::text = 'cancelled'::text) AND (created_at >= '2025-01-01 00:00:00'::timestamp without time zone))
  Heap Blocks: exact=4736
  -> Bitmap Index Scan on idx_orders_status_date (cost=0.00..728.09 rows=24367 width=0) (actual time=1.488..1.488 rows=25040 loops=1)
       Index Cond: (((status)::text = 'cancelled'::text) AND (created_at >= '2025-01-01 00:00:00'::timestamp without time zone))
Planning Time: 0.100 ms
Execution Time: 6.908 ms
```

**Tedavi, İleri Seviye Analiz ve Sonuç:**
Veritabanı burada klasik bir Index Scan yerine Bitmap Index Scan yapmayı tercih etmiştir. Neden mi? Çünkü sorgu sonucunda dönen kayıt sayısı nispeten yüksektir (25.040 satır). Veritabanı önce kompozit indekse bakarak hangi satırların bu iki koşulu aynı anda sağladığının bir "haritasını" (Bitmap) çıkarır. Ardından sadece o haritadaki gerekli veri bloklarını (Heap Blocks: exact=4736) diskten/bellekten toplu olarak çeker (Bitmap Heap Scan). Bu yöntem, çok sayıda satır dönen çoklu filtrelerde PostgreSQL'in kullandığı en gelişmiş ve ideal okuma stratejisidir. Sorgu süresi ciddi oranda kısalmış, işçilere (Workers) ihtiyaç kalmamıştır.

| Durum | Tarama Tipi | Çalışma Süresi |
| :--- | :--- | ---: |
| 🔴 **Optimizasyon Öncesi** | `Parallel Seq Scan` | 22.677 ms |
| 🟢 **Optimizasyon Sonrası** | `Bitmap Index Scan` | 6.908 ms |
| ⚡ **Hızlanma Oranı** | - | **~3.3 Kat Daha Hızlı** |

---

**A/B Testi Sonuçları: OLTP vs Star Schema (Data Warehouse)**

| Karşılaştırma Metriği | OLTP Şeması (Eski) | Star Schema (Yeni DWH) | Sağlanan Avantaj |
| :--- | :--- | :--- | :--- |
| **Çalışma Süresi** | 299.927 ms | 127.321 ms | **~2.3 Kat Daha Hızlı** |
| **Sorgu Karmaşıklığı** | 4 Tablo (3 adet `JOIN`) | 2 Tablo (1 adet `JOIN`) | Çok daha temiz/okunabilir SQL |
| **Matematiksel Yük** | Çalışma anında (`qty * price`) | Önceden hesaplanmış (`line_total`) | Düşük CPU kullanımı |

**Performans Artışının Teknik Nedenleri:**

* **JOIN Sayısının Düşmesi:** OLTP veritabanında "Kategori" bilgisine ulaşmak için `orders` -> `order_items` -> `products` -> `categories` şeklinde 4 tablonun birleştirilmesi (ardışık Hash Join işlemleri) gerekmiştir. Star Schema'da ise kategori bilgisi `dim_product` boyut tablosuna gömüldüğü (denormalize edildiği) için tek bir JOIN ile aynı veriye ulaşılmıştır.
* **Hesaplanmış Metrikler (Pre-computation):** OLTP sorgusunda her bir ürün kalemi için miktar ve fiyat anlık olarak çarpılırken (`quantity * unit_price`); ETL sürecimizde bu değer `line_total` olarak Fact tablosuna peşinen yazıldığı için, veritabanı okuma anında ekstra işlemci gücü harcamaktan kurtulmuştur.
* **Genişleyebilirlik:** Tablodaki veri miktarı milyonlarca satıra çıktığında, OLTP'deki çoklu JOIN'lerin maliyeti logaritmik olarak artıp sistemi kilitleyecekken; Star Schema mimarisi (Fact ve Dimension mantığı) bu yükü çok daha yatay ve stabil bir şekilde karşılayacaktır.

---

**Büyük Veri Analitiği (3 Milyon Satır Parquet): DuckDB vs Pandas**

| Kriter | DuckDB (Sunucusuz SQL) | Pandas (DataFrame) | Sağlanan Avantaj |
| :--- | :--- | :--- | :--- |
| **Sorgu Süresi (10 İşlem)** | 0.263 saniye | 3.259 saniye | **~12.4 Kat Daha Hızlı** |
| **Bellek (RAM) Tüketimi** | 10.81 MB | 1038.28 MB (1 GB) | **~96 Kat Daha Az RAM** |

**Performans Farkının Teknik Nedenleri:**

* **Tembel Çalışma (Lazy Evaluation) & Disk Okuma:** Pandas, en ufak bir analiz yapabilmek için dahi Parquet dosyasının *tamamını* dekomprese edip RAM'e yüklemek zorundadır (bu yüzden sistemden 1 GB RAM çeker). DuckDB ise dosyayı RAM'e almaz; doğrudan disk üzerindeki sıkıştırılmış Parquet dosyasına SQL atar ve sadece sonucu (birkaç satırı) belleğe getirerek 10 MB ile işi bitirir.
* **Kolon Bazlı ve Vektörel İşleme:** DuckDB, analitik sorgular (OLAP) için özel tasarlanmış, C++ ile yazılmış vektörel bir motora sahiptir. İstenen `GROUP BY` veya `SUM` işlemlerini donanıma en yakın seviyede, CPU önbelleklerini (cache) maksimum kullanarak milisaniyeler içinde tamamlar. Pandas ise tek thread (iş parçacığı) üzerinde çalışan çok daha hantal bir yapıya sahiptir.