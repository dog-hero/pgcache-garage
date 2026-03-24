-- Generate 50-100 million rows for load testing PgCache
-- Run by generate_data container after initial setup
-- Estimated time: 15-30 minutes depending on hardware

\timing on

-- Generate additional customers (total will be ~100,000 customers per tenant = 300,000)
DO $$
BEGIN
    RAISE NOTICE 'Starting customer generation at %', clock_timestamp();
END $$;

INSERT INTO customers (tenant_id, email, first_name, last_name, phone, accept_marketing)
SELECT 
    (ROW_NUMBER() OVER ()) % 3 + 1,
    'customer_' || generate_series || '@example.com',
    'FirstName' || generate_series,
    'LastName' || generate_series,
    '+1-555-' || LPAD((generate_series % 10000)::text, 4, '0'),
    case when random() > 0.5 then true else false end
FROM generate_series(1001, 300000);

DO $$
BEGIN
    RAISE NOTICE 'Customer generation complete at %', clock_timestamp();
END $$;

-- Generate products (total ~5000 products per tenant = 15000)
DO $$
BEGIN
    RAISE NOTICE 'Starting product generation at %', clock_timestamp();
END $$;

INSERT INTO products (tenant_id, category_id, name, slug, description, price, compare_at_price, cost_price, sku, inventory_quantity)
SELECT 
    (ROW_NUMBER() OVER ()) % 3 + 1,
    (ROW_NUMBER() OVER ()) % 8 + 1,
    'Product ' || generate_series,
    'product-' || generate_series,
    'Description for product ' || generate_series,
    (random() * 500 + 10)::decimal(10,2),
    case when random() > 0.7 then (random() * 500 + 50)::decimal(10,2) else null end,
    (random() * 200 + 5)::decimal(10,2),
    'SKU-' || LPAD(generate_series::text, 6, '0'),
    (random() * 500)::integer
FROM generate_series(1, 15000);

DO $$
BEGIN
    RAISE NOTICE 'Product generation complete at %', clock_timestamp();
END $$;

-- Generate orders (10,000,000 orders distributed across tenants)
DO $$
BEGIN
    RAISE NOTICE 'Starting order generation (10M) at %', clock_timestamp();
END $$;

INSERT INTO orders (tenant_id, customer_id, order_number, status, payment_status, fulfillment_status, subtotal, tax_amount, shipping_amount, discount_amount, total, created_at)
SELECT 
    (random() * 2 + 1)::integer,
    (random() * 299999 + 1)::integer,
    'ORD-' || generate_series,
    (array['pending', 'processing', 'shipped', 'delivered', 'cancelled'])[floor(random() * 4 + 1)::integer],
    (array['pending', 'paid', 'failed', 'refunded'])[floor(random() * 3 + 1)::integer],
    (array['unfulfilled', 'partial', 'fulfilled'])[floor(random() * 2 + 1)::integer],
    (random() * 500 + 20)::decimal(10,2),
    (random() * 40 + 2)::decimal(10,2),
    case when random() > 0.3 then (random() * 15 + 5)::decimal(10,2) else 0 end,
    case when random() > 0.8 then (random() * 50)::decimal(10,2) else 0 end,
    0,
    timestamp '2025-01-01' + random() * (timestamp '2026-03-22' - timestamp '2025-01-01')
FROM generate_series(1, 10000000);

-- Update total after insert
DO $$
BEGIN
    RAISE NOTICE 'Updating order totals at %', clock_timestamp();
END $$;

UPDATE orders SET total = subtotal + tax_amount + shipping_amount - discount_amount;

DO $$
BEGIN
    RAISE NOTICE 'Order generation complete at %', clock_timestamp();
END $$;

-- Generate order items (~30 million order items)
DO $$
BEGIN
    RAISE NOTICE 'Starting order items generation (30M) at %', clock_timestamp();
END $$;

INSERT INTO order_items (order_id, product_id, quantity, unit_price, tax_amount, total)
SELECT 
    (random() * 9999999 + 1)::integer,
    (random() * 14999 + 1)::integer,
    (random() * 5 + 1)::integer,
    (random() * 200 + 10)::decimal(10,2),
    (random() * 16 + 1)::decimal(10,2),
    0
FROM generate_series(1, 30000000);

-- Update order item totals
DO $$
BEGIN
    RAISE NOTICE 'Updating order item totals at %', clock_timestamp();
END $$;

UPDATE order_items SET total = quantity * unit_price + tax_amount;

DO $$
BEGIN
    RAISE NOTICE 'Order items generation complete at %', clock_timestamp();
END $$;

-- Generate usage events (~50 million events)
DO $$
BEGIN
    RAISE NOTICE 'Starting usage events generation (50M) at %', clock_timestamp();
END $$;

INSERT INTO usage_events (tenant_id, event_type, quantity, recorded_at)
SELECT 
    (random() * 2 + 1)::integer,
    (array['api_calls', 'storage_gb', 'bandwidth_gb', 'emails_sent', 'sms_sent'])[floor(random() * 4 + 1)::integer],
    (random() * 1000)::integer,
    timestamp '2025-01-01' + random() * (timestamp '2026-03-22' - timestamp '2025-01-01')
FROM generate_series(1, 50000000);

DO $$
BEGIN
    RAISE NOTICE 'Usage events generation complete at %', clock_timestamp();
END $$;

-- Generate invoices (~2 million invoices)
DO $$
BEGIN
    RAISE NOTICE 'Starting invoice generation (2M) at %', clock_timestamp();
END $$;

INSERT INTO invoices (tenant_id, subscription_id, invoice_number, amount, status, due_date, paid_at)
SELECT 
    (random() * 2 + 1)::integer,
    (random() * 2 + 1)::integer,
    'INV-' || generate_series || '-' || (random() * 2026)::integer,
    (random() * 500 + 10)::decimal(10,2),
    (array['draft', 'sent', 'paid', 'overdue', 'cancelled'])[floor(random() * 4 + 1)::integer],
    date '2026-01-01' + (random() * 450)::integer,
    case when random() > 0.3 then date '2026-01-01' + (random() * 450)::integer else null end
FROM generate_series(1, 2000000);

DO $$
BEGIN
    RAISE NOTICE 'Invoice generation complete at %', clock_timestamp();
END $$;

-- Update inventory records
DO $$
BEGIN
    RAISE NOTICE 'Updating inventory at %', clock_timestamp();
END $$;

INSERT INTO inventory (product_id, warehouse_id, quantity, reserved_quantity)
SELECT 
    (random() * 14999 + 1)::integer,
    (random() * 4 + 1)::integer,
    (random() * 1000)::integer,
    (random() * 50)::integer
FROM generate_series(1, 50000);

DO $$
BEGIN
    RAISE NOTICE 'Data generation complete at %', clock_timestamp();
END $$;

-- Vacuum to clean up
DO $$
BEGIN
    RAISE NOTICE 'Running VACUUM ANALYZE at %', clock_timestamp();
END $$;

VACUUM (ANALYZE, VERBOSE);

DO $$
BEGIN
    RAISE NOTICE 'All done at %', clock_timestamp();
END $$;

\timing off
