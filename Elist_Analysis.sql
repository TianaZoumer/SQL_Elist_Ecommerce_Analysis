--aggregates purchase_quarter
--counts orders by granularity of orders.id
--sum and avg of usd_price accounts for sales trends
--returns groups of quarter and NA region
SELECT 
  DATE_TRUNC(orders.purchase_ts, QUARTER) AS purchase_quarter,
  geo_lookup.region,
  COUNT(DISTINCT orders.id) AS order_count,
  ROUND(SUM(orders.usd_price), 2) AS total_sales,
  ROUND(AVG(orders.usd_price), 2) AS aov
FROM elist.orders orders
LEFT JOIN elist.customers customers
  ON orders.customer_id = customers.id
LEFT JOIN elist.geo_lookup geo_lookup
  ON geo_lookup.country = customers.country_code
WHERE lower(orders.product_name) LIKE '%macbook%'
  AND geo_lookup.region = 'NA'
GROUP BY 1, 2
ORDER BY 1 DESC, 2


--count the number of refunds per month (non-null refund date) and calculate refund rate
--refund rate is equal to the total number of refunds divided by the total number of orders
SELECT 
  DATE_TRUNC(orders.purchase_ts, MONTH) AS purchase_month,
  SUM(CASE WHEN order_status.refund_ts IS NOT NULL THEN 1 ELSE 0 END) AS refunds,
  SUM(CASE WHEN order_status.refund_ts IS NOT NULL THEN 1 ELSE 0 END)/COUNT(orders.id) AS refund_rate
FROM elist.orders orders
LEFT JOIN elist.order_status order_status
  ON orders.id = order_status.order_id
GROUP BY 1
ORDER BY 1;

--count the number of refunds, filtered to 2021
--only include products with 'apple' or 'mac' in the name - use lowercase to account for differences
SELECT 
  date_trunc(order_status.refund_ts, MONTH) AS refund_month,
  SUM(CASE WHEN order_status.refund_ts IS NOT NULL THEN 1 ELSE 0 END) as refunds,
FROM elist.orders orders
LEFT JOIN elist.order_status order_status
  ON orders.id = order_status.order_id
WHERE extract(YEAR FROM order_status.refund_ts) = 2021
  AND (lower(orders.product_name) LIKE '%mac%'
  OR lower(orders.product_name) LIKE '%apple%')
GROUP BY 1
ORDER BY 1;

--clean up product name
--calculate refund rate across products
--order products in descending order of refund rate to get the top 3 frequently refunded by refund rate
SELECT 
  CASE WHEN product_name = '27in"" 4k gaming monitor' THEN '27in 4K gaming monitor' ELSE product_name END AS product_clean,
  SUM(CASE WHEN refund_ts IS NOT NULL THEN 1 ELSE 0 END) AS refunds,
  SUM(CASE WHEN refund_ts IS NOT NULL THEN 1 ELSE 0 END)/COUNT(DISTINCT orders.id) AS refund_rate
FROM elist.orders orders
LEFT JOIN elist.order_status order_status
  ON orders.id = order_status.order_id
GROUP BY 1
ORDER BY 3 desc;

--order products in descending order of refund count to get the top 3 highest refunded by count
SELECT 
  CASE WHEN product_name = '27in"" 4k gaming monitor' then '27in 4K gaming monitor' else product_name END as product_clean,
  SUM(CASE WHEN refund_ts is not null then 1 else 0 END) as refunds,
  SUM(CASE WHEN refund_ts is not null then 1 else 0 END)/COUNT(distinct orders.id) as refund_rate
FROM elist.orders orders
LEFT JOIN elist.order_status order_status
  ON orders.id = order_status.order_id
GROUP BY 1
ORDER BY 2 desc;

--aov and count of new customers by account creation channel in first 2 months of 2022
--number of loyalty program purchases by account creation channel, ordered by AOV 
SELECT 
  CASE WHEN customers.account_creation_method IS NULL THEN 'unknown' ELSE customers.account_creation_method END AS account_creation_method,
  AVG(orders.usd_price) AS aov,
  COUNT(distinct customers.id) AS num_customers,
  SUM(customers.loyalty_program) AS num_loyalty
FROM elist.orders orders
LEFT JOIN elist.customers customers
  ON orders.customer_id = customers.id
WHERE orders.purchase_ts BETWEEN '2022-01-01' AND '2022-02-01'
GROUP BY 1
ORDER BY 2 DESC;

--calculate days to purchase by taking date difference
WITH days_to_purchase_cte AS (
  SELECT customers.id AS customer_id,
  orders.id AS order_id,
  customers.created_on,
  orders.purchase_ts,
  date_diff(orders.purchase_ts, customers.created_on, DAY) AS days_to_purchase
FROM elist.orders orders
LEFT JOIN elist.customers customers
  ON orders.customer_id = customers.id
ORDER BY 1
)
--take the average of the number of days to purchase
SELECT AVG(days_to_purchase)
FROM days_to_purchase_cte

--calculate the total number of orders and total sales by region and registration channel
--rank the channels by total sales, order dataset by this ranking to surface top channels per region first
WITH region_orders AS (
  SELECT geo_lookup.region,
  customers.marketing_channel,
  COUNT(DISTINCT orders.id) AS num_orders,
  SUM(orders.usd_price) AS total_sales,
  AVG(orders.usd_price) AS aov
FROM elist.orders orders
LEFT JOIN elist.customers customers
  ON orders.customer_id = customers.id
LEFT JOIN elist.geo_lookup geo_lookup
  ON customers.country_code = geo_lookup.country
GROUP BY 1, 2
ORDER BY 1, 2
)
SELECT *,
  row_number() over (partition BY region ORDER BY num_orders DESC) AS ranking
FROM region_orders
ORDER BY 6 asc
