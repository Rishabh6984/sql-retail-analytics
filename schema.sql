-- Supermarket retail analytics schema (MySQL 8+)
DROP TABLE IF EXISTS sale_lines;
DROP TABLE IF EXISTS bills;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS stores;

CREATE TABLE stores (
  store_id   INT PRIMARY KEY,
  store_name VARCHAR(50) NOT NULL,
  city       VARCHAR(50) NOT NULL,
  opened_on  DATE NOT NULL
);

CREATE TABLE products (
  product_id INT PRIMARY KEY,
  name       VARCHAR(80) NOT NULL,
  category   VARCHAR(40) NOT NULL,
  cost_price DECIMAL(10,2) NOT NULL,
  mrp        DECIMAL(10,2) NOT NULL
);

CREATE TABLE bills (
  bill_id    INT PRIMARY KEY,
  store_id   INT NOT NULL,
  bill_date  DATE NOT NULL,
  payment    VARCHAR(10) NOT NULL,          -- CASH / CARD / UPI
  FOREIGN KEY (store_id) REFERENCES stores(store_id)
);

CREATE TABLE sale_lines (
  bill_id    INT NOT NULL,
  product_id INT NOT NULL,
  qty        INT NOT NULL,
  sell_price DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (bill_id, product_id),
  FOREIGN KEY (bill_id) REFERENCES bills(bill_id),
  FOREIGN KEY (product_id) REFERENCES products(product_id)
);
