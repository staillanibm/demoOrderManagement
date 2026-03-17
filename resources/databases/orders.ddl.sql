CREATE TABLE orders (
    order_id VARCHAR(20) PRIMARY KEY,
    order_date TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL,
    customer_id VARCHAR(20) NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    customer_email VARCHAR(255) NOT NULL,
    shipping_street VARCHAR(255),
    shipping_city VARCHAR(100),
    shipping_postal_code VARCHAR(20),
    shipping_country CHAR(2),
    subtotal DECIMAL(10,2),
    tax DECIMAL(10,2),
    shipping DECIMAL(10,2),
    total DECIMAL(10,2),
    currency CHAR(3) DEFAULT 'EUR'
);

CREATE TABLE order_items (
    order_id VARCHAR(20) REFERENCES orders(order_id),
    line_number INT NOT NULL,
    product_id VARCHAR(20) NOT NULL,
    product_name VARCHAR(255),
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2),
    total_price DECIMAL(10,2),
    PRIMARY KEY (order_id, line_number)
);