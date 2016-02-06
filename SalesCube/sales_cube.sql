-- http://www.piazza.com/class_profile/get_resource/ijcejswq97f42q/ijzd7jr53p32tf

DROP TABLE IF EXISTS customers CASCADE ;


CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name character varying(50) NOT NULL,
    state_id integer
);


DROP TABLE IF EXISTS  categories CASCADE;

CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name  character varying(50) NOT NULL,
    desc text
);

DROP TABLE IF EXISTS  products CASCADE;

CREATE TABLE products (
    id SERIAL PRIMARY KEY NOT NULL,
    list_price numeric NOT NULL,
    name character varying(50) NOT NULL,
    category_id INTEGER REFERENCES categories (id) NOT NULL
);



DROP TABLE  IF EXISTS sales CASCADE;


CREATE TABLE sales (
    id SERIAL PRIMARY KEY NOT NULL,
    customer_id INTEGER REFERENCES customers (id) NOT NULL,
    product_id INTEGER REFERENCES products (id) NOT NULL,
    quantity integer NOT NULL,
    total numeric NOT NULL
);


DROP TABLE IF EXISTS  states CASCADE;

CREATE TABLE states (
    id SERIAL PRIMARY KEY NOT NULL,
    name  character varying(50) NOT NULL UNIQUE
);



