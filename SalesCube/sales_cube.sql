DROP TABLE IF EXISTS customers CASCADE ;


CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    state_id integer
);


DROP TABLE IF EXISTS  categories CASCADE;

CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name  text,
    description text
);

DROP TABLE IF EXISTS  products CASCADE;

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    list_price money,
    name text,
    category_id INTEGER REFERENCES categories (id) NOT NULL
);



DROP TABLE  IF EXISTS sales CASCADE;


CREATE TABLE sales (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers (id) NOT NULL,
    product_id INTEGER REFERENCES products (id) NOT NULL,
    quantity integer,
    total money
);


DROP TABLE IF EXISTS  states CASCADE;

CREATE TABLE states (
    id SERIAL PRIMARY KEY,
    name  text
);



