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