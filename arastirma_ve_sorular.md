# Matematiksel Temeller ve Araştırma Ödevleri Raporu


## 4.6 Araştırma Ödevleri

### 1. Neden $(X^T X)^{-1} X^T y$ Üretimde Kullanılmaz?
Doğrusal regresyonda kapalı form çözümü (Closed-form solution) olarak bilinen Normal Denklemler yöntemi, teorik türetmelerde ve küçük veri setlerinde oldukça şık ve etkilidir. Ancak bu formülün üretim ortamlarında (production) doğrudan kullanılmamasının arkasında çok ciddi sayısal kararlılık, bellek ve donanım maliyeti kısıtları yatar. 

İlk temel sorun, **sayısal kararlılık (numerical stability) ve koşul sayısıdır (condition number)**. Bir matrisin tersini almak, matrisin koşul sayısını karesel olarak büyütür. Eğer tasarım matrisiniz $X$ içerisindeki sütunlar (öznitelikler) arasında yüksek korelasyon varsa (çoklu doğrusal bağlantı - multicollinearity), $X^T X$ matrisi tekil (singular) veya tekilliğe çok yakın hale gelir. Kayan nokta aritmetiği (floating-point arithmetic) kullanan bilgisayarlarda, bu tür ill-conditioned matrislerin tersini almaya çalışmak büyük hassasiyet kayıplarına, yuvarlama hatalarına ve hatta tamamen yanlış katsayı tahminlerine yol açar.

İkinci büyük dezavantaj **hesaplama karmaşıklığıdır**. Matris çarpımı $X^T X$ işlemi $O(n p^2)$ maliyet getirirken, bu matrisin tersini almak (örneğin Gauss-Jordan elevasyonu veya LU ayrışımı ile) $O(p^3)$ karmaşıklığa sahiptir (burada $p$ öznitelik sayısı, $n$ örnek sayısını ifade eder). Modern yapay zeka ve veri bilimi projelerinde öznitelik sayısı binlerce, milyarlarca olabildiğinden, bir matrisin tersini almak donanımı tamamen kilitleyen imkansız bir hesaplama yükü doğurur.

Bu sorunların üstesinden gelmek için üretim sistemlerinde asla doğrudan matris inversiyonu yapılmaz. Bunun yerine sayısal olarak kararlı olan **QR Ayrışımı (QR Decomposition)** veya **Tekil Değer Ayrışımı (SVD - Singular Value Decomposition)** tercih edilir. SVD, matrisin tersini doğrudan almak zorunda kalmadan sözde-ters (pseudo-inverse) hesaplamasına olanak tanır ve en kötü koşullu matrislerde bile hatayı minimumda tutar. Ayrıca Ridge Regresyon gibi yöntemler, köşegene küçük bir düzenlileştirme terimi ($\lambda I$) ekleyerek $X^T X$ matrisinin terslenebilir olmasını ve sayısal olarak kararlı kalmasını sağlar.

### 2. Kösinüs mü Öklid mi? Vektör Aramada Mesafe Metriği
Modern RAG (Retrieval-Augmented Generation) sistemlerinde, LLM tabanlı arama motorlarında ve öneri sistemlerinde veriler yüksek boyutlu vektörler (embeddings) olarak temsil edilir. Bu vektörler arasındaki benzerliği veya mesafeyi ölçerken en sık kullanılan iki metrik Öklid Mesafesi ($L_2$ Distance) ve Kösinüs Benzerliğidir (Cosine Similarity). Doğru metriği seçmek, sistemin getirdiği sonuçların kalitesini doğrudan etkiler.

**Öklid Mesafesi**, iki vektör arasındaki düz çizgi üzerindeki geometric mesafeyi hesaplar. Matematiksel olarak şu formülle ifade edilir:
$$d(u, v) = \sqrt{\sum (u_i - v_i)^2}$$
Öklid mesafesi, vektörlerin yalnızca yönünü değil, aynı zamanda **büyüklüğünü (magnitude/length)** de hesaba katar. Örneğin, bir doküman analizinde kelime frekansları kullanılıyorsa, çok uzun bir doküman ile çok kısa bir doküman kelime sayısı bakımından farklı büyüklüklere sahip olacaktır. Öklid bu büyüklük farkına duyarlıdır.

**Kösinüs Benzerliği** ise iki vektör arasındaki **açının kosinüsünü** ölçer ve vektörlerin büyüklüklerinden tamamen bağımsızdır:
$$\text{similarity} = \frac{u \cdot v}{\|u\| \|v\|}$$
Metin gömmelerinde (text embeddings), kelime veya dokümanların uzunluğu genellikle anlamsal içeriğin büyüklüğünü değil, sadece metnin hacmini belirtir. İki doküman aynı konudan bahsediyor ancak biri diğerinden iki kat uzunsa, Öklid mesafesi büyük bir fark gösterirken, aralarındaki açı sıfıra yakın olabilir (yani aynı yönü işaret ederler). Bu nedenle yapay zeka ve NLP dünyasında anlamsal yönelim uzunluktan çok daha önemli olduğundan standart olarak **Kösinüs Benzerliği** tercih edilir.

Ayrıca yüksek boyutlu uzaylarda (yüzlerce veya binlerce boyut) ortaya çıkan **Boyutun Laneti (Curse of Dimensionality)** fenomeni nedeniyle Öklid mesafesi anlamını yitirmeye başlar; en yakın ve en uzak komşu arasındaki mesafe farkı neredeyse sıfırlanır. Kösinüs benzerliği ise yüksek boyutlu normalize uzaylarda bu kararsızlıktan çok daha az etkilenir. Not etmek gerekir ki, eğer vektörler önceden $L_2$ normuna göre birleştirilirse (unit length = 1), Öklid mesafesi ile Kösinüs benzerliği matematiksel olarak birbirine orantılı hale gelir ve aynı sıralamayı üretir.

### 3. LoRA'nın Matematiği: Düşük Ranklı Yaklaşım Neden Fine-Tuning'i Ucuzlatır?
Milyarlarca parametreye sahip Büyük Dil Modellerini (LLM) tam ince ayara (Full Fine-Tuning) tabi tutmak, her bir parametre için bir gradyan, optimize edici durumu (optimizer states - örneğin AdamW için momentum ve varyans) ve aktivasyon belleği tutmayı gerektirir. Bu durum, tüketici sınıfı donanımları aşan devasa VRAM (GPU belleği) maliyetleri doğurur. **LoRA (Low-Rank Adaptation)**, modelin orijinal ağırlıklarını dondurup, ağırlık değişim matrisini düşük ranklı (low-rank) iki küçük matrise çarpanlayarak bu maliyeti radikal biçimde düşüren devrimci bir yaklaşımdır.

Matematiksel temeli şu prensibe dayanır: Araştırmalar, büyük modellerin eğitim sürecindeki ağırlık güncellemelerinin aslında düşük bir **iç ranka (intrinsic rank)** sahip olduğunu göstermiştir. Yani devasa bir $W_0 \in \mathbb{R}^{d \times k}$ ağırlık matrisini tamamen güncellemek yerine, bu değişimi ($\Delta W$) daha küçük iki matrisin çarpımı olarak ifade edebiliriz:
$$\Delta W = B \cdot A$$
Burada $W_0$ dondurulmuş (frozen) orijinal model ağırlığıdır. $B \in \mathbb{R}^{d \times r}$ ve $A \in \mathbb{R}^{r \times k}$ ise eğitilebilir matrislerdir. $r$ rank parametresini temsil eder ve genellikle model boyutundan ($d$ ve $k$) çok çok küçüktür ($r \ll \min(d, k)$, örneğin $r = 4, 8, 16$).

İleri besleme (forward pass) aşamasında çıktı şu şekilde hesaplanır:
$$h = W_0 x + \Delta W x = W_0 x + B A x$$
Eğitim sırasında $W_0$ matrisinin gradyanları hesaplanmaz ve bellekte tutulmaz. Sadece çok daha küçük boyutlu olan $A$ ve $B$ matrislerinin parametreleri güncellenir. Örneğin $4096 \times 4096$ boyutundaki bir katman için tam güncelleme $16,777,216$ parametre gerektirirken; $r=8$ seçildiğinde $4096 \times 8 \times 2 = 65,536$ parametre güncellenir. Bu, eğitilmesi gereken parametre sayısını ve dolayısıyla optimizer'ın tuttuğu bellek yükünü yüzlerce kat azaltır. Sonuç olarak, devasa modeller tek bir GPU üzerinde bile düşük maliyetle ve hızla özelleştirilebilir hale gelir.

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