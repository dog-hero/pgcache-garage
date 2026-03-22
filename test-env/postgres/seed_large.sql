-- Generate 1 million rows for load testing PgCache
-- Run by generate_data container after initial setup

\timing on

-- Generate additional customers (total will be ~10,000 customers per tenant)
INSERT INTO customers (tenant_id, email, first_name, last_name, phone, accept_marketing)
SELECT 
    (ROW_NUMBER() OVER ()) % 3 + 1,
    'customer_' || generate_series || '@example.com',
    'FirstName' || generate_series,
    'LastName' || generate_series,
    '+1-555-' || LPAD(generate_series::text, 4, '0'),
    case when random() > 0.5 then true else false end
FROM generate_series(1001, 10000);

-- Generate products (total ~500 products per tenant)
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
FROM generate_series(1, 500);

-- Generate orders (500,000 orders distributed across tenants)
INSERT INTO orders (tenant_id, customer_id, order_number, status, payment_status, fulfillment_status, subtotal, tax_amount, shipping_amount, discount_amount, total, created_at)
SELECT 
    (random() * 2 + 1)::integer,
    (random() * 9999 + 1)::integer,
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
FROM generate_series(1, 500000);

-- Update total after insert
UPDATE orders SET total = subtotal + tax_amount + shipping_amount - discount_amount;

-- Generate order items (~1.5 million order items)
INSERT INTO order_items (order_id, product_id, quantity, unit_price, tax_amount, total)
SELECT 
    (random() * 499999 + 1)::integer,
    (random() * 499 + 1)::integer,
    (random() * 5 + 1)::integer,
    (random() * 200 + 10)::decimal(10,2),
    (random() * 16 + 1)::decimal(10,2),
    0
FROM generate_series(1, 1500000);

-- Update order item totals
UPDATE order_items SET total = quantity * unit_price + tax_amount;

-- Generate usage events (~500,000 events)
INSERT INTO usage_events (tenant_id, event_type, quantity, recorded_at)
SELECT 
    (random() * 2 + 1)::integer,
    (array['api_calls', 'storage_gb', 'bandwidth_gb', 'emails_sent', 'sms_sent'])[floor(random() * 4 + 1)::integer],
    (random() * 1000)::integer,
    timestamp '2025-01-01' + random() * (timestamp '2026-03-22' - timestamp '2025-01-01')
FROM generate_series(1, 500000);

-- Generate invoices (~50,000 invoices)
INSERT INTO invoices (tenant_id, subscription_id, invoice_number, amount, status, due_date, paid_at)
SELECT 
    (random() * 2 + 1)::integer,
    (random() * 2 + 1)::integer,
    'INV-' || generate_series || '-' || (random() * 2026)::integer,
    (random() * 500 + 10)::decimal(10,2),
    (array['draft', 'sent', 'paid', 'overdue', 'cancelled'])[floor(random() * 4 + 1)::integer],
    date '2026-01-01' + (random() * 450)::integer,
    case when random() > 0.3 then date '2026-01-01' + (random() * 450)::integer else null end
FROM generate_series(1, 50000);

-- Update inventory records
INSERT INTO inventory (product_id, warehouse_id, quantity, reserved_quantity)
SELECT 
    (random() * 499 + 1)::integer,
    (random() * 4 + 1)::integer,
    (random() * 1000)::integer,
    (random() * 50)::integer
FROM generate_series(1, 2000);

-- Vacuum to clean up
VACUUM (FULL, ANALYZE);

\timing off
