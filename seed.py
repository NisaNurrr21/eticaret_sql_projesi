import psycopg2
from faker import Faker
import random
import numpy as np
from datetime import datetime, timedelta

# Faker ve Random seed (Tekrar üretilebilir veri için)
fake = Faker('tr_TR')
Faker.seed(42)
random.seed(42)
np.random.seed(42)

# Veritabanı bağlantısı
conn = psycopg2.connect(
    dbname="eticaret", user="admin", password="secret", host="localhost", port="5432"
)
cur = conn.cursor()
print("Eski veriler temizleniyor, sıfırdan başlanacak...")
cur.execute("TRUNCATE TABLE inventory_movements, reviews, shipments, payments, order_items, orders, products, coupons, categories, users, product_price_history RESTART IDENTITY CASCADE;")
conn.commit()

print("Veri üretimi başlıyor, lütfen bekleyin...")

# --- 1. Kategoriler (Categories) ---
kategoriler = ['Elektronik', 'Giyim', 'Ev ve Yaşam', 'Kitap', 'Kozmetik', 'Spor', 'Oyuncak', 'Otomotiv', 'Gıda', 'Pet Shop']
for kat in kategoriler:
    cur.execute("INSERT INTO categories (name) VALUES (%s) ON CONFLICT DO NOTHING", (kat,))
conn.commit()

# --- 2. Kullanıcılar (Users) - 10,000 Kullanıcı ---
# %5 eksik veri (bazı email veya passwordler NULL bırakılabilir, ama kısıtlama olduğu için boş string veya varsayılan değer atayacağız)
users_data = []
for i in range(10000):
    email = fake.unique.email()
    password = fake.sha256()
    
    # %5 eksik veri mantığı (böylece veritabanı kısıtlamalarını test edebiliriz)
    if random.random() < 0.05:
        email = f"user_{i}@missing.com" # NULL yerine varsayılan bir eksik formatı kullandık
        
    cur.execute(
        "INSERT INTO users (email, password_hash, created_at) VALUES (%s, %s, %s) RETURNING id",
        (email, password, fake.date_time_between(start_date='-2y', end_date='now'))
    )
    users_data.append(cur.fetchone()[0])
conn.commit()
print("10,000 kullanıcı eklendi.")

# --- 3. Kuponlar (Coupons) ---
for _ in range(50):
    cur.execute(
        "INSERT INTO coupons (code, discount_pct, valid_until) VALUES (%s, %s, %s)",
        (fake.unique.bothify(text='DISCOUNT-####'), random.randint(5, 50), fake.future_datetime(end_date='+1y'))
    )
conn.commit()

# --- 4. Ürünler (Products) - 1,000 Ürün ---
products_data = []
for _ in range(1000):
    cur.execute(
        "INSERT INTO products (category_id, name, price, stock) VALUES (%s, %s, %s, %s) RETURNING id",
        (random.randint(1, 10), fake.sentence(nb_words=3)[:-1], round(random.uniform(10.0, 5000.0), 2), random.randint(10, 1000))
    )
    products_data.append(cur.fetchone()[0])
conn.commit()
print("1,000 ürün eklendi.")

# --- 5. Siparişler ve İlgili Tablolar (Power Law ve Mevsimsellik) ---
# Power Law: Satışların çoğu az sayıdaki popüler üründen gelecek
populerlik_agirliklari = np.random.pareto(a=2, size=len(products_data))
populerlik_agirliklari /= populerlik_agirliklari.sum()

# Toplam 500,000 sipariş üreteceğiz
toplam_siparis = 500000

for i in range(toplam_siparis):
    user_id = random.choice(users_data)
    
    # Mevsimsellik: Siparişlerin %40'ını kasıtlı olarak yaz aylarına (Haziran, Temmuz, Ağustos) yığıyoruz
    if random.random() < 0.40:
        created_at = fake.date_time_between_dates(datetime_start=datetime.now().replace(month=6, day=1), datetime_end=datetime.now().replace(month=8, day=31))
    else:
        created_at = fake.date_time_between(start_date='-1y', end_date='now')
        
    # Sipariş statüsü: %2 İade (returned), %5 Kasıtlı Anomali (pending ama ödenmiş vs.), kalanı completed
    rand_status = random.random()
    if rand_status < 0.02:
        status = 'returned'
    elif rand_status < 0.07:
        status = 'cancelled'
    else:
        status = 'completed'
        
    cur.execute(
        "INSERT INTO orders (user_id, total_amount, status, created_at) VALUES (%s, %s, %s, %s) RETURNING id",
        (user_id, 0.0, status, created_at) # Total amount'u birazdan güncelleyeceğiz
    )
    order_id = cur.fetchone()[0]
    
    # Sipariş Kalemleri
    num_items = random.randint(1, 5)
    order_total = 0
    
    # Power law dağılımına göre ürün seçimi
    secilen_urunler = np.random.choice(products_data, size=num_items, p=populerlik_agirliklari, replace=False)
    
    for product_id in secilen_urunler:
        # Fiyatı almak için
        cur.execute("SELECT price FROM products WHERE id = %s", (int(product_id),))
        unit_price = cur.fetchone()[0]
        qty = random.randint(1, 3)
        
        cur.execute(
            "INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (%s, %s, %s, %s)",
            (order_id, int(product_id), qty, unit_price)
        )
        order_total += unit_price * qty
        
        # Anomali yaratmak için kasıtlı olarak stok güncellemesini atlayabileceğimiz %1'lik bir durum eklenebilir
    
    # Toplam tutarı güncelle
    cur.execute("UPDATE orders SET total_amount = %s WHERE id = %s", (order_total, order_id))
    
    # Ödeme (Payments)
    if status != 'cancelled':
        cur.execute(
            "INSERT INTO payments (order_id, amount, status) VALUES (%s, %s, %s)",
            (order_id, order_total, 'success' if status == 'completed' else 'refunded')
        )
        # Ödeme kısmının bittiği yerin altına ekle:
        if status == 'completed':
            # 1. Kargo (Shipments) verisi oluştur
            cur.execute(
                "INSERT INTO shipments (order_id, tracking_number, status) VALUES (%s, %s, %s) ON CONFLICT DO NOTHING",
                (order_id, fake.unique.bothify(text='TR-#########'), random.choice(['shipped', 'delivered', 'delivered']))
            )
            
            # 2. Yorum (Reviews) verisi oluştur (%10 ihtimalle müşteri ürünlere yorum yapsın)
            if random.random() < 0.10:
                for product_id in secilen_urunler:
                    cur.execute(
                        "INSERT INTO reviews (user_id, product_id, rating, comment) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING",
                        (user_id, int(product_id), random.randint(1, 5), fake.sentence(nb_words=5))
                    )
    if i % 10000 == 0:
        conn.commit()
        print(f"{i} sipariş işlendi...")

conn.commit()
# --- 6. Envanter Hareketleri (Inventory Movements) ---
print("Envanter hareketleri oluşturuluyor...")
for p_id in products_data:
    # Her ürün için rastgele bir başlangıç stoğu (Initial Stock) hareketi ekle
    cur.execute(
        "INSERT INTO inventory_movements (product_id, quantity_changed, reason) VALUES (%s, %s, %s)",
        (p_id, random.randint(100, 1000), 'Initial Stock Load')
    )
conn.commit()
print("Eksik tablolar başarıyla dolduruldu!")
cur.close()
conn.close()
print("Veritabanı besleme (seeding) işlemi tamamlandı!")