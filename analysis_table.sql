-- ============================================================
-- KIMIA FARMA BIG DATA ANALYST
-- Analisis Kinerja Bisnis Kimia Farma Tahun 2020-2023
-- ============================================================
-- Tujuan:
-- Membuat analysis_table dengan menggabungkan data transaksi,
-- data kantor cabang, data produk, dan data inventory.
--
-- Tabel sumber:
-- 1. kf_final_transaction
-- 2. kf_inventory
-- 3. kf_kantor_cabang
-- 4. kf_product
--
-- Output:
-- analysis_table
-- ============================================================


-- Membuat key inventory yang unik berdasarkan kombinasi
-- branch_id dan product_id untuk mencegah JOIN menggandakan
-- jumlah transaksi karena terdapat duplikasi pada inventory.
WITH inventory_key AS (
  SELECT DISTINCT
    branch_id,
    product_id
  FROM `rakamin-kf-analytics-508515.kimia_farma.kf_inventory`
),


-- Menggabungkan data transaksi dengan informasi cabang,
-- produk, dan inventory.
base_data AS (
  SELECT
    t.transaction_id,
    t.date,
    t.branch_id,

    -- Informasi kantor cabang
    b.branch_name,
    b.kota,
    b.provinsi,
    b.rating AS rating_cabang,

    -- Informasi pelanggan
    t.customer_name,

    -- Informasi produk
    t.product_id,
    p.product_name,

    -- Informasi transaksi
    t.price AS actual_price,
    t.discount_percentage,

    -- Menentukan persentase gross profit berdasarkan
    -- harga produk sesuai ketentuan challenge.
    CASE
      WHEN t.price <= 50000 THEN 0.10
      WHEN t.price <= 100000 THEN 0.15
      WHEN t.price <= 300000 THEN 0.20
      WHEN t.price <= 500000 THEN 0.25
      ELSE 0.30
    END AS persentase_gross_laba,

    -- Menghitung nett sales setelah diskon.
    t.price * (1 - t.discount_percentage) AS nett_sales,

    -- Rating transaksi dari data transaksi.
    t.rating AS rating_transaksi

  FROM `rakamin-kf-analytics-508515.kimia_farma.kf_final_transaction` AS t

  -- Menggabungkan transaksi dengan data kantor cabang.
  LEFT JOIN `rakamin-kf-analytics-508515.kimia_farma.kf_kantor_cabang` AS b
    ON t.branch_id = b.branch_id

  -- Menggabungkan transaksi dengan data produk.
  LEFT JOIN `rakamin-kf-analytics-508515.kimia_farma.kf_product` AS p
    ON t.product_id = p.product_id

  -- Menghubungkan transaksi dengan inventory
  -- menggunakan kombinasi branch_id dan product_id.
  LEFT JOIN inventory_key AS i
    ON t.branch_id = i.branch_id
    AND t.product_id = i.product_id
)


-- Membuat tabel analisis final.
SELECT
  transaction_id,
  date,
  branch_id,
  branch_name,
  kota,
  provinsi,
  rating_cabang,
  customer_name,
  product_id,
  product_name,
  actual_price,
  discount_percentage,
  persentase_gross_laba,
  nett_sales,

  -- Menghitung nett profit berdasarkan nett sales
  -- dan persentase gross laba.
  nett_sales * persentase_gross_laba AS nett_profit,

  rating_transaksi

FROM base_data;
