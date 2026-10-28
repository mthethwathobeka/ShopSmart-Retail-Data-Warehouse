--Task2: Creating Tables
CREATE SCHEMA IF NOT EXISTS profiling;

CREATE TABLE profiling.online_sales (
    order_id TEXT,
    order_date TEXT,
    sku TEXT,
    customer_id TEXT,
    qty TEXT,
    price TEXT,
    discount_amount TEXT,
    delivery_date TEXT,
    payment_type TEXT,
    promotion_id TEXT
);

CREATE TABLE profiling.store_sales (
    sale_id TEXT,
    sale_date TEXT,
    product_code TEXT,
    customer_code TEXT,
    quantity TEXT,
    selling_price TEXT,
    discount TEXT,
    store_code TEXT,
    payment_method TEXT,
    promotion_id TEXT
);

CREATE TABLE profiling.products (
    product_code TEXT,
    product_name TEXT,
    category TEXT,
    subcategory TEXT,
    brand TEXT,
    supplier TEXT,
    unit_cost TEXT
);

CREATE TABLE profiling.customers (
    customer_id TEXT,
    first_name TEXT,
    last_name TEXT,
    gender TEXT,
    city TEXT,
    province TEXT,
    customer_segment TEXT,
    loyalty_tier TEXT,
    registration_date TEXT
);

CREATE TABLE profiling.stores (
    store_code TEXT,
    store_name TEXT,
    city TEXT,
    province TEXT,
    region TEXT,
    store_type TEXT
);

CREATE TABLE profiling.inventory_daily (
    inventory_date TEXT,
    store_code TEXT,
    product_code TEXT,
    opening_stock TEXT,
    units_received TEXT,
    units_sold TEXT,
    closing_stock TEXT
);

--List profiling tables.
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'profiling'
ORDER BY table_name;

--Count seven source tables
SELECT 'online_sales' AS table_name, COUNT(*) AS row_count
FROM profiling.online_sales

UNION ALL
SELECT 'store_sales', COUNT(*)
FROM profiling.store_sales

UNION ALL
SELECT 'products', COUNT(*)
FROM profiling.products

UNION ALL
SELECT 'customers', COUNT(*)
FROM profiling.customers

UNION ALL
SELECT 'stores', COUNT(*)
FROM profiling.stores

UNION ALL
SELECT 'inventory_daily', COUNT(*)
FROM profiling.inventory_daily

UNION ALL
SELECT 'promotions', COUNT(*)
FROM profiling.promotions;

-- Profile missing sales fields.
SELECT
    'online_sales' AS dataset,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_date), '') IS NULL
    ) AS missing_transaction_date,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(customer_id), '') IS NULL
    ) AS missing_customer,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(promotion_id), '') IS NULL
    ) AS missing_promotion,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(delivery_date), '') IS NULL
    ) AS missing_delivery_date
FROM profiling.online_sales

UNION ALL

SELECT
    'store_sales',
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(sale_date), '') IS NULL
    ),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(customer_code), '') IS NULL
    ),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(promotion_id), '') IS NULL
    ),
    NULL::BIGINT
FROM profiling.store_sales;


--Find repeated Sale_ID values.
SELECT sale_id, COUNT(*) AS occurrences
FROM profiling.store_sales
GROUP BY sale_id
HAVING COUNT(*) > 1
ORDER BY sale_id;


--Count exact duplicate Store rows.
WITH duplicate_rows AS (
    SELECT
        TO_JSONB(s) AS source_row,
        COUNT(*) AS occurrences
    FROM profiling.store_sales s
    GROUP BY TO_JSONB(s)
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS duplicate_groups,
    COALESCE(SUM(occurrences - 1), 0) AS extra_duplicate_rows
FROM duplicate_rows;


--Count lowercase SKUs.
SELECT COUNT(*) AS lowercase_product_codes
FROM profiling.online_sales
WHERE sku <> UPPER(sku);

--Display lowercase SKU examples.
SELECT order_id, sku
FROM profiling.online_sales
WHERE sku <> UPPER(sku)
ORDER BY order_id;


--Profile category labels.
SELECT category, COUNT(*) AS product_count
FROM profiling.products
GROUP BY category
ORDER BY LOWER(BTRIM(category)), category;

--Profile subcategory labels.
SELECT subcategory, COUNT(*) AS product_count
FROM profiling.products
GROUP BY subcategory
ORDER BY LOWER(BTRIM(subcategory)), subcategory;


--Find customer city spaces.
SELECT
    customer_id,
    '[' || city || ']' AS original_city,
    BTRIM(city) AS proposed_clean_city
FROM profiling.customers
WHERE city <> BTRIM(city);


--Classify date text formats.
WITH source_dates AS (
    SELECT 'online.order_date' AS field, order_date AS date_text
    FROM profiling.online_sales

    UNION ALL
    SELECT 'online.delivery_date', delivery_date
    FROM profiling.online_sales

    UNION ALL
    SELECT 'store.sale_date', sale_date
    FROM profiling.store_sales

    UNION ALL
    SELECT 'customers.registration_date', registration_date
    FROM profiling.customers

    UNION ALL
    SELECT 'inventory.inventory_date', inventory_date
    FROM profiling.inventory_daily

    UNION ALL
    SELECT 'promotions.start_date', start_date
    FROM profiling.promotions

    UNION ALL
    SELECT 'promotions.end_date', end_date
    FROM profiling.promotions
),
classified_dates AS (
    SELECT
        field,
        CASE
            WHEN NULLIF(BTRIM(date_text), '') IS NULL
                THEN 'Missing'
            WHEN BTRIM(date_text) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                THEN 'YYYY-MM-DD'
            WHEN BTRIM(date_text) ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
                THEN 'Slash date: confirm day/month order'
            WHEN BTRIM(date_text) ~ '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$'
                THEN 'Hyphen date: confirm day/month order'
            ELSE 'Other format: inspect'
        END AS format_pattern
    FROM source_dates
)
SELECT field, format_pattern, COUNT(*) AS row_count
FROM classified_dates
GROUP BY field, format_pattern
ORDER BY field, format_pattern;


--Check candidate and composite business keys.
WITH source_keys AS (
    SELECT 'online_sales' AS dataset,
           NULLIF(BTRIM(order_id), '') AS business_key
    FROM profiling.online_sales

    UNION ALL
    SELECT 'store_sales', NULLIF(BTRIM(sale_id), '')
    FROM profiling.store_sales

    UNION ALL
    SELECT 'products', NULLIF(BTRIM(product_code), '')
    FROM profiling.products

    UNION ALL
    SELECT 'customers', NULLIF(BTRIM(customer_id), '')
    FROM profiling.customers

    UNION ALL
    SELECT 'stores', NULLIF(BTRIM(store_code), '')
    FROM profiling.stores

    UNION ALL
    SELECT 'promotions', NULLIF(BTRIM(promotion_id), '')
    FROM profiling.promotions

    UNION ALL
    SELECT
        'inventory_daily',
        CASE
            WHEN NULLIF(BTRIM(inventory_date), '') IS NULL
              OR NULLIF(BTRIM(store_code), '') IS NULL
              OR NULLIF(BTRIM(product_code), '') IS NULL
            THEN NULL
            ELSE JSONB_BUILD_ARRAY(
                BTRIM(inventory_date),
                BTRIM(store_code),
                BTRIM(product_code)
            )::TEXT
        END
    FROM profiling.inventory_daily
)
SELECT
    dataset,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE business_key IS NULL
    ) AS missing_keys,
    COUNT(DISTINCT business_key) AS distinct_keys,
    COUNT(business_key)
        - COUNT(DISTINCT business_key) AS extra_duplicate_keys
FROM source_keys
GROUP BY dataset
ORDER BY dataset;


--Validate source references against masters.
WITH source_references AS (
    SELECT 'online_sales' AS dataset,
           'product' AS reference_type,
           sku AS code
    FROM profiling.online_sales

    UNION ALL
    SELECT 'online_sales', 'customer', customer_id
    FROM profiling.online_sales

    UNION ALL
    SELECT 'online_sales', 'promotion', promotion_id
    FROM profiling.online_sales

    UNION ALL
    SELECT 'store_sales', 'product', product_code
    FROM profiling.store_sales

    UNION ALL
    SELECT 'store_sales', 'customer', customer_code
    FROM profiling.store_sales

    UNION ALL
    SELECT 'store_sales', 'store', store_code
    FROM profiling.store_sales

    UNION ALL
    SELECT 'store_sales', 'promotion', promotion_id
    FROM profiling.store_sales

    UNION ALL
    SELECT 'inventory_daily', 'product', product_code
    FROM profiling.inventory_daily

    UNION ALL
    SELECT 'inventory_daily', 'store', store_code
    FROM profiling.inventory_daily
)
SELECT *
FROM source_references;


WITH source_references AS (
    SELECT 'online_sales' AS dataset,
           'product' AS reference_type,
           sku AS code
    FROM profiling.online_sales

    UNION ALL
    SELECT 'online_sales', 'customer', customer_id
    FROM profiling.online_sales

    UNION ALL
    SELECT 'online_sales', 'promotion', promotion_id
    FROM profiling.online_sales

    UNION ALL
    SELECT 'store_sales', 'product', product_code
    FROM profiling.store_sales

    UNION ALL
    SELECT 'store_sales', 'customer', customer_code
    FROM profiling.store_sales

    UNION ALL
    SELECT 'store_sales', 'store', store_code
    FROM profiling.store_sales

    UNION ALL
    SELECT 'store_sales', 'promotion', promotion_id
    FROM profiling.store_sales

    UNION ALL
    SELECT 'inventory_daily', 'product', product_code
    FROM profiling.inventory_daily

    UNION ALL
    SELECT 'inventory_daily', 'store', store_code
    FROM profiling.inventory_daily
),
master_keys AS (
    SELECT 'product' AS reference_type,
           UPPER(BTRIM(product_code)) AS code
    FROM profiling.products

    UNION
    SELECT 'customer', UPPER(BTRIM(customer_id))
    FROM profiling.customers

    UNION
    SELECT 'store', UPPER(BTRIM(store_code))
    FROM profiling.stores

    UNION
    SELECT 'promotion', UPPER(BTRIM(promotion_id))
    FROM profiling.promotions
),
normalised_references AS (
    SELECT
        dataset,
        reference_type,
        NULLIF(UPPER(BTRIM(code)), '') AS code
    FROM source_references
)
SELECT
    s.dataset,
    s.reference_type,
    COUNT(*) AS checked_rows,
    COUNT(*) FILTER (
        WHERE s.code IS NULL
    ) AS missing_identifier,
    COUNT(*) FILTER (
        WHERE s.code IS NOT NULL
          AND m.code IS NULL
    ) AS unmatched_identifier
FROM normalised_references s
LEFT JOIN master_keys m
    ON s.reference_type = m.reference_type
   AND s.code = m.code
GROUP BY s.dataset, s.reference_type
ORDER BY s.dataset, s.reference_type;

--Profile missing values across all fields.
WITH source_rows AS (
    SELECT 'online_sales' AS dataset, TO_JSONB(t) AS data
    FROM profiling.online_sales t
    UNION ALL
    SELECT 'store_sales', TO_JSONB(t)
    FROM profiling.store_sales t
    UNION ALL
    SELECT 'products', TO_JSONB(t)
    FROM profiling.products t
    UNION ALL
    SELECT 'customers', TO_JSONB(t)
    FROM profiling.customers t
    UNION ALL
    SELECT 'stores', TO_JSONB(t)
    FROM profiling.stores t
    UNION ALL
    SELECT 'inventory_daily', TO_JSONB(t)
    FROM profiling.inventory_daily t
    UNION ALL
    SELECT 'promotions', TO_JSONB(t)
    FROM profiling.promotions t
)
SELECT
    dataset,
    field.key AS column_name,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(field.value), '') IS NULL
    ) AS missing_count
FROM source_rows
CROSS JOIN LATERAL JSONB_EACH_TEXT(data) AS field
GROUP BY dataset, field.key
HAVING COUNT(*) FILTER (
    WHERE NULLIF(BTRIM(field.value), '') IS NULL
) > 0
ORDER BY dataset, column_name;


-- Check numeric formats before conversion.
WITH numeric_fields AS (
    SELECT 'online_sales' AS dataset, f.*
    FROM profiling.online_sales s
    CROSS JOIN LATERAL (
        VALUES
            ('qty', s.qty, 'INTEGER'),
            ('price', s.price, 'NUMERIC'),
            ('discount_amount', s.discount_amount, 'NUMERIC')
    ) AS f(column_name, raw_value, intended_type)

    UNION ALL

    SELECT 'store_sales', f.*
    FROM profiling.store_sales s
    CROSS JOIN LATERAL (
        VALUES
            ('quantity', s.quantity, 'INTEGER'),
            ('selling_price', s.selling_price, 'NUMERIC'),
            ('discount', s.discount, 'NUMERIC')
    ) AS f(column_name, raw_value, intended_type)

    UNION ALL

    SELECT 'products', 'unit_cost', unit_cost, 'NUMERIC'
    FROM profiling.products

    UNION ALL

    SELECT 'inventory_daily', f.*
    FROM profiling.inventory_daily s
    CROSS JOIN LATERAL (
        VALUES
            ('opening_stock', s.opening_stock, 'INTEGER'),
            ('units_received', s.units_received, 'INTEGER'),
            ('units_sold', s.units_sold, 'INTEGER'),
            ('closing_stock', s.closing_stock, 'INTEGER')
    ) AS f(column_name, raw_value, intended_type)

    UNION ALL

    SELECT 'promotions', 'discount_percentage',
           discount_percentage, 'NUMERIC'
    FROM profiling.promotions
)
SELECT
    dataset,
    column_name,
    intended_type,
    COUNT(*) AS checked_rows,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(raw_value), '') IS NULL
    ) AS missing_values,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(raw_value), '') IS NOT NULL
          AND NOT (
              CASE
                  WHEN intended_type = 'INTEGER'
                      THEN BTRIM(raw_value) ~ '^[+-]?[0-9]+$'
                  ELSE BTRIM(raw_value)
                      ~ '^[+-]?[0-9]+([.][0-9]+)?$'
              END
          )
    ) AS unexpected_number_format
FROM numeric_fields
GROUP BY dataset, column_name, intended_type
ORDER BY dataset, column_name;


--Check exact duplicates across seven datasets.
WITH source_rows AS (
    SELECT 'online_sales' AS dataset, TO_JSONB(t) AS data
    FROM profiling.online_sales t
    UNION ALL
    SELECT 'store_sales', TO_JSONB(t)
    FROM profiling.store_sales t
    UNION ALL
    SELECT 'products', TO_JSONB(t)
    FROM profiling.products t
    UNION ALL
    SELECT 'customers', TO_JSONB(t)
    FROM profiling.customers t
    UNION ALL
    SELECT 'stores', TO_JSONB(t)
    FROM profiling.stores t
    UNION ALL
    SELECT 'inventory_daily', TO_JSONB(t)
    FROM profiling.inventory_daily t
    UNION ALL
    SELECT 'promotions', TO_JSONB(t)
    FROM profiling.promotions t
),
row_groups AS (
    SELECT dataset, data, COUNT(*) AS occurrences
    FROM source_rows
    GROUP BY dataset, data
)
SELECT
    dataset,
    COUNT(*) FILTER (
        WHERE occurrences > 1
    ) AS duplicate_groups,
    SUM(occurrences - 1) AS extra_duplicate_rows
FROM row_groups
GROUP BY dataset
ORDER BY dataset;


-- TASK 3: 
SELECT channel, transaction_id, product_code, COUNT(*) AS occurrences
FROM cleaned.sales
GROUP BY channel, transaction_id, product_code
HAVING COUNT(*) > 1;

-- TASK 3: Check raw inventory date-store-product grain.
SELECT COUNT(*) AS total_records,
 COUNT(DISTINCT (inventory_date, store_code, product_code)) AS unique_combinations,
 COUNT(*) - COUNT(DISTINCT (inventory_date, store_code, product_code)) AS extra_duplicate_rows
FROM profiling.inventory_daily;

--Display duplicate inventory combinations. 
SELECT inventory_date, store_code, product_code, COUNT(*) AS occurrences
FROM profiling.inventory_daily
GROUP BY inventory_date, store_code, product_code
HAVING COUNT(*) > 1;

--Show ten inventory rows and explain each column.
SELECT * FROM cleaned.inventory_daily
ORDER BY inventory_date, store_code, product_code
LIMIT 10;


-- TASK 4: DESIGN AND EXPLAIN THE DIMENSIONAL MODEL
-- IDENTIFY THE DIMENSIONS AND FACT TABLES
SELECT
    table_name,
    CASE
        WHEN table_name LIKE 'dim_%' THEN 'Dimension'
        WHEN table_name LIKE 'fact_%' THEN 'Fact'
    END AS table_role
FROM information_schema.tables
WHERE table_schema = 'warehouse'
  AND table_type = 'BASE TABLE'
  AND (
      table_name LIKE 'dim_%'
      OR table_name LIKE 'fact_%'
  )
ORDER BY table_role, table_name;


-- IDENTIFY THE MEASURES IN EACH FACT
-- These are the numeric business measures used for analysis.
SELECT
    table_name,
    column_name AS measure,
    data_type
FROM information_schema.columns
WHERE table_schema = 'warehouse'
  AND (
      (
          table_name = 'fact_sales'
          AND column_name IN (
              'quantity',
              'unit_selling_price',
              'gross_sales',
              'discount_amount',
              'net_sales',
              'estimated_cost',
              'estimated_profit'
          )
      )
      OR
      (
          table_name = 'fact_inventory_snapshot'
          AND column_name IN (
              'opening_stock',
              'units_received',
              'units_sold',
              'closing_stock'
          )
      )
  )
ORDER BY table_name, ordinal_position;


-- SHOW DIMENSION SURROGATE PRIMARY KEYS
SELECT
    tc.table_name,
    kcu.column_name AS surrogate_primary_key
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_catalog = kcu.constraint_catalog
 AND tc.constraint_schema = kcu.constraint_schema
 AND tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
 AND tc.table_name = kcu.table_name
WHERE tc.table_schema = 'warehouse'
  AND tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_name LIKE 'dim_%'
ORDER BY tc.table_name, kcu.ordinal_position;


-- EXPLAIN SURROGATE AND BUSINESS KEYS
-- Business keys come from the source systems.
-- Surrogate keys identify dimension members in the warehouse.
-- This query displays our documented design.

SELECT *
FROM (
    VALUES
        ('dim_date',      'date_key',      'full_date'),
        ('dim_product',   'product_key',   'product_code'),
        ('dim_customer',  'customer_key',  'customer_id'),
        ('dim_store',     'store_key',     'store_code'),
        ('dim_promotion', 'promotion_key', 'promotion_id')
) AS model(
    dimension,
    surrogate_key,
    business_key
);


--SHOW UNKNOWN AND NON-APPLICABLE DATE MEMBERS
SELECT
    date_key,
    full_date,
    date_status
FROM warehouse.dim_date
WHERE date_key IN (0, -1)
ORDER BY date_key;


--SHOW UNKNOWN PRODUCT

SELECT
    product_key,
    product_code,
    product_name
FROM warehouse.dim_product
WHERE product_code = 'UNKNOWN';


--SHOW UNKNOWN CUSTOMER
SELECT
    customer_key,
    customer_id,
    first_name,
    last_name
FROM warehouse.dim_customer
WHERE customer_id = 'UNKNOWN';


--SHOW NO PROMOTION AND UNKNOWN PROMOTION

SELECT
    promotion_key,
    promotion_id,
    promotion_name
FROM warehouse.dim_promotion
WHERE promotion_id IN ('NO_PROMOTION', 'UNKNOWN')
ORDER BY promotion_key;


-- SHOW UNKNOWN AND ONLINE STORE MEMBERS
-- Online sales have no physical Store_Code.

SELECT
    store_key,
    store_code,
    store_name,
    store_type
FROM warehouse.dim_store
WHERE store_code IN ('UNKNOWN', 'ONLINE')
ORDER BY store_key;


-- DEMONSTRATE ONLINE STORE REPRESENTATION
-- Physical-store sales use their actual store members.

SELECT
    f.channel,
    s.store_code,
    s.store_name,
    COUNT(*) AS sales_lines
FROM warehouse.fact_sales f
JOIN warehouse.dim_store s
  ON f.store_key = s.store_key
GROUP BY
    f.channel,
    s.store_code,
    s.store_name
ORDER BY f.channel, s.store_code;


-- SHOW PRIMARY KEYS FOR DIMENSIONS AND FACTS
-- Inventory should have a composite date-product-store key.

SELECT
    tc.table_name,
    STRING_AGG(
        kcu.column_name::TEXT,
        ', ' ORDER BY kcu.ordinal_position
    ) AS primary_key_columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_catalog = kcu.constraint_catalog
 AND tc.constraint_schema = kcu.constraint_schema
 AND tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
 AND tc.table_name = kcu.table_name
WHERE tc.table_schema = 'warehouse'
  AND tc.constraint_type = 'PRIMARY KEY'
GROUP BY tc.table_name
ORDER BY tc.table_name;


-- SHOW FACT-TO-DIMENSION FOREIGN KEYS(6)
-- Includes both order and delivery Date roles in Sales.

SELECT
    child.relname AS fact_table,
    child_col.attname AS foreign_key,
    parent.relname AS dimension_table,
    parent_col.attname AS referenced_key
FROM pg_constraint c
JOIN pg_class child
  ON child.oid = c.conrelid
JOIN pg_namespace child_schema
  ON child_schema.oid = child.relnamespace
JOIN pg_class parent
  ON parent.oid = c.confrelid
CROSS JOIN LATERAL
    UNNEST(c.conkey, c.confkey)
    AS key_pair(child_attnum, parent_attnum)
JOIN pg_attribute child_col
  ON child_col.attrelid = child.oid
 AND child_col.attnum = key_pair.child_attnum
JOIN pg_attribute parent_col
  ON parent_col.attrelid = parent.oid
 AND parent_col.attnum = key_pair.parent_attnum
WHERE c.contype = 'f'
  AND child_schema.nspname = 'warehouse'
  AND child.relname IN (
      'fact_sales',
      'fact_inventory_snapshot'
  )
ORDER BY fact_table, foreign_key;


-- CLASSIFY MEASURES
-- This query displays the documented aggregation rules.

SELECT *
FROM (
    VALUES
        (
            'Sales quantity and monetary totals',
            'Additive',
            'Sum across relevant sales dimensions'
        ),
        (
            'Inventory receipts and units sold',
            'Additive daily flows',
            'Sum across non-overlapping daily periods'
        ),
        (
            'Opening and closing stock',
            'Semi-additive',
            'Sum across products/stores for one date, not across dates'
        ),
        (
            'Unit selling price',
            'Non-additive',
            'Do not sum prices; calculate an appropriate average'
        ),
        (
            'Average transaction value',
            'Non-additive',
            'Total transaction revenue divided by transaction count'
        ),
        (
            'Estimated margin percentage',
            'Non-additive',
            'Total estimated profit divided by total net sales times 100'
        )
) AS rules(
    measure,
    aggregation_type,
    reporting_rule
);

--TASK 5: Create staging schema
--Copy raw Online into staging with load metadata.

CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE staging.online_sales AS
SELECT *, CURRENT_TIMESTAMP AS loaded_at,
       'shopsmart_initial_01'::TEXT AS batch_id
FROM profiling.online_sales;

CREATE TABLE staging.store_sales AS
SELECT *, CURRENT_TIMESTAMP AS loaded_at,
       'shopsmart_initial_01'::TEXT AS batch_id
FROM profiling.store_sales;

CREATE TABLE staging.products AS
SELECT *, CURRENT_TIMESTAMP AS loaded_at,
       'shopsmart_initial_01'::TEXT AS batch_id
FROM profiling.products;

CREATE TABLE staging.customers AS
SELECT *, CURRENT_TIMESTAMP AS loaded_at,
       'shopsmart_initial_01'::TEXT AS batch_id
FROM profiling.customers;

CREATE TABLE staging.stores AS
SELECT *, CURRENT_TIMESTAMP AS loaded_at,
       'shopsmart_initial_01'::TEXT AS batch_id
FROM profiling.stores;

CREATE TABLE staging.inventory_daily AS
SELECT *, CURRENT_TIMESTAMP AS loaded_at,
       'shopsmart_initial_01'::TEXT AS batch_id
FROM profiling.inventory_daily;

CREATE TABLE staging.promotions AS
SELECT *, CURRENT_TIMESTAMP AS loaded_at,
       'shopsmart_initial_01'::TEXT AS batch_id
FROM profiling.promotions;


-- Validate staging row counts.
SELECT 'online_sales' AS table_name, COUNT(*) AS row_count
FROM staging.online_sales
UNION ALL
SELECT 'store_sales', COUNT(*) FROM staging.store_sales
UNION ALL
SELECT 'products', COUNT(*) FROM staging.products
UNION ALL
SELECT 'customers', COUNT(*) FROM staging.customers
UNION ALL
SELECT 'stores', COUNT(*) FROM staging.stores
UNION ALL
SELECT 'inventory_daily', COUNT(*) FROM staging.inventory_daily
UNION ALL
SELECT 'promotions', COUNT(*) FROM staging.promotions
ORDER BY table_name;



--Create cleaned schema.
CREATE SCHEMA IF NOT EXISTS cleaned;


-- TASK 6: Create cleaned schema
CREATE OR REPLACE VIEW cleaned.products AS
SELECT
    UPPER(BTRIM(product_code)) AS product_code,
    BTRIM(product_name) AS product_name,
    INITCAP(BTRIM(category)) AS category,
    INITCAP(BTRIM(subcategory)) AS subcategory,
    BTRIM(brand) AS brand,
    BTRIM(supplier) AS supplier,
    BTRIM(unit_cost)::NUMERIC(12,2) AS unit_cost
FROM staging.products;

CREATE OR REPLACE VIEW cleaned.customers AS
SELECT
    UPPER(BTRIM(customer_id)) AS customer_id,
    BTRIM(first_name) AS first_name,
    BTRIM(last_name) AS last_name,
    INITCAP(BTRIM(gender)) AS gender,
    BTRIM(city) AS city,
    BTRIM(province) AS province,
    INITCAP(BTRIM(customer_segment)) AS customer_segment,
    INITCAP(BTRIM(loyalty_tier)) AS loyalty_tier,
    NULLIF(BTRIM(registration_date), '')::DATE
        AS registration_date
FROM staging.customers;


--Clean Customer master.
CREATE OR REPLACE VIEW cleaned.stores AS
SELECT
    UPPER(BTRIM(store_code)) AS store_code,
    BTRIM(store_name) AS store_name,
    BTRIM(city) AS city,
    BTRIM(province) AS province,
    INITCAP(BTRIM(region)) AS region,
    INITCAP(BTRIM(store_type)) AS store_type
FROM staging.stores;


--Clean Promotion master.
CREATE OR REPLACE VIEW cleaned.promotions AS
SELECT
    UPPER(BTRIM(promotion_id)) AS promotion_id,
    BTRIM(promotion_name) AS promotion_name,
    INITCAP(BTRIM(promotion_type)) AS promotion_type,
    NULLIF(BTRIM(start_date), '')::DATE AS start_date,
    NULLIF(BTRIM(end_date), '')::DATE AS end_date,
    BTRIM(discount_percentage)::NUMERIC(5,2)
        AS discount_percentage
FROM staging.promotions;


--Validate cleaned master counts.
SELECT 'products' AS dataset, COUNT(*) AS row_count
FROM cleaned.products
UNION ALL
SELECT 'customers', COUNT(*) FROM cleaned.customers
UNION ALL
SELECT 'stores', COUNT(*) FROM cleaned.stores
UNION ALL
SELECT 'promotions', COUNT(*) FROM cleaned.promotions;



-- Category labels should now be consistent.
SELECT category, COUNT(*) AS product_count
FROM cleaned.products
GROUP BY category
ORDER BY category;


-- Check trimmed customer cities.
SELECT COUNT(*) AS cities_with_surrounding_spaces
FROM cleaned.customers
WHERE city <> BTRIM(city);



-- Evaluates the date and numeric conversions.
SELECT * FROM cleaned.promotions ORDER BY promotion_id;


--Clean Online sales and missing identifiers.
CREATE OR REPLACE VIEW cleaned.online_sales AS
SELECT
    BTRIM(order_id) AS transaction_id,
    NULLIF(BTRIM(order_date), '')::DATE AS order_date,
    UPPER(BTRIM(sku)) AS product_code,
    COALESCE(
        NULLIF(UPPER(BTRIM(customer_id)), ''),
        'UNKNOWN'
    ) AS customer_id,
    BTRIM(qty)::INTEGER AS quantity,
    BTRIM(price)::NUMERIC(12,2) AS unit_selling_price,
    BTRIM(discount_amount)::NUMERIC(12,2) AS discount_amount,
    NULLIF(BTRIM(delivery_date), '')::DATE AS delivery_date,
    BTRIM(payment_type) AS payment_method,
    COALESCE(
        NULLIF(UPPER(BTRIM(promotion_id)), ''),
        'NO_PROMOTION'
    ) AS promotion_id,
    'ONLINE'::TEXT AS store_code,
    'Online'::TEXT AS channel
FROM staging.online_sales;


--Clean Store sales and remove exact duplicate copies.
CREATE OR REPLACE VIEW cleaned.store_sales AS
WITH distinct_source_rows AS (
    SELECT DISTINCT
        sale_id, sale_date, product_code, customer_code,
        quantity, selling_price, discount, store_code,
        payment_method, promotion_id
    FROM staging.store_sales
)
SELECT
    BTRIM(sale_id) AS transaction_id,
    NULLIF(BTRIM(sale_date), '')::DATE AS order_date,
    UPPER(BTRIM(product_code)) AS product_code,
    COALESCE(
        NULLIF(UPPER(BTRIM(customer_code)), ''),
        'UNKNOWN'
    ) AS customer_id,
    BTRIM(quantity)::INTEGER AS quantity,
    BTRIM(selling_price)::NUMERIC(12,2) AS unit_selling_price,
    BTRIM(discount)::NUMERIC(12,2) AS discount_amount,
    NULL::DATE AS delivery_date,
    BTRIM(payment_method) AS payment_method,
    COALESCE(
        NULLIF(UPPER(BTRIM(promotion_id)), ''),
        'NO_PROMOTION'
    ) AS promotion_id,
    UPPER(BTRIM(store_code)) AS store_code,
    'Store'::TEXT AS channel
FROM distinct_source_rows;


-- Integrate cleaned sales channels.
CREATE OR REPLACE VIEW cleaned.sales AS
SELECT * FROM cleaned.online_sales
UNION ALL
SELECT * FROM cleaned.store_sales;


-- Clean daily inventory.
CREATE OR REPLACE VIEW cleaned.inventory_daily AS
SELECT
    NULLIF(BTRIM(inventory_date), '')::DATE AS inventory_date,
    UPPER(BTRIM(store_code)) AS store_code,
    UPPER(BTRIM(product_code)) AS product_code,
    BTRIM(opening_stock)::INTEGER AS opening_stock,
    BTRIM(units_received)::INTEGER AS units_received,
    BTRIM(units_sold)::INTEGER AS units_sold,
    BTRIM(closing_stock)::INTEGER AS closing_stock
FROM staging.inventory_daily;


-- Validate cleaned transaction counts.
SELECT 'online_sales' AS dataset, COUNT(*) AS row_count
FROM cleaned.online_sales
UNION ALL
SELECT 'store_sales', COUNT(*) FROM cleaned.store_sales
UNION ALL
SELECT 'combined_sales', COUNT(*) FROM cleaned.sales
UNION ALL
SELECT 'inventory_daily', COUNT(*) FROM cleaned.inventory_daily;



-- Forces evaluation of sales dates and numeric conversions.
SELECT
    channel,
    MIN(order_date) AS earliest_sale,
    MAX(order_date) AS latest_sale,
    MIN(delivery_date) AS earliest_delivery,
    MAX(delivery_date) AS latest_delivery,
    SUM(quantity) AS total_quantity,
    SUM(discount_amount) AS total_discount,
    MIN(unit_selling_price) AS minimum_price,
    MAX(unit_selling_price) AS maximum_price
FROM cleaned.sales
GROUP BY channel
ORDER BY channel;


--Check inventory date range and arithmetic.
SELECT
    MIN(inventory_date) AS earliest_inventory_date,
    MAX(inventory_date) AS latest_inventory_date,
    COUNT(*) FILTER (
        WHERE closing_stock <>
              opening_stock + units_received - units_sold
    ) AS stock_balance_mismatches
FROM cleaned.inventory_daily;


--Display stock balance discrepancies.
SELECT
    inventory_date,
    store_code,
    product_code,
    opening_stock,
    units_received,
    units_sold,
    closing_stock,
    opening_stock + units_received - units_sold
        AS calculated_closing_stock,
    closing_stock -
        (opening_stock + units_received - units_sold)
        AS balance_difference
FROM cleaned.inventory_daily
WHERE closing_stock <>
      opening_stock + units_received - units_sold
ORDER BY inventory_date, store_code, product_code
LIMIT 20;

--Test zero-capped balance explanation.
SELECT
    COUNT(*) FILTER (
        WHERE closing_stock <>
              opening_stock + units_received - units_sold
    ) AS total_mismatches,

    COUNT(*) FILTER (
        WHERE opening_stock + units_received - units_sold < 0
          AND closing_stock = 0
    ) AS negative_balance_capped_at_zero,

    COUNT(*) FILTER (
        WHERE closing_stock <>
              GREATEST(
                  opening_stock + units_received - units_sold,
                  0
              )
    ) AS mismatches_after_zero_cap
FROM cleaned.inventory_daily;


--Create inventory exception view.
CREATE OR REPLACE VIEW cleaned.inventory_exceptions AS
SELECT
    *,
    opening_stock + units_received - units_sold
        AS calculated_closing_stock,
    closing_stock -
        (opening_stock + units_received - units_sold)
        AS balance_difference,
    'Units sold exceed opening stock plus receipts'::TEXT
        AS issue
FROM cleaned.inventory_daily
WHERE closing_stock <>
      opening_stock + units_received - units_sold;

SELECT COUNT(*) AS exception_rows
FROM cleaned.inventory_exceptions;


--Count inventory exceptions.
CREATE OR REPLACE VIEW cleaned.sales_measures AS
WITH measures AS (
    SELECT
        s.*,
        p.unit_cost,
        ROUND(
            s.quantity * s.unit_selling_price, 2
        ) AS gross_sales,
        ROUND(
            s.quantity * s.unit_selling_price
            - s.discount_amount, 2
        ) AS net_sales,
        ROUND(
            s.quantity * p.unit_cost, 2
        ) AS estimated_cost
    FROM cleaned.sales s
    LEFT JOIN cleaned.products p
        ON s.product_code = p.product_code
)
SELECT
    *,
    ROUND(net_sales - estimated_cost, 2)
        AS estimated_profit
FROM measures;


--Validate measures by channel.
--Derive gross net cost and estimated profit.
SELECT
    channel,
    COUNT(*) AS sales_rows,
    COUNT(*) FILTER (
        WHERE unit_cost IS NULL
    ) AS missing_product_cost,
    SUM(quantity) AS total_quantity,
    SUM(gross_sales) AS gross_sales,
    SUM(discount_amount) AS discounts,
    SUM(net_sales) AS net_sales,
    SUM(estimated_cost) AS estimated_cost,
    SUM(estimated_profit) AS estimated_profit
FROM cleaned.sales_measures
GROUP BY channel
ORDER BY channel;


--Check numeric business rules.
SELECT
    COUNT(*) FILTER (
        WHERE quantity <= 0
    ) AS nonpositive_quantity,
    COUNT(*) FILTER (
        WHERE unit_selling_price < 0
    ) AS negative_price,
    COUNT(*) FILTER (
        WHERE discount_amount < 0
    ) AS negative_discount,
    COUNT(*) FILTER (
        WHERE discount_amount > gross_sales
    ) AS discount_exceeds_gross_sales,
    COUNT(*) FILTER (
        WHERE estimated_cost < 0
    ) AS negative_estimated_cost
FROM cleaned.sales_measures;


-- TASK 7: Create warehouse schema
-- Create warehouse schema.
CREATE SCHEMA IF NOT EXISTS warehouse;


--Define Date dimension and calendar attributes.
CREATE TABLE IF NOT EXISTS warehouse.dim_date (
    date_key INTEGER GENERATED BY DEFAULT AS IDENTITY
        PRIMARY KEY,
    full_date DATE UNIQUE,
    date_status TEXT NOT NULL,
    weekday TEXT,
    weekday_num INTEGER,
    day_month INTEGER,
    day_of_year INTEGER,
    week_of_year INTEGER,
    iso_year INTEGER,
    month_num INTEGER,
    month_name TEXT,
    quarter_num INTEGER,
    year_num INTEGER
);

--Insert Unknown and Not Applicable dates
INSERT INTO warehouse.dim_date (
    date_key, full_date, date_status
)
VALUES
    (0, NULL, 'Unknown'),
    (-1, NULL, 'Not Applicable')
ON CONFLICT (date_key) DO NOTHING;

--Generate calendar dates from source coverage.
WITH source_dates AS (
    SELECT order_date AS source_date FROM cleaned.sales
    UNION ALL
    SELECT delivery_date FROM cleaned.sales
    UNION ALL
    SELECT inventory_date FROM cleaned.inventory_daily
    UNION ALL
    SELECT registration_date FROM cleaned.customers
    UNION ALL
    SELECT start_date FROM cleaned.promotions
    UNION ALL
    SELECT end_date FROM cleaned.promotions
),
bounds AS (
    SELECT
        DATE_TRUNC('year', MIN(source_date))::DATE AS start_date,
        (
            DATE_TRUNC('year', MAX(source_date))
            + INTERVAL '1 year'
            - INTERVAL '1 day'
        )::DATE AS end_date
    FROM source_dates
),
calendar AS (
    SELECT generated_date::DATE AS full_date
    FROM bounds
    CROSS JOIN LATERAL GENERATE_SERIES(
        start_date::TIMESTAMP,
        end_date::TIMESTAMP,
        INTERVAL '1 day'
    ) AS dates(generated_date)
)
INSERT INTO warehouse.dim_date (
    full_date, date_status,
    weekday, weekday_num, day_month, day_of_year,
    week_of_year, iso_year,
    month_num, month_name, quarter_num, year_num
)
SELECT
    full_date,
    'Known',
    TO_CHAR(full_date, 'FMDay'),
    EXTRACT(ISODOW FROM full_date)::INTEGER,
    EXTRACT(DAY FROM full_date)::INTEGER,
    EXTRACT(DOY FROM full_date)::INTEGER,
    EXTRACT(WEEK FROM full_date)::INTEGER,
    EXTRACT(ISOYEAR FROM full_date)::INTEGER,
    EXTRACT(MONTH FROM full_date)::INTEGER,
    TO_CHAR(full_date, 'FMMonth'),
    EXTRACT(QUARTER FROM full_date)::INTEGER,
    EXTRACT(YEAR FROM full_date)::INTEGER
FROM calendar
ORDER BY full_date
ON CONFLICT (full_date) DO NOTHING;

-- Validate Date range and counts.
SELECT
    MIN(full_date) AS first_date,
    MAX(full_date) AS last_date, 
    COUNT(full_date) AS calendar_rows,
    MAX(full_date) - MIN(full_date) + 1 AS expected_calendar_rows,
    COUNT(*) FILTER (
        WHERE full_date IS NULL
    ) AS special_members
FROM warehouse.dim_date;


--Inspect Date members
SELECT *
FROM warehouse.dim_date
ORDER BY date_key
LIMIT 12;

--task 8: Define Product dimension
CREATE TABLE IF NOT EXISTS warehouse.dim_product (
    product_key INTEGER GENERATED BY DEFAULT AS IDENTITY
        PRIMARY KEY,
    product_code TEXT NOT NULL UNIQUE,
    product_name TEXT NOT NULL,
    category TEXT,
    subcategory TEXT,
    brand TEXT,
    supplier TEXT,
    unit_cost NUMERIC(12,2)
);


-- Define Customer dimension.
CREATE TABLE IF NOT EXISTS warehouse.dim_customer (
    customer_key INTEGER GENERATED BY DEFAULT AS IDENTITY
        PRIMARY KEY,
    customer_id TEXT NOT NULL UNIQUE,
    first_name TEXT,
    last_name TEXT,
    gender TEXT,
    city TEXT,
    province TEXT,
    customer_segment TEXT,
    loyalty_tier TEXT,
    registration_date DATE
);


--Define Store dimension.
CREATE TABLE IF NOT EXISTS warehouse.dim_store (
    store_key INTEGER GENERATED BY DEFAULT AS IDENTITY
        PRIMARY KEY,
    store_code TEXT NOT NULL UNIQUE,
    store_name TEXT NOT NULL,
    city TEXT,
    province TEXT,
    region TEXT,
    store_type TEXT
);


--Define Promotion dimension.
CREATE TABLE IF NOT EXISTS warehouse.dim_promotion (
    promotion_key INTEGER GENERATED BY DEFAULT AS IDENTITY
        PRIMARY KEY,
    promotion_id TEXT NOT NULL UNIQUE,
    promotion_name TEXT NOT NULL,
    promotion_type TEXT,
    start_date DATE,
    end_date DATE,
    discount_percentage NUMERIC(5,2)
);


--Insert Unknown Product.
INSERT INTO warehouse.dim_product (
    product_key, product_code, product_name, category
)
VALUES (0, 'UNKNOWN', 'Unknown Product', 'Unknown')
ON CONFLICT (product_code) DO NOTHING;

INSERT INTO warehouse.dim_customer (
    customer_key, customer_id, first_name, last_name,
    gender, city, province, customer_segment, loyalty_tier
)
VALUES (
    0, 'UNKNOWN', 'Unknown', 'Customer',
    'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown'
)
ON CONFLICT (customer_id) DO NOTHING;


--Insert Unknown Customer.
INSERT INTO warehouse.dim_store (
    store_key, store_code, store_name,
    city, province, region, store_type
)
VALUES
    (0, 'UNKNOWN', 'Unknown Store',
     'Unknown', 'Unknown', 'Unknown', 'Unknown'),
    (-1, 'ONLINE', 'ShopSmart Online',
     'Not Applicable', 'Not Applicable',
     'Not Applicable', 'Online')
ON CONFLICT (store_code) DO NOTHING;


--Insert Unknown and Online stores.
INSERT INTO warehouse.dim_promotion (
    promotion_key, promotion_id, promotion_name,
    promotion_type, discount_percentage
)
VALUES
    (0, 'NO_PROMOTION', 'No Promotion', 'None', 0),
    (-1, 'UNKNOWN', 'Unknown Promotion', 'Unknown', NULL)
ON CONFLICT (promotion_id) DO NOTHING;


--Insert No Promotion and Unknown Promotion.
INSERT INTO warehouse.dim_product (
    product_code, product_name, category, subcategory,
    brand, supplier, unit_cost
)
SELECT
    product_code, product_name, category, subcategory,
    brand, supplier, unit_cost
FROM cleaned.products
ORDER BY product_code
ON CONFLICT (product_code) DO NOTHING;


INSERT INTO warehouse.dim_customer (
    customer_id, first_name, last_name, gender,
    city, province, customer_segment, loyalty_tier,
    registration_date
)
SELECT
    customer_id, first_name, last_name, gender,
    city, province, customer_segment, loyalty_tier,
    registration_date
FROM cleaned.customers
ORDER BY customer_id
ON CONFLICT (customer_id) DO NOTHING;

INSERT INTO warehouse.dim_store (
    store_code, store_name, city, province, region, store_type
)
SELECT
    store_code, store_name, city, province, region, store_type
FROM cleaned.stores
ORDER BY store_code
ON CONFLICT (store_code) DO NOTHING;

INSERT INTO warehouse.dim_promotion (
    promotion_id, promotion_name, promotion_type,
    start_date, end_date, discount_percentage
)
SELECT
    promotion_id, promotion_name, promotion_type,
    start_date, end_date, discount_percentage
FROM cleaned.promotions
ORDER BY promotion_id
ON CONFLICT (promotion_id) DO NOTHING;



SELECT 'dim_date' AS dimension, COUNT(*) AS row_count
FROM warehouse.dim_date
UNION ALL
SELECT 'dim_product', COUNT(*) FROM warehouse.dim_product
UNION ALL
SELECT 'dim_customer', COUNT(*) FROM warehouse.dim_customer
UNION ALL
SELECT 'dim_store', COUNT(*) FROM warehouse.dim_store
UNION ALL
SELECT 'dim_promotion', COUNT(*) FROM warehouse.dim_promotion
ORDER BY dimension;

--task 9

CREATE TABLE IF NOT EXISTS warehouse.fact_sales (
    sales_key BIGINT GENERATED BY DEFAULT AS IDENTITY
        PRIMARY KEY,
    transaction_id TEXT NOT NULL,
    channel TEXT NOT NULL
        CHECK (channel IN ('Online', 'Store')),

    order_date_key INTEGER NOT NULL
        REFERENCES warehouse.dim_date(date_key),
    delivery_date_key INTEGER NOT NULL
        REFERENCES warehouse.dim_date(date_key),
    product_key INTEGER NOT NULL
        REFERENCES warehouse.dim_product(product_key),
    customer_key INTEGER NOT NULL
        REFERENCES warehouse.dim_customer(customer_key),
    store_key INTEGER NOT NULL
        REFERENCES warehouse.dim_store(store_key),
    promotion_key INTEGER NOT NULL
        REFERENCES warehouse.dim_promotion(promotion_key),

    payment_method TEXT,
    quantity INTEGER NOT NULL,
    unit_selling_price NUMERIC(12,2) NOT NULL,
    gross_sales NUMERIC(14,2) NOT NULL,
    discount_amount NUMERIC(14,2) NOT NULL,
    net_sales NUMERIC(14,2) NOT NULL,
    estimated_cost NUMERIC(14,2) NOT NULL,
    estimated_profit NUMERIC(14,2) NOT NULL,

    UNIQUE (channel, transaction_id, product_key)
);

CREATE TABLE IF NOT EXISTS warehouse.fact_inventory_snapshot (
    date_key INTEGER NOT NULL
        REFERENCES warehouse.dim_date(date_key),
    product_key INTEGER NOT NULL
        REFERENCES warehouse.dim_product(product_key),
    store_key INTEGER NOT NULL
        REFERENCES warehouse.dim_store(store_key),

    opening_stock INTEGER NOT NULL,
    units_received INTEGER NOT NULL,
    units_sold INTEGER NOT NULL,
    closing_stock INTEGER NOT NULL,
    stock_balance_exception BOOLEAN NOT NULL,

    PRIMARY KEY (date_key, product_key, store_key)
);


INSERT INTO warehouse.fact_sales (
    transaction_id, channel,
    order_date_key, delivery_date_key,
    product_key, customer_key, store_key, promotion_key,
    payment_method, quantity, unit_selling_price,
    gross_sales, discount_amount, net_sales,
    estimated_cost, estimated_profit
)
SELECT
    s.transaction_id,
    s.channel,

    CASE
        WHEN s.order_date IS NULL THEN 0
        ELSE od.date_key
    END,

    CASE
        WHEN s.channel = 'Store' THEN -1
        WHEN s.delivery_date IS NULL THEN 0
        ELSE dd.date_key
    END,

    p.product_key,
    c.customer_key,
    st.store_key,
    pr.promotion_key,
    s.payment_method,
    s.quantity,
    s.unit_selling_price,
    s.gross_sales,
    s.discount_amount,
    s.net_sales,
    s.estimated_cost,
    s.estimated_profit

FROM cleaned.sales_measures s
LEFT JOIN warehouse.dim_date od
    ON s.order_date = od.full_date
LEFT JOIN warehouse.dim_date dd
    ON s.delivery_date = dd.full_date
LEFT JOIN warehouse.dim_product p
    ON s.product_code = p.product_code
LEFT JOIN warehouse.dim_customer c
    ON s.customer_id = c.customer_id
LEFT JOIN warehouse.dim_store st
    ON s.store_code = st.store_code
LEFT JOIN warehouse.dim_promotion pr
    ON s.promotion_id = pr.promotion_id

ON CONFLICT (channel, transaction_id, product_key)
DO NOTHING;


INSERT INTO warehouse.fact_inventory_snapshot (
    date_key, product_key, store_key,
    opening_stock, units_received, units_sold, closing_stock,
    stock_balance_exception
)
SELECT
    d.date_key,
    p.product_key,
    st.store_key,
    i.opening_stock,
    i.units_received,
    i.units_sold,
    i.closing_stock,
    i.closing_stock <>
        i.opening_stock + i.units_received - i.units_sold
FROM cleaned.inventory_daily i
LEFT JOIN warehouse.dim_date d
    ON i.inventory_date = d.full_date
LEFT JOIN warehouse.dim_product p
    ON i.product_code = p.product_code
LEFT JOIN warehouse.dim_store st
    ON i.store_code = st.store_code

ON CONFLICT (date_key, product_key, store_key)
DO NOTHING;


SELECT channel, COUNT(*) AS sales_rows
FROM warehouse.fact_sales
GROUP BY channel
ORDER BY channel;


SELECT
    COUNT(*) AS inventory_rows,
    COUNT(*) FILTER (
        WHERE stock_balance_exception
    ) AS flagged_inventory_rows
FROM warehouse.fact_inventory_snapshot;



SELECT
    COUNT(*) FILTER (
        WHERE order_date_key = 0
    ) AS unknown_order_dates,
    COUNT(*) FILTER (
        WHERE channel = 'Online' AND delivery_date_key = 0
    ) AS unknown_online_delivery_dates,
    COUNT(*) FILTER (
        WHERE channel = 'Store' AND delivery_date_key = -1
    ) AS store_delivery_not_applicable
FROM warehouse.fact_sales;


--Task 10
WITH distinct_store AS (
    SELECT DISTINCT
        sale_id, sale_date, product_code, customer_code,
        quantity, selling_price, discount, store_code,
        payment_method, promotion_id
    FROM staging.store_sales
),
source_sales AS (
    SELECT
        'Online'::TEXT AS channel,
        BTRIM(qty)::INTEGER AS quantity,
        BTRIM(price)::NUMERIC AS unit_price,
        BTRIM(discount_amount)::NUMERIC AS discount
    FROM staging.online_sales

    UNION ALL

    SELECT
        'Store',
        BTRIM(quantity)::INTEGER,
        BTRIM(selling_price)::NUMERIC,
        BTRIM(discount)::NUMERIC
    FROM distinct_store
),
source_totals AS (
    SELECT
        channel,
        COUNT(*) AS rows,
        SUM(quantity) AS quantity,
        SUM(ROUND(quantity * unit_price, 2)) AS gross_sales,
        SUM(discount) AS discount,
        SUM(ROUND(quantity * unit_price - discount, 2))
            AS net_sales
    FROM source_sales
    GROUP BY channel
),
warehouse_totals AS (
    SELECT
        channel,
        COUNT(*) AS rows,
        SUM(quantity) AS quantity,
        SUM(gross_sales) AS gross_sales,
        SUM(discount_amount) AS discount,
        SUM(net_sales) AS net_sales
    FROM warehouse.fact_sales
    GROUP BY channel
)
SELECT
    COALESCE(s.channel, w.channel) AS channel,
    s.rows AS expected_source_rows,
    w.rows AS warehouse_rows,
    w.rows - s.rows AS row_difference,
    w.quantity - s.quantity AS quantity_difference,
    w.gross_sales - s.gross_sales AS gross_sales_difference,
    w.discount - s.discount AS discount_difference,
    w.net_sales - s.net_sales AS net_sales_difference
FROM source_totals s
FULL JOIN warehouse_totals w
    ON s.channel = w.channel
ORDER BY channel;


SELECT COUNT(*) AS sales_with_invalid_dimension_keys
FROM warehouse.fact_sales f
LEFT JOIN warehouse.dim_date od
    ON f.order_date_key = od.date_key
LEFT JOIN warehouse.dim_date dd
    ON f.delivery_date_key = dd.date_key
LEFT JOIN warehouse.dim_product p
    ON f.product_key = p.product_key
LEFT JOIN warehouse.dim_customer c
    ON f.customer_key = c.customer_key
LEFT JOIN warehouse.dim_store s
    ON f.store_key = s.store_key
LEFT JOIN warehouse.dim_promotion pr
    ON f.promotion_key = pr.promotion_key
WHERE od.date_key IS NULL
   OR dd.date_key IS NULL
   OR p.product_key IS NULL
   OR c.customer_key IS NULL
   OR s.store_key IS NULL
   OR pr.promotion_key IS NULL;


SELECT COUNT(*) AS inventory_with_invalid_dimension_keys
FROM warehouse.fact_inventory_snapshot f
LEFT JOIN warehouse.dim_date d
    ON f.date_key = d.date_key
LEFT JOIN warehouse.dim_product p
    ON f.product_key = p.product_key
LEFT JOIN warehouse.dim_store s
    ON f.store_key = s.store_key
WHERE d.date_key IS NULL
   OR p.product_key IS NULL
   OR s.store_key IS NULL;

WITH source_inventory AS (
    SELECT
        BTRIM(inventory_date)::DATE AS inventory_date,
        UPPER(BTRIM(product_code)) AS product_code,
        UPPER(BTRIM(store_code)) AS store_code,
        BTRIM(opening_stock)::INTEGER AS opening_stock,
        BTRIM(units_received)::INTEGER AS units_received,
        BTRIM(units_sold)::INTEGER AS units_sold,
        BTRIM(closing_stock)::INTEGER AS closing_stock
    FROM staging.inventory_daily
),
warehouse_inventory AS (
    SELECT
        d.full_date AS inventory_date,
        p.product_code,
        st.store_code,
        f.opening_stock,
        f.units_received,
        f.units_sold,
        f.closing_stock,
        f.stock_balance_exception
    FROM warehouse.fact_inventory_snapshot f
    JOIN warehouse.dim_date d ON f.date_key = d.date_key
    JOIN warehouse.dim_product p ON f.product_key = p.product_key
    JOIN warehouse.dim_store st ON f.store_key = st.store_key
)
SELECT
    COUNT(*) FILTER (
        WHERE s.inventory_date IS NULL
    ) AS warehouse_only_rows,
    COUNT(*) FILTER (
        WHERE w.inventory_date IS NULL
    ) AS source_only_rows,
    COUNT(*) FILTER (
        WHERE s.inventory_date IS NOT NULL
          AND w.inventory_date IS NOT NULL
          AND (
              s.opening_stock IS DISTINCT FROM w.opening_stock
              OR s.units_received IS DISTINCT FROM w.units_received
              OR s.units_sold IS DISTINCT FROM w.units_sold
              OR s.closing_stock IS DISTINCT FROM w.closing_stock
              OR w.stock_balance_exception IS DISTINCT FROM
                 (s.closing_stock <>
                  s.opening_stock + s.units_received - s.units_sold)
          )
    ) AS changed_inventory_rows
FROM source_inventory s
FULL JOIN warehouse_inventory w
    ON s.inventory_date = w.inventory_date
   AND s.product_code = w.product_code
   AND s.store_code = w.store_code;


WITH business_keys AS (
    SELECT 'dim_product' AS dimension,
           product_code AS business_key
    FROM warehouse.dim_product
    UNION ALL
    SELECT 'dim_customer', customer_id
    FROM warehouse.dim_customer
    UNION ALL
    SELECT 'dim_store', store_code
    FROM warehouse.dim_store
    UNION ALL
    SELECT 'dim_promotion', promotion_id
    FROM warehouse.dim_promotion
),
key_groups AS (
    SELECT dimension, business_key, COUNT(*) AS occurrences
    FROM business_keys
    GROUP BY dimension, business_key
)
SELECT dimension, SUM(occurrences - 1) AS extra_duplicate_keys
FROM key_groups
GROUP BY dimension
ORDER BY dimension;


SELECT 'fact_sales' AS fact_table,
       COUNT(*) AS rows_with_missing_mandatory_values
FROM warehouse.fact_sales
WHERE NULLIF(BTRIM(transaction_id), '') IS NULL
   OR NULLIF(BTRIM(channel), '') IS NULL
   OR order_date_key IS NULL
   OR delivery_date_key IS NULL
   OR product_key IS NULL
   OR customer_key IS NULL
   OR store_key IS NULL
   OR promotion_key IS NULL
   OR quantity IS NULL
   OR unit_selling_price IS NULL
   OR gross_sales IS NULL
   OR discount_amount IS NULL
   OR net_sales IS NULL
   OR estimated_cost IS NULL
   OR estimated_profit IS NULL

UNION ALL

SELECT 'fact_inventory_snapshot', COUNT(*)
FROM warehouse.fact_inventory_snapshot
WHERE date_key IS NULL
   OR product_key IS NULL
   OR store_key IS NULL
   OR opening_stock IS NULL
   OR units_received IS NULL
   OR units_sold IS NULL
   OR closing_stock IS NULL
   OR stock_balance_exception IS NULL;


SELECT channel, transaction_id, product_key,
       COUNT(*) AS occurrences
FROM warehouse.fact_sales
GROUP BY channel, transaction_id, product_key
HAVING COUNT(*) > 1;


--Task 11
WITH distinct_store AS (
    SELECT DISTINCT
        sale_id, sale_date, product_code, customer_code,
        quantity, selling_price, discount, store_code,
        payment_method, promotion_id
    FROM staging.store_sales
),
source_sales AS (
    SELECT 'Online' AS channel,
           BTRIM(qty)::INTEGER AS qty,
           BTRIM(price)::NUMERIC AS price,
           BTRIM(discount_amount)::NUMERIC AS discount
    FROM staging.online_sales
    UNION ALL
    SELECT 'Store',
           BTRIM(quantity)::INTEGER,
           BTRIM(selling_price)::NUMERIC,
           BTRIM(discount)::NUMERIC
    FROM distinct_store
),
source_totals AS (
    SELECT channel, COUNT(*) AS rows,
           SUM(qty) AS qty,
           SUM(ROUND(qty * price, 2)) AS gross,
           SUM(discount) AS discount,
           SUM(ROUND(qty * price - discount, 2)) AS net
    FROM source_sales
    GROUP BY channel
),
fact_totals AS (
    SELECT channel, COUNT(*) AS rows,
           SUM(quantity) AS qty,
           SUM(gross_sales) AS gross,
           SUM(discount_amount) AS discount,
           SUM(net_sales) AS net
    FROM warehouse.fact_sales
    GROUP BY channel
)
SELECT
    COALESCE(s.channel, f.channel) AS channel,
    CASE
        WHEN s.channel IS NULL OR f.channel IS NULL
            THEN 'FAIL: missing channel'
        WHEN s.rows = f.rows
         AND s.qty = f.qty
         AND s.gross = f.gross
         AND s.discount = f.discount
         AND s.net = f.net
            THEN 'PASS'
        ELSE 'FAIL: totals differ'
    END AS reconciliation
FROM source_totals s
FULL JOIN fact_totals f ON s.channel = f.channel
ORDER BY channel;



SELECT
    COALESCE(d.year_num::TEXT, 'Unknown Date') AS sales_year,
    COUNT(*) AS sales_lines,
    SUM(f.quantity) AS total_quantity,
    SUM(f.gross_sales) AS gross_sales,
    SUM(f.discount_amount) AS total_discount,
    SUM(f.net_sales) AS net_sales,
    SUM(f.estimated_profit) AS estimated_profit
FROM warehouse.fact_sales f
JOIN warehouse.dim_date d
    ON f.order_date_key = d.date_key
GROUP BY d.year_num
ORDER BY d.year_num NULLS LAST;



SELECT
    d.year_num,
    d.month_num,
    d.month_name,
    SUM(f.quantity) AS total_quantity,
    SUM(f.net_sales) AS net_sales,
    SUM(f.estimated_profit) AS estimated_profit
FROM warehouse.fact_sales f
JOIN warehouse.dim_date d
    ON f.order_date_key = d.date_key
WHERE d.date_status = 'Known'
GROUP BY d.year_num, d.month_num, d.month_name
ORDER BY d.year_num, d.month_num;


SELECT
    p.category,
    SUM(f.quantity) AS total_quantity,
    SUM(f.net_sales) AS net_sales,
    SUM(f.estimated_profit) AS estimated_profit
FROM warehouse.fact_sales f
JOIN warehouse.dim_product p
    ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY net_sales DESC, p.category
LIMIT 5;


SELECT
    p.product_code,
    p.product_name,
    p.category,
    SUM(f.quantity) AS total_quantity,
    SUM(f.net_sales) AS net_sales,
    SUM(f.estimated_profit) AS estimated_profit
FROM warehouse.fact_sales f
JOIN warehouse.dim_product p
    ON f.product_key = p.product_key
GROUP BY p.product_code, p.product_name, p.category
ORDER BY net_sales DESC, p.product_code
LIMIT 10;


SELECT
    s.store_code,
    s.store_name,
    s.province,
    s.region,
    COUNT(*) AS sales_lines,
    SUM(f.quantity) AS total_quantity,
    SUM(f.net_sales) AS net_sales,
    SUM(f.estimated_profit) AS estimated_profit
FROM warehouse.fact_sales f
JOIN warehouse.dim_store s
    ON f.store_key = s.store_key
WHERE f.channel = 'Store'
GROUP BY s.store_code, s.store_name, s.province, s.region
ORDER BY net_sales DESC, s.store_code;



SELECT
    s.province,
    s.region,
    SUM(f.quantity) AS total_quantity,
    SUM(f.net_sales) AS net_sales,
    SUM(f.estimated_profit) AS estimated_profit
FROM warehouse.fact_sales f
JOIN warehouse.dim_store s
    ON f.store_key = s.store_key
WHERE f.channel = 'Store'
GROUP BY s.province, s.region
ORDER BY net_sales DESC, s.province;


SELECT
    channel,
    COUNT(*) AS sales_lines,
    SUM(quantity) AS total_quantity,
    SUM(net_sales) AS net_sales,
    SUM(discount_amount) AS total_discount,
    SUM(estimated_profit) AS estimated_profit,
    ROUND(
        100.0 * SUM(net_sales)
        / NULLIF(SUM(SUM(net_sales)) OVER (), 0),
        2
    ) AS net_sales_share_pct
FROM warehouse.fact_sales
GROUP BY channel
ORDER BY net_sales DESC;



SELECT
    c.customer_segment,
    COUNT(*) AS sales_lines,
    SUM(f.quantity) AS total_quantity,
    SUM(f.net_sales) AS net_sales,
    SUM(f.estimated_profit) AS estimated_profit
FROM warehouse.fact_sales f
JOIN warehouse.dim_customer c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_segment
ORDER BY net_sales DESC, c.customer_segment;



SELECT
    c.loyalty_tier,
    COUNT(*) AS sales_lines,
    SUM(f.net_sales) AS net_sales,
    SUM(f.estimated_profit) AS estimated_profit
FROM warehouse.fact_sales f
JOIN warehouse.dim_customer c
    ON f.customer_key = c.customer_key
GROUP BY c.loyalty_tier
ORDER BY net_sales DESC, c.loyalty_tier;



SELECT
    p.promotion_id,
    p.promotion_name,
    p.promotion_type,
    COUNT(*) AS sales_lines,
    SUM(f.quantity) AS total_quantity,
    SUM(f.net_sales) AS net_sales,
    SUM(f.discount_amount) AS total_discount,
    SUM(f.estimated_profit) AS estimated_profit
FROM warehouse.fact_sales f
JOIN warehouse.dim_promotion p
    ON f.promotion_key = p.promotion_key
WHERE p.promotion_key > 0
GROUP BY p.promotion_id, p.promotion_name, p.promotion_type
ORDER BY net_sales DESC, p.promotion_id;


WITH latest_date AS (
    SELECT MAX(d.full_date) AS snapshot_date
    FROM warehouse.fact_inventory_snapshot f
    JOIN warehouse.dim_date d ON f.date_key = d.date_key
)
SELECT
    d.full_date AS snapshot_date,
    p.product_code,
    p.product_name,
    SUM(f.closing_stock) AS closing_stock_across_stores,
    COUNT(*) FILTER (
        WHERE f.closing_stock = 0
    ) AS stores_with_zero_stock,
    COUNT(*) FILTER (
        WHERE f.stock_balance_exception
    ) AS flagged_observations
FROM warehouse.fact_inventory_snapshot f
JOIN warehouse.dim_date d ON f.date_key = d.date_key
JOIN warehouse.dim_product p ON f.product_key = p.product_key
JOIN latest_date l ON d.full_date = l.snapshot_date
GROUP BY d.full_date, p.product_code, p.product_name
ORDER BY closing_stock_across_stores, p.product_code
LIMIT 10;


SELECT
    s.store_code,
    s.store_name,
    COUNT(*) AS product_day_observations,
    COUNT(*) FILTER (
        WHERE f.closing_stock = 0
    ) AS zero_stock_observations,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE f.closing_stock = 0)
        / NULLIF(COUNT(*), 0),
        2
    ) AS zero_stock_pct,
    COUNT(*) FILTER (
        WHERE f.stock_balance_exception
    ) AS flagged_observations
FROM warehouse.fact_inventory_snapshot f
JOIN warehouse.dim_store s ON f.store_key = s.store_key
GROUP BY s.store_code, s.store_name
ORDER BY zero_stock_observations DESC, s.store_code;



SELECT
    p.product_code,
    p.product_name,
    SUM(f.quantity) AS total_quantity,
    SUM(f.net_sales) AS net_sales
FROM warehouse.fact_sales f
JOIN warehouse.dim_product p ON f.product_key = p.product_key
GROUP BY p.product_code, p.product_name
ORDER BY total_quantity DESC, p.product_code
LIMIT 10;


WITH transactions AS (
    SELECT
        channel,
        transaction_id,
        SUM(net_sales) AS transaction_value
    FROM warehouse.fact_sales
    GROUP BY channel, transaction_id
)
SELECT
    channel,
    COUNT(*) AS transaction_count,
    ROUND(AVG(transaction_value), 2)
        AS average_transaction_value,
    SUM(transaction_value) AS net_sales
FROM transactions
GROUP BY channel
ORDER BY channel;



WITH monthly_sales AS (
    SELECT
        d.year_num,
        d.month_num,
        d.month_name,
        SUM(f.net_sales) AS net_sales
    FROM warehouse.fact_sales f
    JOIN warehouse.dim_date d ON f.order_date_key = d.date_key
    WHERE d.date_status = 'Known'
    GROUP BY d.year_num, d.month_num, d.month_name
),
ranked_months AS (
    SELECT *,
        DENSE_RANK() OVER (
            PARTITION BY year_num ORDER BY net_sales DESC
        ) AS strongest_rank,
        DENSE_RANK() OVER (
            PARTITION BY year_num ORDER BY net_sales ASC
        ) AS weakest_rank
    FROM monthly_sales
)
SELECT year_num, month_num, month_name, net_sales,
       'Strongest' AS performance
FROM ranked_months
WHERE strongest_rank = 1

UNION ALL

SELECT year_num, month_num, month_name, net_sales,
       'Weakest' AS performance
FROM ranked_months
WHERE weakest_rank = 1
ORDER BY year_num, performance, month_num;


--task 12
CREATE SCHEMA IF NOT EXISTS reporting;

CREATE OR REPLACE VIEW reporting.sales_kpis AS
SELECT
    COUNT(*) AS sales_lines,
    SUM(quantity) AS total_quantity,
    SUM(gross_sales) AS gross_sales,
    SUM(discount_amount) AS total_discount,
    SUM(net_sales) AS net_sales,
    SUM(estimated_profit) AS estimated_profit,
    ROUND(
        100.0 * SUM(estimated_profit)
        / NULLIF(SUM(net_sales), 0),
        2
    ) AS estimated_margin_pct,
    COUNT(*) FILTER (
        WHERE order_date_key = 0
    ) AS undated_sales_lines
FROM warehouse.fact_sales;


SELECT * FROM reporting.sales_kpis;


CREATE OR REPLACE VIEW reporting.inventory_risk AS
WITH latest_date AS (
    SELECT MAX(d.full_date) AS snapshot_date
    FROM warehouse.fact_inventory_snapshot f
    JOIN warehouse.dim_date d ON f.date_key = d.date_key
)
SELECT
    d.full_date AS snapshot_date,
    s.store_code,
    s.store_name,
    p.product_code,
    p.product_name,
    f.closing_stock,
    10 AS low_stock_threshold,
    CASE
        WHEN f.closing_stock < 0 THEN 'Negative Stock'
        WHEN f.closing_stock = 0 THEN 'Zero Stock'
        ELSE 'Low Stock'
    END AS stock_status,
    f.stock_balance_exception
FROM warehouse.fact_inventory_snapshot f
JOIN warehouse.dim_date d ON f.date_key = d.date_key
JOIN warehouse.dim_store s ON f.store_key = s.store_key
JOIN warehouse.dim_product p ON f.product_key = p.product_key
JOIN latest_date l ON d.full_date = l.snapshot_date
WHERE f.closing_stock <= 10;


SELECT *
FROM reporting.inventory_risk
ORDER BY closing_stock, store_code, product_code;


-- A. Monthly trend: excludes 69 undated sales.
SELECT
    TO_CHAR(d.full_date, 'YYYY-MM') AS sales_month,
    SUM(f.net_sales) AS net_sales
FROM warehouse.fact_sales f
JOIN warehouse.dim_date d ON f.order_date_key = d.date_key
WHERE d.date_status = 'Known'
GROUP BY TO_CHAR(d.full_date, 'YYYY-MM')
ORDER BY sales_month;


-- B. Category performance: includes all sales.
SELECT p.category, SUM(f.net_sales) AS net_sales
FROM warehouse.fact_sales f
JOIN warehouse.dim_product p ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY net_sales DESC;


-- C. Physical-store regional performance.
SELECT s.region, SUM(f.net_sales) AS net_sales
FROM warehouse.fact_sales f
JOIN warehouse.dim_store s ON f.store_key = s.store_key
WHERE f.channel = 'Store'
GROUP BY s.region
ORDER BY net_sales DESC;


-- D. Channel comparison: includes all sales.
SELECT channel, SUM(net_sales) AS net_sales
FROM warehouse.fact_sales
GROUP BY channel
ORDER BY net_sales DESC;


SELECT * FROM reporting.sales_kpis;


SELECT *
FROM reporting.inventory_risk
ORDER BY closing_stock, store_code, product_code;