# Matematiksel Temeller ve Araştırma Ödevleri Raporu

## 4.6 Araştırma Ödevleri

### 1. Neden $(X^T X)^{-1} X^T y$ Üretimde Kullanılmaz?
* **Sayısal Kararlılık ve Koşul Sayısı:** Matrisin tersini almak ($X^T X$) koşul sayısını (condition number) karesine çıkarır. Bu durum, kayan nokta (floating-point) hassasiyet kayıplarına ve büyük hesaplama hatalarına yol açar.
* **Hesaplama Maliyeti:** Matris inversiyonu $O(n^3)$ karmaşıklığa sahiptir; büyük veri setlerinde donanımı kilitler.
* **Alternatifler ve Ridge Etkisi:** Üretimde QR Decompozisyonu veya SVD (Singular Value Decomposition) tercih edilir. Ridge regresyon ise köşegene küçük bir $\lambda I$ terimi ekleyerek matrisin terslenebilir olmasını sağlar.

### 2. Kösinüs mü Öklid mi? Vektör Aramada Mesafe Metriği
* **Öklid Mesafesi:** Vektörlerin uzunluğunu (magnitude) hesaba katar. Sadece uçların konumuna değil, büyüklük farklarına da duyarlıdır.
* **Kösinüs Benzerliği:** Açısal farka odaklanır, vektör uzunluğundan bağımsızdır. Metin ve yüksek boyutlu gömme (embedding) uzaylarında yön (anlam) büyüklükten daha kritik olduğu için kösinüs standarttır.

### 3. LoRA'nın Matematiği ve Düşük Ranklı Yaklaşım
* **Ağırlık Güncellemesi:** Büyük bir $W_0$ matrisini değiştirmek yerine, değişim $\Delta W = B \times A$ şeklinde iki küçük matrise ayrıştırılır.
* **Parametre Tasarrufu:** $d \times d$ boyutundaki bir matris yerine $r \ll d$ olmak üzere $2 \times d \times r$ parametre güncellenir. Bu, GPU bellek ve gradyan hesaplama maliyetini dramatik biçimde düşürür.

---

## 4.7 Kontrol Soruları (Tahtada, AI'sız)

### 1. $A$ ($3 \times 5$) ve $B$ ($5 \times 2$) İçin Boyutlar
* **$AB$ Boyutu:** $3 \times 2$'dir (İç boyutlar 5 eşleşir).
* **$BA$ Tanımlı mı?:** Tanımlı **değildir**. $B$ ($5 \times 2$) ile $A$ ($3 \times 5$) çarpılırken iç boyutlar (2 ve 3) uyuşmaz.

### 2. Determinantı 0 Olan Matrisin Dönüşümü
Boyut düşürücü (kollaps) etki yapar. 2 boyutlu bir düzlemi 1 boyutlu bir doğruya veya tek bir noktaya (0,0) çökertir; uzayda bilgi kaybı (rank kaybı) yaratır.

### 3. Kovaryans Matrisi Neden Simetrik ve PSD'dir?
* **Simetriktir:** $\text{Cov}(X_i, X_j) = \text{Cov}(X_j, X_i)$ tanımı gereği matris köşegene göre simetriktir ($\Sigma = \Sigma^T$).
* **Pozitif Yarı Tanımlıdır (PSD):** Herhangi bir $v$ vektörü için $v^T \Sigma v = \text{Var}(v^T X) \ge 0$ dir. Varyans negatif olamayacağı için matris PSD'dir.

### 4. PCA'da Ortalama Çıkarma
Veriyi orijine (merkeze) taşır. Ortalama çıkarılmazsa ilk ana bileşen (PC1) maksimum varyans yönünü değil, doğrudan orijine olan uzaklık eksenini yakalamaya çalışır ve hatalı bir rotasyon oluşur.

### 5. $\text{softmax}(QK^T/\sqrt{d})V$ İçindeki $\sqrt{d}$ Faktörü
$Q$ ve $K$ bileşenlerinin varyansı boyut ($d_k$) büyüdükçe artar. Bu durum softmax fonksiyonunu çok keskin (gradient'in sıfıra yakın olduğu doygunluk bölgelerine) iter. $\sqrt{d}$ ile bölmek varyansı 1'e sabitleyerek gradyanların sönmesini (vanishing gradient) engeller.

### 6. Rank'i 3 Olan Bir Matrisin Kolon ve Boş Uzayı
* **Kolon Uzayının Boyutu:** Matrisin sütun rankı tanımı gereği **3**'tür.
* **Boş Uzayın Boyutu (Nullity):** Boyut Teoremi'ne göre $\text{Rank} + \text{Nullity} = \text{Sütun Sayısı ($n$)}$ formülüyle bulunur (örneğin matris 5 sütunluysa boş uzayın boyutu $5 - 3 = 2$'dir).