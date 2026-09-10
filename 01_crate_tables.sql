-- 1. users tablosu
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. categories tablosu
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- 3. coupons tablosu
CREATE TABLE coupons (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    discount_pct INT CHECK (discount_pct > 0 AND discount_pct <= 100),
    valid_until TIMESTAMP NOT NULL
);

-- 4. products tablosu
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    category_id INT REFERENCES categories(id) NOT NULL,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) CHECK (price > 0) NOT NULL,
    stock INT DEFAULT 0 CHECK (stock >= 0)
);

-- 5. orders tablosu
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) NOT NULL,
    coupon_id INT REFERENCES coupons(id), -- NULL olabilir
    total_amount DECIMAL(10, 2) CHECK (total_amount >= 0) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending' NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. order_items tablosu
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id) NOT NULL,
    product_id INT REFERENCES products(id) NOT NULL,
    quantity INT CHECK (quantity > 0) NOT NULL,
    unit_price DECIMAL(10, 2) CHECK (unit_price > 0) NOT NULL
);

-- 7. payments tablosu
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id) UNIQUE NOT NULL,
    amount DECIMAL(10, 2) CHECK (amount > 0) NOT NULL,
    status VARCHAR(50) NOT NULL
);

-- 8. shipments tablosu
CREATE TABLE shipments (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id) UNIQUE NOT NULL,
    tracking_number VARCHAR(100) UNIQUE,
    status VARCHAR(50) NOT NULL
);

-- 9. reviews tablosu
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) NOT NULL,
    product_id INT REFERENCES products(id) NOT NULL,
    rating INT CHECK (rating >= 1 AND rating <= 5) NOT NULL,
    comment TEXT,
    UNIQUE(user_id, product_id) -- Bir kullanıcı bir ürüne tek yorum yapabilir
);

-- 10. inventory_movements tablosu
CREATE TABLE inventory_movements (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id) NOT NULL,
    quantity_changed INT NOT NULL, -- Eksi değerler stok çıkışını, artılar girişi temsil eder
    reason VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);