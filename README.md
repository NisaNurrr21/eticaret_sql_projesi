# E-Ticaret Veritabanı Tasarımı ve İleri Seviye SQL Analitiği

Bu proje, kapsamlı bir e-ticaret senaryosu için sıfırdan tasarlanmış bir OLTP veritabanı mimarisini ve 50 farklı ileri seviye SQL analitik sorgusunu içermektedir. Veritabanı, Python kullanılarak güç yasası (power law) ve mevsimsellik (seasonality) gibi gerçek hayat senaryolarına uygun 500.000 satırlık sentetik veri ile beslenmiştir.

## Kullanılan Teknolojiler
* **Veritabanı:** PostgreSQL
* **Veri Üretimi (Seeding):** Python (Faker, Psycopg2, Numpy)
* **Analitik Soru Seti:** İleri Seviye SQL (Window Functions, CTEs, Gaps & Islands, SCD2)

## Proje İçeriği

### 1. Fiziksel Şema Tasarımı (Ödev 3.1)
Veritabanı `users`, `products`, `categories`, `orders`, `order_items`, `payments`, `shipments`, `reviews`, `coupons` ve `inventory_movements` olmak üzere ilişkisel tablolardan oluşmaktadır. 
* Tüm tablolarda `PRIMARY KEY`, `FOREIGN KEY`, `CHECK`, `UNIQUE` ve `NOT NULL` kısıtlamaları uygulanmıştır.
* `seed.py` dosyası ile 500.000 sipariş kaydı, %2 iade oranı, %5 eksik veri (null) ve yaz aylarında sipariş yoğunluğu (mevsimsellik) kurgulanarak otomatik oluşturulur.

### 2. Analitik Sorgular (Ödev 3.2)
Veritabanı üzerinde iş zekası ve CRM ekiplerinin ihtiyaç duyabileceği 50 farklı analitik sorgu yazılmıştır. Raporda öne çıkan bazı analizler:
* **Kohort Analizi:** Aylık yeni kullanıcıların N. ay dönüş oranları (Retention).
* **RFM Segmentasyonu:** `NTILE` fonksiyonu ile müşteri skorlaması.
* **Gaps and Islands Problemi:** Ardışık günlerde alışveriş yapan müşteri serileri.
* **Hareketli Ortalama (Rolling Average):** Ürün başına 7 günlük hareketli ortalama satış trendi.
* **SCD2 (Slowly Changing Dimensions):** Zaman içinde değişen ürün fiyatlarının geçmiş siparişlerdeki geçerli değerini bulma.
* **Funnel Analizi:** Sepet -> Ödeme -> Kargo dönüşüm oranları.

## Kurulum ve Çalıştırma

Projedeki veritabanını sıfırdan kurmak ve verilerle doldurmak için terminalde aşağıdaki komutu çalıştırmanız yeterlidir:

```bash
# Tabloları oluşturur ve 500k sentetik veriyi basar
python seed.py
```

### 3. Veritabanı Performans Optimizasyonu (Ödev 3.3)
Veritabanı üzerindeki yavaş (costly) sorgular tespit edilmiş ve `EXPLAIN ANALYZE` okumalarıyla darboğazlar giderilmiştir. Toplamda 5 farklı optimizasyon senaryosu laboratuvar ortamında test edilmiştir:
* **Index & Bitmap Scan:** B-Tree ve kompozit (composite) indeksler ile `Parallel Seq Scan` taramaları `Bitmap Index Scan` seviyesine çekilerek sorgularda 400 kata varan hızlanmalar sağlandı.
* **Anti-Pattern Analizi:** İndekslerin neden çalışmadığına dair (fonksiyon kullanımı, düşük seçicilik) derinlemesine analizler yapıldı.
* *Tüm performans karşılaştırmaları ve kanıtları `performans_lab.md` dosyasında raporlanmıştır.*

### 4. Veri Ambarı ve Star Schema Mimarisi (Ödev 3.4)
Analitik raporlama performansını artırmak ve karmaşık JOIN yapılarını sadeleştirmek için OLTP veritabanından OLAP (Veri Ambarı) mimarisine geçiş yapılmıştır.
* **Şema Tasarımı:** Merkezde `fct_orders`, `fct_order_items` (Gerçek) ve etrafında `dim_customer`, `dim_product`, `dim_date` (Boyut) tabloları ile Star Schema kurgulandı.
* **Idempotent ETL:** Verileri OLTP'den OLAP'a güvenli ve veri kirliliği yaratmadan aktaran tekrarlanabilir yükleme scriptleri yazıldı.
* **SCD2 (Slowly Changing Dimensions):** Müşteri bilgilerindeki değişiklikleri, eski fatura raporlarını bozmadan tarihe gömen (`valid_from`, `valid_to`, `is_current`) zaman yolculuğu mimarisi kuruldu ve test edildi.
* **A/B Benchmark Testi:** Yazılan karmaşık bir iş zekası sorgusu OLTP sistemde 4 adet `JOIN` ile ~300ms'de çalışırken, Star Schema üzerinde tek `JOIN` ile ~127ms'de çalıştırılarak **~2.3 kat performans artışı** ve düşük CPU tüketimi kanıtlandı.
### Star Schema Grain (Tanecik) Tanımı
* **`fct_orders` Tablosu:** Her bir satır, bir müşterinin verdiği **tek bir benzersiz siparişi (order)** temsil eder.
* **`fct_order_items` Tablosu:** Her bir satır, verilen bir siparişin sepetindeki **tek bir ürün kalemini (line item)** temsil eder.

### 10 İş Sorusu: OLTP vs Star Schema (DWH) Karşılaştırma Raporu
DBeaver üzerinde 10 farklı analitik soru hem eski ilişkisel yapı (OLTP) hem de yeni yıldız şema (DWH) üzerinde test edilmiştir.

| Analitik Soru Kategorisi | OLTP (Eski Sistem) | Star Schema (Yeni Sistem) | Okunabilirlik ve Süre Avantajı |
| :--- | :--- | :--- | :--- |
| **Ciro & Ürün Analizleri (Soru 1,3,5,8)** | 3-4 adet `JOIN` ve anlık matematik (`qty * price`) | Sadece 1 `JOIN` ve hesaplanmış `line_total` | Kod satırı %60 kısaldı, CPU hesaplama yükü ortadan kalktığı için tepki süresi hızlandı. |
| **Zaman ve Tarih Analizleri (Soru 2,4,9)** | `EXTRACT()`, `TO_CHAR()` gibi maliyetli dönüşüm fonksiyonları | `dim_date` boyut tablosundan doğrudan okuma | Fonksiyonların yarattığı darboğaz (`Full Table Scan`) engellendi, tarih okumaları anlık hale geldi. |
| **Müşteri Davranışları (Soru 6,7,10)** | `users` ve `orders` tablolarında `VARCHAR` e-posta aramaları | `dim_customer` üzerinden INT formatında `customer_sk` taraması | Surrogate Key kullanımı sayesinde `JOIN` maliyetleri düştü, sorgu yazımı basitleşti. |

### 5. Büyük Veri Analitiği: DuckDB vs Pandas (Ödev 3.5)
Klasik veritabanlarından bağımsız olarak, 3 milyon satırlık (NYC Taxi) Parquet veri seti üzerinde sunucusuz (serverless) analitik performans kıyaslaması yapılmıştır.
* **Hız Avantajı:** C++ tabanlı vektörel sorgu motoru kullanan DuckDB, 10 farklı iş zekası sorgusunu Pandas'a kıyasla **~12.4 kat daha hızlı** (0.26 sn vs 3.25 sn) tamamlamıştır.
* **RAM Optimizasyonu:** Pandas tüm dosyayı RAM'e alarak **~1 GB** bellek tüketirken; DuckDB veriyi RAM'e yüklemeden doğrudan diskten okuyarak (lazy evaluation) süreci yalnızca **~10 MB** bellek ile bitirmiştir.
* *Detaylı bellek ve CPU karşılaştırma raporu `performans_lab.md` dosyasında yer almaktadır.*