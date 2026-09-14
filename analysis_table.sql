-- CHALLENGE #1
-- Import 4 dataset
-- ============================================================
SELECT
  t.transaction_id,
  t.date,
  t.branch_id,
  b.branch_name,
  b.kota,
  b.provinsi,
  b.rating AS rating_cabang,
  t.customer_name,
  t.product_id,
  p.product_name,
  t.price AS actual_price,
  t.discount_percentage,
  t.rating AS rating_transaksi
FROM `rakamin-kf-analytics-508515.kimia_farma.kf_final_transaction` AS t
LEFT JOIN `rakamin-kf-analytics-508515.kimia_farma.kf_kantor_cabang` AS b
  ON t.branch_id = b.branch_id
LEFT JOIN `rakamin-kf-analytics-508515.kimia_farma.kf_product` AS p
  ON t.product_id = p.product_id
LIMIT 10;

-- ============================================================
-- STEP : VALIDASI DATA INVENTORY
-- ============================================================
-- CHALLENGE:
-- Memastikan kombinasi branch_id dan product_id pada
-- kf_inventory tidak menyebabkan duplikasi ketika
-- digunakan dalam proses JOIN analysis table.
-- ============================================================

SELECT
    branch_id,
    product_id,
    COUNT(*) AS jumlah_data
FROM
    `rakamin-kf-analytics-508515.kimia_farma.kf_inventory`
GROUP BY
    branch_id,
    product_id
HAVING COUNT(*) > 1 ORDER BY jumlah_data DESC;

-- ============================================================
-- STEP : VALIDASI UNIQUE TRANSACTION
-- ============================================================
-- TUJUAN:
-- Memastikan setiap transaction_id pada tabel transaksi
-- hanya muncul satu kali.
--
-- CHALLENGE:
-- transaction_id merupakan salah satu kolom wajib dalam
-- analysis table.
-- ============================================================

SELECT
    COUNT(*) AS total_baris,
    COUNT(DISTINCT transaction_id) AS total_transaction_unik
FROM
    `rakamin-kf-analytics-508515.kimia_farma.kf_final_transaction`;

-- ============================================================
-- STEP : VALIDASI PRIMARY KEY / KEY MASTER DATA
-- ============================================================
-- TUJUAN:
-- Memastikan branch_id pada kf_kantor_cabang dan product_id pada kf_product tidak memiliki duplikasi.
--
-- CHALLENGE:
-- Data transaksi akan digabungkan dengan data kantor cabang berdasarkan branch_id dan dengan data produk berdasarkan product_id.
-- ============================================================

-- Mengecek apakah branch_id pada tabel kantor cabang unik
SELECT
    'kf_kantor_cabang' AS nama_tabel,
    COUNT(*) AS total_baris,
    COUNT(DISTINCT branch_id) AS total_branch_unik
FROM
    `rakamin-kf-analytics-508515.kimia_farma.kf_kantor_cabang`
UNION ALL

-- Mengecek apakah product_id pada tabel produk unik
SELECT
    'kf_product' AS nama_tabel,
    COUNT(*) AS total_baris,
    COUNT(DISTINCT product_id) AS total_product_unik
FROM
    `rakamin-kf-analytics-508515.kimia_farma.kf_product`;


-- STEP : CEK KESESUAIAN TRANSAKSI DENGAN DATA INVENTORY
-- Tujuan:
-- 1. Menggunakan kunci branch_id + product_id untuk mencocokkan transaksi
--    dengan data inventory.
-- 2. Menghindari duplikasi inventory dengan SELECT DISTINCT.
-- 3. Menghitung berapa transaksi yang memiliki pasangan inventory.

WITH inventory_key AS (
  SELECT DISTINCT
    branch_id,
    product_id
  FROM `rakamin-kf-analytics-508515.kimia_farma.kf_inventory`
)

SELECT
  COUNT(*) AS total_transaksi,
  COUNTIF(i.branch_id IS NOT NULL) AS transaksi_match_inventory,
  COUNTIF(i.branch_id IS NULL) AS transaksi_tidak_match_inventory
FROM `rakamin-kf-analytics-508515.kimia_farma.kf_final_transaction` AS t

LEFT JOIN inventory_key AS i
  ON t.branch_id = i.branch_id
  AND t.product_id = i.product_id;

-- ============================================================
-- CHALLENGE #2
-- CREATE ANALYSIS TABLE
-- ============================================================
-- Query ini menggabungkan:
-- 1. kf_final_transaction
-- 2. kf_kantor_cabang
-- 3. kf_product
-- 4. kf_inventory
-- Hasil akhirnya memiliki 16 kolom sesuai requirement challenge.
-- ============================================================

CREATE OR REPLACE TABLE
`rakamin-kf-analytics-508515.kimia_farma.analysis_table`
AS WITH inventory_key AS (
  -- Inventory memiliki duplikasi branch_id + product_id.
  -- DISTINCT digunakan agar JOIN inventory tidak menggandakan
  -- jumlah transaksi.
  SELECT DISTINCT
    branch_id,product_id
  FROM `rakamin-kf-analytics-508515.kimia_farma.kf_inventory`
),

base_data AS (
  SELECT
    t.transaction_id,
    t.date,
    t.branch_id,
    b.branch_name,
    b.kota,
    b.provinsi,
    b.rating AS rating_cabang,
    t.customer_name,
    t.product_id,
    p.product_name,
    t.price AS actual_price,
    t.discount_percentage,
    -- Persentase gross laba berdasarkan harga
    CASE
      WHEN t.price <= 50000 THEN 0.10
      WHEN t.price <= 100000 THEN 0.15
      WHEN t.price <= 300000 THEN 0.20
      WHEN t.price <= 500000 THEN 0.25
      ELSE 0.30
    END AS persentase_gross_laba,
    -- Nett sales setelah diskon
    t.price * (1 - t.discount_percentage) AS nett_sales,
    -- Rating transaksi
    t.rating AS rating_transaksi
  FROM
    `rakamin-kf-analytics-508515.kimia_farma.kf_final_transaction` AS t
  -- Menghubungkan transaksi dengan data cabang
  LEFT JOIN
    `rakamin-kf-analytics-508515.kimia_farma.kf_kantor_cabang` AS b
  ON t.branch_id = b.branch_id
  -- Menghubungkan transaksi dengan data produk
  LEFT JOIN
    `rakamin-kf-analytics-508515.kimia_farma.kf_product` AS p
  ON t.product_id = p.product_id

  -- Menghubungkan transaksi dengan inventory
  -- yang sudah dibuat unik terlebih dahulu.
  LEFT JOIN
    inventory_key AS i
  ON
    t.branch_id = i.branch_id
    AND t.product_id = i.product_id
)

SELECT
  transaction_id,
  date,
  branch_id,branch_name,kota,provinsi,
  rating_cabang,customer_name,
  product_id,product_name,
  actual_price,discount_percentage,
  persentase_gross_laba,nett_sales,

  -- Nett profit
  nett_sales * persentase_gross_laba AS nett_profit,rating_transaksi
FROM base_data;

-- Mengecek jumlah baris dan memastikan transaction_id
-- tetap unik setelah proses JOIN seluruh tabel sumber.
SELECT
  COUNT(*) AS total_baris,
  COUNT(DISTINCT transaction_id) AS total_transaction_unik
FROM `rakamin-kf-analytics-508515.kimia_farma.analysis_table`;

-- CHALLENGE #2
-- ============================================================
-- Validasi kelengkapan kolom dan perhitungan pada analysis_table.

SELECT
  COUNT(*) AS total_baris,
  -- Mengecek apakah kolom hasil JOIN memiliki nilai kosong.
  COUNTIF(branch_name IS NULL) AS branch_name_null,
  COUNTIF(kota IS NULL) AS kota_null,
  COUNTIF(provinsi IS NULL) AS provinsi_null,
  COUNTIF(product_name IS NULL) AS product_name_null,
  -- Mengecek apakah hasil perhitungan penjualan dan profit valid.
  COUNTIF(nett_sales IS NULL) AS nett_sales_null,
  COUNTIF(nett_profit IS NULL) AS nett_profit_null,
  -- Mengecek nilai minimum dan maksimum hasil perhitungan.
  MIN(nett_sales) AS nett_sales_min,
  MAX(nett_sales) AS nett_sales_max,
  MIN(nett_profit) AS nett_profit_min,
  MAX(nett_profit) AS nett_profit_max
FROM `rakamin-kf-analytics-508515.kimia_farma.analysis_table`;
