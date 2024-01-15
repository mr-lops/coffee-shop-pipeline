CREATE TABLE Sales_Coffee IF NOT EXISTS(
    transaction_id INT PRIMARY KEY,
    transaction_date DATE,
    transaction_time TIME,
    transaction_qty INT,
    store_id INT,
    store_location VARCHAR(255),
    product_id INT,
    unit_price DECIMAL(10, 2),
    product_category VARCHAR(255),
    product_type VARCHAR(255),
    product_detail VARCHAR(255)
);
