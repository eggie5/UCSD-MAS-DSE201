# Hmwk3 

> For each query, report the indices that you used by writing the query you used to create them.
NOTE: as mentioned before, consider each query to be independent of the other. Eg. If you used video_id for q1, and used video_id and user_id for q2, make sure you mention both indices in the answer for q2.
 
> For each query, report the final "cost" you get in the explain output and the estimated time. It is ok if you report the entire query plan but what matters is the final cost (topmost line).

## 201Cats

### Query 1

```sql
SELECT video_id, COUNT(*) AS like_no 
FROM cats.likes 
GROUP BY video_id
ORDER BY like_no DESC 
LIMIT 10
```

```sql
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

```sql
SELECT l.video_id, COUNT(*) AS like_no 
FROM cats.friend f, cats.like l
WHERE f.user_id=2004
AND f.friend_id=l.user_id 
GROUP BY l.video_id 
ORDER BY like_no DESC 
LIMIT 10
--870ms
```

```sql
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

```sql
CREATE INDEX friend_user_id_idx ON cats.friend USING btree (user_id); --3964ms
```

The query only takes 685ms now. The like.user_id index did not help any extra:


```sql
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

```sql
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


```sql
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

```sql
CREATE INDEX friend_user_id_idx ON cats.friend USING btree (user_id); -- 3627ms
```

Now the query now only takes 1331ms, half the time

```sql
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

```sql
SELECT l.video_id, COUNT(*) FROM cats.like l
WHERE l.user_id 
IN (SELECT ly.user_id 
  FROM cats.like lx, cats.like ly 
  WHERE lx.user_id=30442 AND lx.video_id=ly.video_id) 
GROUP BY l.video_id
ORDER BY COUNT(*) 
DESC LIMIT 10
```

```sql
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

```sql
CREATE INDEX like_user_id_idx ON cats."like" USING btree (user_id);
```

```sql
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

```sql
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

```sql
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


```sql
CREATE INDEX like_user_id_idx ON cats."like" USING btree (user_id); -- 3168ms
```

```sql
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
