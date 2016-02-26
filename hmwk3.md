# Hmwk 3

## Sales Cube

### Query 1

```
EXPLAIN SELECT customer_name,sum(quantity),sum(price) 
FROM sales.sale s 
NATURAL JOIN sales.customer c 
GROUP BY c.customer_id
```

This query is simply looking up the total sales per customer. All the columns that are queried or joined in this query are primary key columsn so an index is already in place. There is nothing we can do here!

### Query 2

```
SELECT state_name,sum(quantity), sum(price) 
FROM sales.sale s 
NATURAL JOIN sales.customer c 
NATURAL JOIN sales.state st 
GROUP BY st.state_name
```

This query is another example of the previous query where all column querires or joins are preformed on primary keys which already have an index.

### Query 3

```
SELECT product_id,sum(quantity),sum(price) AS dollar_value 
FROM sales.sale s 
WHERE customer_id =1
GROUP BY product_id 
ORDER BY dollar_value
```

#### Explain Output

```
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

```
SELECT product_id,sum(quantity),sum(price) AS dollar_value 
FROM sales.sale s 
WHERE customer_id =1
GROUP BY product_id 
ORDER BY dollar_value
-- 12436ms
```
  
#### Explain Output


```
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

```
SELECT product_id,customer_id,sum(price) AS dollar_value 
FROM sales.sale 
GROUP BY product_id,customer_id 
ORDER BY dollar_value
```

#### Explain Output

```
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

```
SELECT state_name,ca.category_id,sum(price) FROM
sales.sale sa NATURAL JOIN sales.customer cu 
NATURAL JOIN sales.state st 
NATURAL JOIN sales.category ca 
NATURAL JOIN sales.product p
GROUP BY state_name,ca.category_id
```

#### Explain Output


```
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

```
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
```
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

```
CREATE INDEX product_category_id_idx
  ON sales.product USING btree
  (category_id);
```

```
CREATE INDEX sale_product_id_idx
  ON sales.sale USING btree
  (product_id);
```

#### Explain Output w/ index
                            
```
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


## 201Cats

### Query 1

```
SELECT video_id, COUNT(*) AS like_no 
FROM cats.likes 
GROUP BY video_id
ORDER BY like_no DESC 
LIMIT 10
```

```
Limit  (cost=42897.11..42897.14 rows=10 width=4)
  ->  Sort  (cost=42897.11..42909.62 rows=5002 width=4)
        Sort Key: (count(*))
        ->  HashAggregate  (cost=42739.00..42789.02 rows=5002 width=4)
              Group Key: video_id
              ->  Seq Scan on like  (cost=0.00..32739.00 rows=2000000 width=4)
```

#### Analysis
As this query does no extensive querying or joining on a particular column, it stands to have no benefit from an added index


### Query 2

```
SELECT l.video_id, COUNT(*) AS like_no 
FROM cats.friend f, cats.like l
WHERE f.user_id=2004
AND f.friend_id=l.user_id 
GROUP BY l.video_id 
ORDER BY like_no DESC 
LIMIT 10
--870ms
```

```
Limit  (cost=107391.36..107391.39 rows=10 width=4)
  ->  Sort  (cost=107391.36..107392.39 rows=411 width=4)
        Sort Key: (count(*))
        ->  HashAggregate  (cost=107378.37..107382.48 rows=411 width=4)
              Group Key: l.video_id
              ->  Hash Join  (cost=65552.00..107376.32 rows=411 width=4)
                    Hash Cond: (f.friend_id = l.user_id)
                    ->  Seq Scan on friend f  (cost=0.00..33850.00 rows=19 width=4)
                          Filter: (user_id = 2004)
                    ->  Hash  (cost=32739.00..32739.00 rows=2000000 width=8)
                          ->  Seq Scan on like l  (cost=0.00..32739.00 rows=2000000 width=8)
```

#### Analysis
As we can see our sql syntax is doing an implicit join between the friend and like table on the `friend.user_id` column. Thus it would be beneficial to add an index to it so it doesn't have to do sequential search. Using the same logic it would seem that adding an index to `like.user_id`.

```
CREATE INDEX friend_user_id_idx ON cats.friend USING btree (user_id); --3964ms
```

The query only takes 685ms now. The like.user_id index did not help any extra:


```
Limit  (cost=73619.53..73619.56 rows=10 width=4)
  ->  Sort  (cost=73619.53..73620.56 rows=411 width=4)
        Sort Key: (count(*))
        ->  HashAggregate  (cost=73606.54..73610.65 rows=411 width=4)
              Group Key: l.video_id
              ->  Hash Join  (cost=65556.57..73604.49 rows=411 width=4)
                    Hash Cond: (f.friend_id = l.user_id)
                    ->  Bitmap Heap Scan on friend f  (cost=4.57..78.17 rows=19 width=4)
                          Recheck Cond: (user_id = 2004)
                          ->  Bitmap Index Scan on friend_user_id_idx  (cost=0.00..4.57 rows=19 width=0)
                                Index Cond: (user_id = 2004)
                    ->  Hash  (cost=32739.00..32739.00 rows=2000000 width=8)
                          ->  Seq Scan on like l  (cost=0.00..32739.00 rows=2000000 width=8)
```

### Query 3

```
SELECT l.video, COUNT(*)
FROM (SELECT l.video_id AS video, l.user_id AS user1 
  FROM cats.friend f, cats.like l 
  WHERE f.user_id=2004 AND f.friend_id=l.user_id
UNION
SELECT l.video_id AS video, l.user_id AS user1 
FROM cats.friend f, cats.friend ff, cats.like l 
WHERE f.user_id=2004 AND f.friend_id=ff.user_id AND ff.user_id=l.user_id
) AS l
GROUP BY l.video
ORDER BY COUNT(*) DESC LIMIT 10
--query runs in 2280ms
```

#### Explain Output
--query runs in 2280ms


```
Limit  (cost=284830.76..284830.79 rows=10 width=4)
  ->  Sort  (cost=284830.76..284831.26 rows=200 width=4)
        Sort Key: (count(*))
        ->  HashAggregate  (cost=284824.44..284826.44 rows=200 width=4)
              Group Key: l.video_id
              ->  HashAggregate  (cost=284613.56..284697.91 rows=8435 width=8)
                    Group Key: l.video_id, l.user_id
                    ->  Append  (cost=65552.00..284571.39 rows=8435 width=8)
                          ->  Hash Join  (cost=65552.00..107376.32 rows=411 width=8)
                                Hash Cond: (f.friend_id = l.user_id)
                                ->  Seq Scan on friend f  (cost=0.00..33850.00 rows=19 width=4)
                                      Filter: (user_id = 2004)
                                ->  Hash  (cost=32739.00..32739.00 rows=2000000 width=8)
                                      ->  Seq Scan on like l  (cost=0.00..32739.00 rows=2000000 width=8)
                          ->  Hash Join  (cost=127215.00..177110.72 rows=8024 width=8)
                                Hash Cond: (f_1.friend_id = ff.user_id)
                                ->  Hash Join  (cost=65552.00..107376.32 rows=411 width=12)
                                      Hash Cond: (f_1.friend_id = l_1.user_id)
                                      ->  Seq Scan on friend f_1  (cost=0.00..33850.00 rows=19 width=4)
                                            Filter: (user_id = 2004)
                                      ->  Hash  (cost=32739.00..32739.00 rows=2000000 width=8)
                                            ->  Seq Scan on like l_1  (cost=0.00..32739.00 rows=2000000 width=8)
                                ->  Hash  (cost=28850.00..28850.00 rows=2000000 width=4)
                                      ->  Seq Scan on friend ff  (cost=0.00..28850.00 rows=2000000 width=4)
```

#### Analysis
It still stands from the last argument that an index on the heavily queried `friend.user_id` column would be beneficial:

```
CREATE INDEX friend_user_id_idx ON cats.friend USING btree (user_id); -- 3627ms
```

Now the query now only takes 1331ms, half the time

```
Limit  (cost=152067.65..152067.68 rows=10 width=4)
  ->  Sort  (cost=152067.65..152068.15 rows=200 width=4)
        Sort Key: (count(*))
        ->  HashAggregate  (cost=152061.33..152063.33 rows=200 width=4)
              Group Key: l.video_id
              ->  HashAggregate  (cost=151850.45..151934.80 rows=8435 width=8)
                    Group Key: l.video_id, l.user_id
                    ->  Append  (cost=65556.57..151808.28 rows=8435 width=8)
                          ->  Hash Join  (cost=65556.57..73604.49 rows=411 width=8)
                                Hash Cond: (f.friend_id = l.user_id)
                                ->  Bitmap Heap Scan on friend f  (cost=4.57..78.17 rows=19 width=4)
                                      Recheck Cond: (user_id = 2004)
                                      ->  Bitmap Index Scan on friend_user_id_idx  (cost=0.00..4.57 rows=19 width=0)
                                            Index Cond: (user_id = 2004)
                                ->  Hash  (cost=32739.00..32739.00 rows=2000000 width=8)
                                      ->  Seq Scan on like l  (cost=0.00..32739.00 rows=2000000 width=8)
                          ->  Hash Join  (cost=65561.16..78119.44 rows=8024 width=8)
                                Hash Cond: (f_1.friend_id = l_1.user_id)
                                ->  Nested Loop  (cost=9.16..1639.60 rows=371 width=8)
                                      ->  Bitmap Heap Scan on friend f_1  (cost=4.57..78.17 rows=19 width=4)
                                            Recheck Cond: (user_id = 2004)
                                            ->  Bitmap Index Scan on friend_user_id_idx  (cost=0.00..4.57 rows=19 width=0)
                                                  Index Cond: (user_id = 2004)
                                      ->  Bitmap Heap Scan on friend ff  (cost=4.58..81.98 rows=20 width=4)
                                            Recheck Cond: (user_id = f_1.friend_id)
                                            ->  Bitmap Index Scan on friend_user_id_idx  (cost=0.00..4.58 rows=20 width=0)
                                                  Index Cond: (user_id = f_1.friend_id)
                                ->  Hash  (cost=32739.00..32739.00 rows=2000000 width=8)
                                      ->  Seq Scan on like l_1  (cost=0.00..32739.00 rows=2000000 width=8)
```

#### Analysis
As you can see the query now uses the bitmap index on friend.user_id for both joins and cuts down cost by almost half!

### Query 4

```
SELECT l.video_id, COUNT(*) FROM cats.like l
WHERE l.user_id 
IN (SELECT ly.user_id 
  FROM cats.like lx, cats.like ly 
  WHERE lx.user_id=30442 AND lx.video_id=ly.video_id) 
GROUP BY l.video_id
ORDER BY COUNT(*) 
DESC LIMIT 10
```

```
--takes 2173ms to run
Limit  (cost=214655.54..214655.57 rows=10 width=4)
  ->  Sort  (cost=214655.54..214668.05 rows=5002 width=4)
        Sort Key: (count(*))
        ->  HashAggregate  (cost=214497.43..214547.45 rows=5002 width=4)
              Group Key: l.video_id
              ->  Hash Join  (cost=144250.13..204497.43 rows=2000000 width=4)
                    Hash Cond: (l.user_id = ly.user_id)
                    ->  Seq Scan on like l  (cost=0.00..32739.00 rows=2000000 width=8)
                    ->  Hash  (cost=144245.13..144245.13 rows=400 width=4)
                          ->  HashAggregate  (cost=144241.13..144245.13 rows=400 width=4)
                                Group Key: ly.user_id
                                ->  Hash Join  (cost=65552.00..139122.10 rows=2047612 width=4)
                                      Hash Cond: (lx.video_id = ly.video_id)
                                      ->  Seq Scan on like lx  (cost=0.00..37739.00 rows=4993 width=4)
                                            Filter: (user_id = 30442)
                                      ->  Hash  (cost=32739.00..32739.00 rows=2000000 width=8)
                                            ->  Seq Scan on like ly  (cost=0.00..32739.00 rows=2000000 width=8)
```

#### Analysis
Since we are doing a sequential scan on `like.user_id` it would seem beneficial to add an index there
after adding the index, the runtime is: 1992ms, not much of an improvement

```
CREATE INDEX like_user_id_idx ON cats."like" USING btree (user_id);
```

```
Limit  (cost=186603.76..186603.79 rows=10 width=4)
  ->  Sort  (cost=186603.76..186616.27 rows=5002 width=4)
        Sort Key: (count(*))
        ->  HashAggregate  (cost=186445.65..186495.67 rows=5002 width=4)
              Group Key: l.video_id
              ->  Hash Join  (cost=116198.35..176445.65 rows=2000000 width=4)
                    Hash Cond: (l.user_id = ly.user_id)
                    ->  Seq Scan on like l  (cost=0.00..32739.00 rows=2000000 width=8)
                    ->  Hash  (cost=116193.35..116193.35 rows=400 width=4)
                          ->  HashAggregate  (cost=116189.35..116193.35 rows=400 width=4)
                                Group Key: ly.user_id
                                ->  Hash Join  (cost=65647.12..111070.32 rows=2047612 width=4)
                                      Hash Cond: (lx.video_id = ly.video_id)
                                      ->  Bitmap Heap Scan on like lx  (cost=95.12..9687.22 rows=4993 width=4)
                                            Recheck Cond: (user_id = 30442)
                                            ->  Bitmap Index Scan on like_user_id_idx  (cost=0.00..93.87 rows=4993 width=0)
                                                  Index Cond: (user_id = 30442)
                                      ->  Hash  (cost=32739.00..32739.00 rows=2000000 width=8)
                                            ->  Seq Scan on like ly  (cost=0.00..32739.00 rows=2000000 width=8)
```

#### Analysis
now as you can see it does an index scan on like.user_id and lowers the cost to a max of 9,687 down from a max of 37,739


### Query 5

```
WITH WeightOfUsers AS
(SELECT ly.user_id, LOG(1+COUNT(*)) AS weight FROM cats.like lx, cats.like ly
WHERE lx.user_id=1 AND lx.video_id=ly.video_id 
GROUP BY ly.user_id)
SELECT l.video_id, SUM(w.weight) AS sum_weight 
FROM cats.like l,  WeightOfUsers w
WHERE l.user_id=w.user_id 
GROUP BY l.video_id
ORDER BY sum_weight DESC LIMIT 10
-- Query takes 2610m
```

```
Limit  (cost=256169.77..256169.80 rows=10 width=12)
  CTE weightofusers
    ->  HashAggregate  (cost=149360.16..149367.16 rows=400 width=4)
          Group Key: ly.user_id
          ->  Hash Join  (cost=65552.00..139122.10 rows=2047612 width=4)
                Hash Cond: (lx.video_id = ly.video_id)
                ->  Seq Scan on like lx  (cost=0.00..37739.00 rows=4993 width=4)
                      Filter: (user_id = 30442)
                ->  Hash  (cost=32739.00..32739.00 rows=2000000 width=8)
                      ->  Seq Scan on like ly  (cost=0.00..32739.00 rows=2000000 width=8)
  ->  Sort  (cost=106802.61..106815.12 rows=5002 width=12)
        Sort Key: (sum(w.weight))
        ->  HashAggregate  (cost=106644.50..106694.52 rows=5002 width=12)
              Group Key: l.video_id
              ->  Hash Join  (cost=65552.00..96644.50 rows=2000000 width=12)
                    Hash Cond: (w.user_id = l.user_id)
                    ->  CTE Scan on weightofusers w  (cost=0.00..8.00 rows=400 width=12)
                    ->  Hash  (cost=32739.00..32739.00 rows=2000000 width=8)
                          ->  Seq Scan on like l  (cost=0.00..32739.00 rows=2000000 width=8)
```

#### Analysis

We can see that the planner is doing a sequential scan on like.user_id, so we should add an index to that.


```
CREATE INDEX like_user_id_idx ON cats."like" USING btree (user_id); -- 3168ms
```

```
Limit  (cost=228117.99..228118.02 rows=10 width=12)
  CTE weightofusers
    ->  HashAggregate  (cost=121308.38..121315.38 rows=400 width=4)
          Group Key: ly.user_id
          ->  Hash Join  (cost=65647.12..111070.32 rows=2047612 width=4)
                Hash Cond: (lx.video_id = ly.video_id)
                ->  Bitmap Heap Scan on like lx  (cost=95.12..9687.22 rows=4993 width=4)
                      Recheck Cond: (user_id = 30442)
                      ->  Bitmap Index Scan on like_user_id_idx  (cost=0.00..93.87 rows=4993 width=0)
                            Index Cond: (user_id = 30442)
                ->  Hash  (cost=32739.00..32739.00 rows=2000000 width=8)
                      ->  Seq Scan on like ly  (cost=0.00..32739.00 rows=2000000 width=8)
  ->  Sort  (cost=106802.61..106815.12 rows=5002 width=12)
        Sort Key: (sum(w.weight))
        ->  HashAggregate  (cost=106644.50..106694.52 rows=5002 width=12)
              Group Key: l.video_id
              ->  Hash Join  (cost=65552.00..96644.50 rows=2000000 width=12)
                    Hash Cond: (w.user_id = l.user_id)
                    ->  CTE Scan on weightofusers w  (cost=0.00..8.00 rows=400 width=12)
                    ->  Hash  (cost=32739.00..32739.00 rows=2000000 width=8)
                          ->  Seq Scan on like l  (cost=0.00..32739.00 rows=2000000 width=8)
```

#### Analysis
As you can see we lowered the cost from a max of 32,739 down to a max of 9678 by using an bitmap index scan