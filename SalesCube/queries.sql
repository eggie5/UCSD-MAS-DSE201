--
-- 1. Show the total sales (quantity sold and dollar value) for each customer.


select customer.customer_id, customer.customer_name, SUM(quantity) as quantity, SUM(price) as dollar_value 
from sales.customer inner join sales.sale on sales.sale.customer_id = customer.customer_id
GROUP BY customer.customer_id 
order by quantity

--Show the total sales for each state.

select state.state_name, state.state_id, SUM(sale.price) from sales.state
inner join sales.customer on customer.state_id = state.state_id
inner join sales.sale on sale.customer_id = customer.customer_id
GROUP BY state.state_id


-- 3. Show the total sales for each product, for a given customer. Only products that were actually
-- bought by the given customer. Order by dollar value.

select customer_id, product.product_id, product.product_name, SUM(sale.quantity), SUM(sale.price) sum_total 
from sales.sale
inner join sales.product on sale.product_id = product.product_id
where customer_id=335
group by product.product_id, customer_id
order by sum_total desc



-- 4. Show the total sales for each product and customer. Order by dollar value.

select customer_id, product.product_id, product.product_name, SUM(sale.quantity), SUM(sale.price) sum_total 
from sales.sale
inner join sales.product on sale.product_id = product.product_id
group by product.product_id, customer_id
order by sum_total desc

-- 5. Show the total sales for each product category and state.

select category.category_name, state.state_name, SUM(price) 
from sales.sale
inner join sales.product on sale.product_id = product.product_id
inner join sales.customer on sale.customer_id = customer.customer_id
inner join sales.category on product.category_id = category.category_id
inner join sales.state on state.state_id = customer.state_id
GROUP BY category.category_id, state.state_id


-- 6. For each one of the top 20 product categories and top 20 customers, it returns a tuple (top product CATEGORY, top customer, quantity sold, dollar value)

WITH top_customers AS(
select customer.customer_name as cust_name, SUM(sale.price) as cust_sales_total from sales.customer
inner join sales.sale on sale.customer_id = customer.customer_id
inner join sales.product on sale.product_id = product.product_id
inner join sales.category on product.category_id = category.category_id
group by customer.customer_name
order by cust_sales_total desc 
limit 20
),top_categories AS(
select category.category_name as cat_name, SUM(sale.quantity) as cat_quant_sum, SUM(sale.price) as cat_sales_total 
from sales.category
inner join sales.product on product.category_id = category.category_id
inner join sales.sale on sale.product_id = product.product_id
group by category.category_id
order by cat_sales_total desc
limit 20
)
select cat_name, cust_name, cat_quant_sum, cat_sales_total 
from  top_categories
CROSS JOIN top_customers
