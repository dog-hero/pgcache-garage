-- Initial seed data (small dataset for quick testing)
-- This runs first, then generate_data container creates the 1M row dataset

-- Insert sample tenants (stores)
INSERT INTO tenants (name, slug, plan) VALUES
    ('TechGadgets Store', 'techgadgets', 'professional'),
    ('HomeEssentials', 'homeessentials', 'basic'),
    ('FashionForward', 'fashionforward', 'enterprise');

-- Insert categories
INSERT INTO categories (tenant_id, name, slug, parent_id) VALUES
    (1, 'Electronics', 'electronics', NULL),
    (1, 'Gadgets', 'gadgets', 1),
    (1, 'Accessories', 'accessories', 1),
    (2, 'Home & Garden', 'home-garden', NULL),
    (2, 'Kitchen', 'kitchen', 4),
    (3, 'Clothing', 'clothing', NULL),
    (3, 'Shoes', 'shoes', 6),
    (3, 'Accessories', 'accessories-3', 6);

-- Insert products
INSERT INTO products (tenant_id, category_id, name, slug, description, price, compare_at_price, cost_price, sku, inventory_quantity) VALUES
    -- TechGadgets
    (1, 2, 'Smart Watch Pro', 'smart-watch-pro', 'Advanced smartwatch with health monitoring', 299.99, 349.99, 150.00, 'SWP-001', 100),
    (1, 2, 'Wireless Earbuds Elite', 'wireless-earbuds-elite', 'Premium noise-canceling earbuds', 179.99, 199.99, 80.00, 'WEE-002', 250),
    (1, 2, 'Portable Charger 20000mAh', 'portable-charger-20k', 'High capacity portable battery', 49.99, NULL, 20.00, 'PC-003', 500),
    (1, 3, 'USB-C Hub 7-in-1', 'usb-c-hub-7in1', 'Multi-port USB-C adapter', 39.99, 49.99, 15.00, 'UCH-004', 300),
    (1, 1, 'Laptop Stand Aluminum', 'laptop-stand-aluminum', 'Ergonomic laptop stand', 59.99, NULL, 25.00, 'LSA-005', 150),
    -- HomeEssentials
    (2, 5, 'Chef Knife Set 15pc', 'chef-knife-set-15pc', 'Professional kitchen knife set', 149.99, 179.99, 60.00, 'CKS-001', 75),
    (2, 5, 'Non-stick Pan Set', 'nonstick-pan-set', '3-piece non-stick cookware set', 89.99, 99.99, 35.00, 'NPS-002', 120),
    (2, 4, 'Smart Thermostat', 'smart-thermostat', 'WiFi connected thermostat', 129.99, 149.99, 55.00, 'ST-003', 90),
    -- FashionForward
    (3, 7, 'Running Shoes Air Max', 'running-shoes-air-max', 'Lightweight running shoes', 129.99, 159.99, 50.00, 'RSA-001', 200),
    (3, 6, 'Cotton T-Shirt Premium', 'cotton-tshirt-premium', '100% organic cotton t-shirt', 29.99, 39.99, 10.00, 'CTP-002', 1000),
    (3, 8, 'Leather Wallet Classic', 'leather-wallet-classic', 'Genuine leather bifold wallet', 49.99, 59.99, 18.00, 'LWC-003', 400);

-- Insert customers
INSERT INTO customers (tenant_id, email, first_name, last_name, phone, accept_marketing) VALUES
    (1, 'john.doe@techgadgets.com', 'John', 'Doe', '+1-555-0101', true),
    (1, 'jane.smith@techgadgets.com', 'Jane', 'Smith', '+1-555-0102', true),
    (1, 'bob.wilson@techgadgets.com', 'Bob', 'Wilson', '+1-555-0103', false),
    (2, 'alice.johnson@homeessentials.com', 'Alice', 'Johnson', '+1-555-0201', true),
    (2, 'charlie.brown@homeessentials.com', 'Charlie', 'Brown', '+1-555-0202', true),
    (3, 'diana.prince@fashionforward.com', 'Diana', 'Prince', '+1-555-0301', false),
    (3, 'evan.rogers@fashionforward.com', 'Evan', 'Rogers', '+1-555-0302', true);

-- Insert orders
INSERT INTO orders (tenant_id, customer_id, order_number, status, payment_status, fulfillment_status, subtotal, tax_amount, shipping_amount, discount_amount, total, created_at) VALUES
    (1, 1, 'TG-1001', 'delivered', 'paid', 'fulfilled', 449.98, 36.00, 9.99, 0, 495.97, '2026-01-15 10:30:00'),
    (1, 2, 'TG-1002', 'shipped', 'paid', 'partial', 179.99, 14.40, 5.99, 0, 200.38, '2026-02-20 14:15:00'),
    (1, 3, 'TG-1003', 'processing', 'paid', 'unfulfilled', 89.98, 7.20, 0, 10.00, 87.18, '2026-03-10 09:45:00'),
    (2, 4, 'HE-2001', 'delivered', 'paid', 'fulfilled', 239.98, 19.20, 12.99, 20.00, 252.17, '2026-01-20 16:00:00'),
    (2, 5, 'HE-2002', 'delivered', 'paid', 'fulfilled', 129.99, 10.40, 0, 0, 140.39, '2026-02-28 11:30:00'),
    (3, 6, 'FF-3001', 'shipped', 'paid', 'fulfilled', 179.98, 14.40, 7.99, 15.00, 187.37, '2026-03-05 13:20:00'),
    (3, 7, 'FF-3002', 'pending', 'pending', 'unfulfilled', 79.98, 6.40, 5.99, 0, 92.37, '2026-03-20 08:00:00');

-- Insert order items
INSERT INTO order_items (order_id, product_id, quantity, unit_price, tax_amount, total) VALUES
    (1, 1, 1, 299.99, 24.00, 323.99),
    (1, 3, 3, 49.99, 12.00, 161.97),
    (2, 2, 1, 179.99, 14.40, 194.39),
    (3, 4, 1, 39.99, 3.20, 43.19),
    (3, 5, 1, 59.99, 4.80, 64.79),
    (4, 6, 1, 149.99, 12.00, 161.99),
    (4, 7, 1, 89.99, 7.20, 97.19),
    (5, 8, 1, 129.99, 10.40, 140.39),
    (6, 9, 1, 129.99, 10.40, 140.39),
    (6, 11, 1, 49.99, 4.00, 53.99),
    (7, 10, 2, 29.99, 4.80, 64.78),
    (7, 11, 1, 49.99, 4.00, 53.99);

-- Insert inventory
INSERT INTO inventory (product_id, warehouse_id, quantity, reserved_quantity) VALUES
    (1, 1, 100, 5),
    (2, 1, 250, 10),
    (3, 1, 500, 25),
    (4, 2, 300, 15),
    (5, 2, 150, 0),
    (6, 1, 75, 3),
    (7, 1, 120, 8),
    (8, 2, 90, 2),
    (9, 1, 200, 12),
    (10, 2, 1000, 50),
    (11, 1, 400, 20);

-- Insert subscriptions
INSERT INTO subscriptions (tenant_id, plan, status, current_period_start, current_period_end) VALUES
    (1, 'professional', 'active', '2026-01-01', '2027-01-01'),
    (2, 'basic', 'active', '2026-02-01', '2027-02-01'),
    (3, 'enterprise', 'active', '2026-03-01', '2027-03-01');

-- Insert usage events
INSERT INTO usage_events (tenant_id, event_type, quantity, recorded_at) VALUES
    (1, 'api_calls', 15420, '2026-03-21 10:00:00'),
    (1, 'storage_gb', 45, '2026-03-21 10:00:00'),
    (2, 'api_calls', 8230, '2026-03-21 10:00:00'),
    (2, 'storage_gb', 22, '2026-03-21 10:00:00'),
    (3, 'api_calls', 45000, '2026-03-21 10:00:00'),
    (3, 'storage_gb', 128, '2026-03-21 10:00:00');

-- Insert invoices
INSERT INTO invoices (tenant_id, subscription_id, invoice_number, amount, status, due_date, paid_at) VALUES
    (1, 1, 'INV-TG-2026-001', 99.00, 'paid', '2026-02-01', '2026-01-15'),
    (1, 1, 'INV-TG-2026-002', 99.00, 'paid', '2026-03-01', '2026-02-28'),
    (2, 2, 'INV-HE-2026-001', 29.00, 'paid', '2026-03-01', '2026-02-25'),
    (3, 3, 'INV-FF-2026-001', 299.00, 'paid', '2026-04-01', '2026-03-15');
