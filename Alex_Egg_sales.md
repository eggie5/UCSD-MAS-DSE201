# Hmwk 3

> For each query, report the indices that you used by writing the query you used to create them.
NOTE: as mentioned before, consider each query to be independent of the other. Eg. If you used video_id for q1, and used video_id and user_id for q2, make sure you mention both indices in the answer for q2.
 
> For each query, report the final "cost" you get in the explain output and the estimated time. It is ok if you report the entire query plan but what matters is the final cost (topmost line).

## Sales Cube

### Query 1

```sql
EXPLAIN SELECT customer_name,sum(quantity),sum(price) 
FROM sales.sale s 
NATURAL JOIN sales.customer c 
GROUP BY c.customer_id
```

This query is simply looking up the total sales per customer. All the columns that are queried or joined in this query are primary key columsn so an index is already in place. There is nothing we can do here!

### Query 2

```sql
SELECT state_name,sum(quantity), sum(price) 
FROM sales.sale s 
NATURAL JOIN sales.customer c 
NATURAL JOIN sales.state st 
GROUP BY st.state_name
```

This query is another example of the previous query where all column querires or joins are preformed on primary keys which already have an index.

### Query 3

```sql
SELECT product_id,sum(quantity),sum(price) AS dollar_value 
FROM sales.sale s 
WHERE customer_id =1
GROUP BY product_id 
ORDER BY dollar_value
```

#### Explain Output

```sql
Sort  (cost=42421.98..42501.23 rows=31698 width=14)
  Sort Key: (sum(price))
  ->  HashAggregate  (cost=39656.00..40052.23 rows=31698 width=14)
        Group Key: product_id
        ->  Seq Scan on sale s  (cost=0.00..37739.00 rows=255600 width=14)
              Filter: (customer_id = 91704)
```

```
250k Rows, 12262ms
```

#### Analysis

As you can see from the plan for this query that it is doing and expensive (37739) sequential scan on the `customer_id` column. We should be able to speed this up w/ an index:

```
create index customer_id_index on sales.sale(customer_id)
--3498ms
```

run it again in the new index

```sql
SELECT product_id,sum(quantity),sum(price) AS dollar_value 
FROM sales.sale s 
WHERE customer_id =1
GROUP BY product_id 
ORDER BY dollar_value
-- 12436ms
```
  
#### Explain Output


```sql
Sort  (cost=25406.31..25485.56 rows=31698 width=14)
  Sort Key: (sum(price))
  ->  HashAggregate  (cost=22640.33..23036.55 rows=31698 width=14)
        Group Key: product_id
        ->  Bitmap Heap Scan on sale s  (cost=4789.33..20723.33 rows=255600 width=14)
              Recheck Cond: (customer_id = 91704)
              ->  Bitmap Index Scan on customer_id_index  (cost=0.00..4725.43 rows=255600 width=0)
                    Index Cond: (customer_id = 91704)
```                 

### Query 4

```sql
SELECT product_id,customer_id,sum(price) AS dollar_value 
FROM sales.sale 
GROUP BY product_id,customer_id 
ORDER BY dollar_value
```

#### Explain Output

```sql
Sort  (cost=321558.87..322178.92 rows=248022 width=14)
  Sort Key: (sum(price))
  ->  GroupAggregate  (cost=276235.69..299335.96 rows=248022 width=14)
        Group Key: product_id, customer_id
        ->  Sort  (cost=276235.69..281235.69 rows=2000000 width=14)
              Sort Key: product_id, customer_id
              ->  Seq Scan on sale  (cost=0.00..32739.00 rows=2000000 width=14)
```

#### Analysis

As you can see from the query plan, we have to do a full sequential scan on sale table which has a very high potential cost. This query does not query any columns or perform any join operation on non-indexed columns. So there is not index we can add that would help optimization.


### Query 5

```sql
SELECT state_name,ca.category_id,sum(price) FROM
sales.sale sa NATURAL JOIN sales.customer cu 
NATURAL JOIN sales.state st 
NATURAL JOIN sales.category ca 
NATURAL JOIN sales.product p
GROUP BY state_name,ca.category_id
```

#### Explain Output


```sql
GroupAggregate  (cost=485614.11..518114.11 rows=1000000 width=128)
  Group Key: st.state_name, ca.category_id
  ->  Sort  (cost=485614.11..490614.11 rows=2000000 width=128)
        Sort Key: st.state_name, ca.category_id
        ->  Hash Join  (cost=28674.42..146413.42 rows=2000000 width=128)
              Hash Cond: (sa.customer_id = cu.customer_id)
              ->  Hash Join  (cost=24462.50..102201.50 rows=2000000 width=14)
                    Hash Cond: (sa.product_id = p.product_id)
                    ->  Seq Scan on sale sa  (cost=0.00..32739.00 rows=2000000 width=14)
                    ->  Hash  (cost=18212.50..18212.50 rows=500000 width=8)
                          ->  Hash Join  (cost=151.50..18212.50 rows=500000 width=8)
                                Hash Cond: (p.category_id = ca.category_id)
                                ->  Seq Scan on product p  (cost=0.00..8686.00 rows=500000 width=8)
                                ->  Hash  (cost=89.00..89.00 rows=5000 width=4)
                                      ->  Seq Scan on category ca  (cost=0.00..89.00 rows=5000 width=4)
              ->  Hash  (cost=2961.93..2961.93 rows=100000 width=122)
                    ->  Hash Join  (cost=21.93..2961.93 rows=100000 width=122)
                          Hash Cond: (cu.state_id = st.state_id)
                          ->  Seq Scan on customer cu  (cost=0.00..1565.00 rows=100000 width=8)
                          ->  Hash  (cost=15.30..15.30 rows=530 width=122)
                                ->  Seq Scan on state st  (cost=0.00..15.30 rows=530 width=122)
```

#### Analysis

As you can see from the query plan we have a 5 way join, howver we can't optimzie it w/ indicies b/c they are already using primary keys. Also, we can see that the outtermost group aggregate is expensive, but we can't help that by adding an index.

### Query 6

```sql
SELECT cate.category_id,cust.customer_id,sum(quantity),sum(price) FROM
(SELECT category_id,sum(price) AS dollar_value FROM
sales.category NATURAL JOIN sales.product NATURAL JOIN sales.sale
GROUP BY category_id ORDER BY dollar_value DESC limit 10) AS cate,
(SELECT customer_id,sum(price) AS dollar_value FROM sales.sale
GROUP BY customer_id ORDER BY dollar_value DESC limit 10) AS cust, sales.sale s,sales.product p
WHERE p.category_id = cate.category_id and s.customer_id = cust.customer_id and s.product_id = p.product_id
GROUP BY cate.category_id,cust.customer_id ORDER BY cate.category_id
```

#### Explain Output
```sql
Sort  (cost=206072.90..206073.10 rows=80 width=18)
  Sort Key: cate.category_id
  ->  HashAggregate  (cost=206069.38..206070.38 rows=80 width=18)
        Group Key: cate.category_id, cust.customer_id
        ->  Hash Join  (cost=165695.24..206029.34 rows=4004 width=18)
              Hash Cond: (s.customer_id = cust.customer_id)
              ->  Hash Join  (cost=122955.82..163234.86 rows=4004 width=18)
                    Hash Cond: (s.product_id = p.product_id)
                    ->  Seq Scan on sale s  (cost=0.00..32739.00 rows=2000000 width=18)
                    ->  Hash  (cost=122943.31..122943.31 rows=1001 width=8)
                          ->  Hash Join  (cost=112372.30..122943.31 rows=1001 width=8)
                                Hash Cond: (p.category_id = cate.category_id)
                                ->  Seq Scan on product p  (cost=0.00..8686.00 rows=500000 width=8)
                                ->  Hash  (cost=112372.17..112372.17 rows=10 width=4)
                                      ->  Subquery Scan on cate  (cost=112372.05..112372.17 rows=10 width=4)
                                            ->  Limit  (cost=112372.05..112372.07 rows=10 width=10)
                                                  ->  Sort  (cost=112372.05..112384.55 rows=5000 width=10)
                                                        Sort Key: (sum(sale.price))
                                                        ->  HashAggregate  (cost=112201.50..112264.00 rows=5000 width=10)
                                                              Group Key: category.category_id
                                                              ->  Hash Join  (cost=24462.50..102201.50 rows=2000000 width=10)
                                                                    Hash Cond: (sale.product_id = product.product_id)
                                                                    ->  Seq Scan on sale  (cost=0.00..32739.00 rows=2000000 width=10)
                                                                    ->  Hash  (cost=18212.50..18212.50 rows=500000 width=8)
                                                                          ->  Hash Join  (cost=151.50..18212.50 rows=500000 width=8)
                                                                                Hash Cond: (product.category_id = category.category_id)
                                                                                ->  Seq Scan on product  (cost=0.00..8686.00 rows=500000 width=8)
                                                                                ->  Hash  (cost=89.00..89.00 rows=5000 width=4)
                                                                                      ->  Seq Scan on category  (cost=0.00..89.00 rows=5000 width=4)
              ->  Hash  (cost=42739.32..42739.32 rows=8 width=4)
                    ->  Subquery Scan on cust  (cost=42739.22..42739.32 rows=8 width=4)
                          ->  Limit  (cost=42739.22..42739.24 rows=8 width=10)
                                ->  Sort  (cost=42739.22..42739.24 rows=8 width=10)
                                      Sort Key: (sum(sale_1.price))
                                      ->  HashAggregate  (cost=42739.00..42739.10 rows=8 width=10)
                                            Group Key: sale_1.customer_id
                                            ->  Seq Scan on sale sale_1  (cost=0.00..32739.00 rows=2000000 width=10)
```


Add an index to product.category_id

```sql
CREATE INDEX product_category_id_idx
  ON sales.product USING btree
  (category_id);
```

```sql
CREATE INDEX sale_product_id_idx
  ON sales.sale USING btree
  (product_id);
```

#### Explain Output w/ index
                            
```sql
BTree index on sale.product_id
Sort  (cost=168190.43..168190.63 rows=80 width=18)
  Sort Key: category.category_id
  ->  HashAggregate  (cost=168186.90..168187.90 rows=80 width=18)
        Group Key: category.category_id, cust.customer_id
        ->  Hash Join  (cost=155075.84..168146.94 rows=3996 width=18)
              Hash Cond: (s.customer_id = cust.customer_id)
              ->  Nested Loop  (cost=112336.42..125352.57 rows=3996 width=18)
                    ->  Nested Loop  (cost=112336.00..115550.51 rows=999 width=8)
                          ->  Limit  (cost=112330.80..112330.82 rows=10 width=10)
                                ->  Sort  (cost=112330.80..112343.30 rows=5000 width=10)
                                      Sort Key: (sum(sale.price))
                                      ->  HashAggregate  (cost=112160.25..112222.75 rows=5000 width=10)
                                            Group Key: category.category_id
                                            ->  Hash Join  (cost=24451.25..102170.25 rows=1998000 width=10)
                                                  Hash Cond: (sale.product_id = product.product_id)
                                                  ->  Seq Scan on sale  (cost=0.00..32739.00 rows=2000000 width=10)
                                                  ->  Hash  (cost=18207.50..18207.50 rows=499500 width=8)
                                                        ->  Hash Join  (cost=151.50..18207.50 rows=499500 width=8)
                                                              Hash Cond: (product.category_id = category.category_id)
                                                              ->  Seq Scan on product  (cost=0.00..8686.00 rows=500000 width=8)
                                                              ->  Hash  (cost=89.00..89.00 rows=5000 width=4)
                                                                    ->  Seq Scan on category  (cost=0.00..89.00 rows=5000 width=4)
                          ->  Bitmap Heap Scan on product p  (cost=5.20..320.96 rows=100 width=8)
                                Recheck Cond: (category_id = category.category_id)
                                ->  Bitmap Index Scan on product_category_id_idx  (cost=0.00..5.17 rows=100 width=0)
                                      Index Cond: (category_id = category.category_id)
                    ->  Index Scan using sale_product_id_idx on sale s  (cost=0.43..9.73 rows=8 width=18)
                          Index Cond: (product_id = p.product_id)
              ->  Hash  (cost=42739.32..42739.32 rows=8 width=4)
                    ->  Subquery Scan on cust  (cost=42739.22..42739.32 rows=8 width=4)
                          ->  Limit  (cost=42739.22..42739.24 rows=8 width=10)
                                ->  Sort  (cost=42739.22..42739.24 rows=8 width=10)
                                      Sort Key: (sum(sale_1.price))
                                      ->  HashAggregate  (cost=42739.00..42739.10 rows=8 width=10)
                                            Group Key: sale_1.customer_id
                                            ->  Seq Scan on sale sale_1  (cost=0.00..32739.00 rows=2000000 width=10)
```


