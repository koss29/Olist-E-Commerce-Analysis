
-- Monthly revenue, orders, AOV
-- Identify seasonality, growth trends
SELECT 
  DATE_TRUNC(order_purchase_timestamp, MONTH) as month,
  COUNT(DISTINCT o.order_id) as total_orders,
  SUM(payment_value) as total_revenue,
  SUM(payment_value) / COUNT(DISTINCT o.order_id) as AOV
FROM `olist_ecommerce.orders` o 
JOIN `olist_ecommerce.payment` p ON o.order_id = p.order_id
WHERE order_status = 'delivered'
GROUP BY 1
ORDER BY 1;



-- Recency, Frequency, Monetary segmentation
-- Categorize: Champions, Loyal, At-Risk, Lost
WITH rfm AS (
  SELECT 
    customer_id,
    DATE_DIFF(CURRENT_DATE(), DATE(MAX(order_purchase_timestamp)), DAY)as recency,
    COUNT(DISTINCT o.order_id) as frequency,
    SUM(payment_value) as monetary
  FROM `olist_ecommerce.orders` o
  JOIN `olist_ecommerce.payment` p ON o.order_id = p.order_id
  WHERE order_status = 'delivered'
  GROUP BY customer_id
)
SELECT *,
  CASE 
    WHEN recency < 30 AND frequency >= 2 THEN 'Champions'
    WHEN recency < 60 THEN 'Loyal'
    WHEN recency < 180 THEN 'At-Risk'
    ELSE 'Lost'
  END as segment
FROM rfm;



-- Group customers by first purchase month
-- Track retention over time
WITH first_purchase AS (
  SELECT 
    customer_id,
    DATE_TRUNC(MIN(order_purchase_timestamp), MONTH) as cohort_month
  FROM `olist_ecommerce.orders`
  GROUP BY customer_id
)
SELECT 
  cohort_month,
  DATE_DIFF(DATE(DATE_TRUNC(o.order_purchase_timestamp, MONTH)), DATE(fp.cohort_month), MONTH) as month_number,
  COUNT(DISTINCT o.customer_id) as active_customers
FROM `olist_ecommerce.orders` o
JOIN first_purchase fp ON o.customer_id = fp.customer_id
GROUP BY 1, 2
ORDER BY 1, 2;


-- 1. Average Ticket by Payment Type
-- 2. Trends: Volume and Value over time per payment type
WITH monthly_payment_stats AS (
  SELECT 
    DATE_TRUNC(o.order_purchase_timestamp, MONTH) as month,
    p.payment_type,
    COUNT(p.order_id) as transaction_count,
    SUM(p.payment_value) as total_revenue,
    AVG(p.payment_value) as avg_ticket
  FROM `olist_ecommerce.orders` o 
  JOIN `olist_ecommerce.payment` p ON o.order_id = p.order_id
  GROUP BY 1, 2
)

SELECT 
  month,
  payment_type,
  transaction_count,
  ROUND(total_revenue, 2) as total_revenue,
  ROUND(avg_ticket, 2) as average_ticket
FROM monthly_payment_stats
ORDER BY month DESC, average_ticket DESC;

-- Actual vs Estimated Delivery and Correlation with Review Scores
WITH delivery_performance AS (
  SELECT 
    order_id,
    -- Calculate the difference between actual delivery and estimated delivery
    DATE_DIFF(DATE(order_delivered_customer_date), DATE(order_estimated_delivery_date), DAY) as delivery_delay,
    order_status
  FROM `olist_ecommerce.orders`
  WHERE order_status = 'delivered'
),
review_data AS (
  SELECT 
    order_id, 
    review_score 
  FROM `olist_ecommerce.review`
)

SELECT 
  -- Create buckets for delivery performance
  CASE 
    WHEN dp.delivery_delay < 0 THEN 'Early'
    WHEN dp.delivery_delay = 0 THEN 'On Time'
    ELSE 'Late' 
  END as delivery_status,
  
  COUNT(dp.order_id) as total_orders,
  ROUND(AVG(rd.review_score), 2) as avg_review_score,
  ROUND(AVG(dp.delivery_delay), 1) as avg_days_diff
FROM delivery_performance dp
JOIN review_data rd ON dp.order_id = rd.order_id
GROUP BY 1
ORDER BY avg_review_score DESC;

-- Top 10 states by revenue and Average freight cost by state
SELECT 
  c.customer_state,
  COUNT(DISTINCT o.order_id) as total_orders,
  ROUND(SUM(i.price), 2) as total_revenue,
  ROUND(AVG(i.freight_value), 2) as avg_freight_cost
FROM `olist_ecommerce.customers` c 
JOIN `olist_ecommerce.orders` o ON c.customer_id = o.customer_id
JOIN `olist_ecommerce.items` i ON o.order_id = i.order_id
GROUP BY c.customer_state
ORDER BY total_revenue DESC
LIMIT 10;

SELECT 
  p.product_id,
  COUNT(i.order_id) as total_sales,
  ROUND(SUM(i.price), 2) as total_revenue,
  ROUND(AVG(i.price), 2) as avg_price
FROM `olist_ecommerce.items` i
JOIN `olist_ecommerce.product` p ON i.product_id = p.product_id
GROUP BY p.product_id
ORDER BY total_sales DESC
LIMIT 10;
