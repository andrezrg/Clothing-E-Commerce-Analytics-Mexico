
SET @year = 2024;

-- ------------------------------------------------------------------------------------------------------------------------------------------------

-- score-cards
WITH cte_query AS (
	SELECT 
		SUM(total_amount) AS revenue,
		COUNT(*) AS orders,
		ROUND(AVG(review), 1) AS avg_review
	FROM orders
	WHERE TRUE
		AND order_date BETWEEN DATE(CONCAT(@year,'-01-01')) AND DATE(CONCAT(@year,'-12-31'))
)
SELECT 
	CONCAT('$', FORMAT(revenue, 2)) AS 'Revenue',
    FORMAT(orders, 0) AS 'Orders',
    avg_review AS 'Avg Review'
FROM cte_query;

-- ############################################################################################

-- monthly-sales-performance
WITH cte_query AS (
	SELECT 
		MONTH(order_date) AS month_num,
		MONTHNAME(order_date) AS month_name,
		COUNT(*) AS orders,
		SUM(quantity) AS items_sold,
		SUM(total_amount) AS revenue
	FROM orders
	WHERE TRUE
		AND order_date BETWEEN DATE(CONCAT(@year,'-01-01')) AND DATE(CONCAT(@year,'-12-31'))
	GROUP BY month_num
)
SELECT 
	month_name AS 'Month',
    FORMAT(orders, 0) AS 'Orders',
	FORMAT(items_sold, 0) AS 'Items Sold',
    CONCAT('$', FORMAT(revenue, 2)) AS 'Revenue',
    IF(MAX(revenue) OVER () = revenue, '←', '') 'Max Revenue'
FROM cte_query
ORDER BY month_num;

-- ############################################################################################

SET @age_bin = 5;

-- total-orders-by-age
WITH cte_query AS (
	SELECT 
		MIN(age) AS age,
		(
			CASE @age_bin
				WHEN 1 THEN age
				ELSE CONCAT(age - MOD(age, @age_bin), '-', (age - MOD(age, @age_bin)) + @age_bin - 1) 
			END
		) AS age_bin,
		COUNT(*) AS orders
	FROM orders
	WHERE TRUE
			AND order_date BETWEEN DATE(CONCAT(@year,'-01-01')) AND DATE(CONCAT(@year,'-12-31'))
	GROUP BY age_bin
)
SELECT
	age_bin AS 'Age',
    FORMAT(orders, 0) AS 'Orders',
    REPEAT('●', ROUND(orders/SUM(orders) OVER () * 100, 0)) AS 'Bar',
    IF(MAX(orders) OVER () = orders, '←', '') 'Max Orders'
FROM cte_query
ORDER BY age;
        
-- ############################################################################################

-- sales-by-state
WITH cte_query AS (
	SELECT 
		state, 
		COUNT(*) AS orders,
		SUM(quantity) AS items_sold,
		SUM(total_amount) AS revenue
	FROM orders
	WHERE TRUE
		AND order_date BETWEEN DATE(CONCAT(@year,'-01-01')) AND DATE(CONCAT(@year,'-12-31'))
	GROUP BY state
)
SELECT 
	state AS 'State',
    CONCAT('#', ROW_NUMBER() OVER (ORDER BY revenue DESC)) AS 'Rank',
    FORMAT(orders, 0) AS 'Orders',
	FORMAT(items_sold, 0) AS 'Items Sold',
    CONCAT('$', FORMAT(revenue, 2)) AS 'Revenue'
FROM cte_query
ORDER BY revenue DESC;

-- ############################################################################################

SET @topN = 15;

-- top-n-items
WITH cte_query AS (
	SELECT
		item,
		COUNT(*) AS orders,
		SUM(quantity) AS pieces_sold,
		SUM(total_amount) AS revenue
	FROM orders
	WHERE TRUE
		AND order_date BETWEEN DATE(CONCAT(@year,'-01-01')) AND DATE(CONCAT(@year,'-12-31'))
	GROUP BY item
), cte_rank AS (
	SELECT 
		ROW_NUMBER() OVER (ORDER BY pieces_sold DESC) AS `rank`,
		item,
		pieces_sold,
        orders,
        revenue
	FROM cte_query
), cte_top_n AS (
	SELECT 
		item AS 'Item',
		CONCAT('#', `rank`) AS 'Rank',
		FORMAT(pieces_sold, 0) AS 'Pieces Sold'
	FROM cte_rank
	WHERE TRUE
		AND `rank` <= @topN
), cte_top_n_summary AS (
	SELECT 
		FORMAT(SUM(orders), 0) AS 'Orders',
		FORMAT(SUM(pieces_sold), 0) AS 'Items Sold',
		CONCAT('$', FORMAT(SUM(revenue), 2)) AS 'Revenue'
	FROM cte_rank
	WHERE TRUE
		AND `rank` <= @topN
)
-- SELECT * FROM cte_top_n_summary;
SELECT * FROM cte_top_n;

-- ############################################################################################

-- category-reviews
WITH cte_query AS (
	SELECT 
		category,
		ROUND(AVG(review), 1) AS avg_review
	FROM orders
	WHERE TRUE
		AND order_date BETWEEN DATE(CONCAT(@year,'-01-01')) AND DATE(CONCAT(@year,'-12-31'))
	GROUP BY category
)
SELECT 
	category AS 'Category',
    CONCAT('#', ROW_NUMBER() OVER (ORDER BY avg_review DESC)) AS 'Rank',
    avg_review AS 'Avg review'
FROM cte_query;

-- ############################################################################################

-- review-distribution
WITH cte_query AS (
	SELECT 
		review AS stars,
		COUNT(*) AS total_reviews
	FROM orders
	WHERE TRUE
		AND order_date BETWEEN DATE(CONCAT(@year,'-01-01')) AND DATE(CONCAT(@year,'-12-31'))
	GROUP BY review
)
SELECT 
	RPAD(REPEAT('★', stars), 5, '☆') AS 'Stars',
    RPAD(REPEAT('●', ROUND(total_reviews/SUM(total_reviews) OVER () * 25, 0)), 25, '○') AS 'Bar',
    CONCAT(ROUND(total_reviews/SUM(total_reviews) OVER () * 100, 0), '%') AS '% of Total',
    FORMAT(total_reviews, 0) AS 'Reviews'
FROM cte_query
ORDER BY cte_query.stars DESC;

-- ############################################################################################

-- clothing-size-distribution-by-gender
WITH cte_query AS (
	SELECT 
		size,
		SUM(quantity) AS pieces_sold,
		SUM(IF(gender = 'male', quantity, 0)) AS male,
		SUM(IF(gender = 'female', quantity, 0)) AS female,
		SUM(IF(gender = 'non-specified', quantity, 0)) AS non_specified
	FROM orders
	WHERE TRUE
		AND order_date BETWEEN DATE(CONCAT(@year,'-01-01')) AND DATE(CONCAT(@year,'-12-31'))
	GROUP BY size
)
SELECT 
	size AS 'Size',
    FORMAT(pieces_sold, 0) AS 'Pieces Sold',
    CONCAT(FORMAT(pieces_sold/SUM(pieces_sold) OVER ()*100, 2), '%') AS '% of Total',
    FORMAT(male, 0) AS 'Male Pieces Sold',
    FORMAT(female, 0) AS 'Female Pieces Sold',
    FORMAT(non_specified, 0) AS 'Non-Specified Pieces Sold',
    CONCAT(FORMAT(male/pieces_sold*100, 2), '%') AS 'Male % of Total',
    CONCAT(FORMAT(female/pieces_sold*100, 2), '%') AS 'Female % of Total',
    CONCAT(FORMAT(non_specified/pieces_sold*100, 2), '%') AS 'Non-Specified % of Total'
FROM cte_query
ORDER BY FIELD(size, 'S', 'M', 'L', 'XL');

-- ############################################################################################

-- size-distribution
WITH cte_query AS (
	SELECT 
		size,
		SUM(quantity) AS pieces_sold,
		SUM(total_amount) AS revenue
	FROM orders
	WHERE TRUE
		AND order_date BETWEEN DATE(CONCAT(@year,'-01-01')) AND DATE(CONCAT(@year,'-12-31'))
	GROUP BY size
)
SELECT 
	size AS 'Size',
	CONCAT('#', ROW_NUMBER() OVER (ORDER BY pieces_sold DESC)) AS 'Rank',
    REPEAT('●', ROUND(pieces_sold/SUM(pieces_sold) OVER () * 50, 0)) AS 'Bar',
    FORMAT(pieces_sold, 0) AS 'Pieces Sold'
FROM cte_query
ORDER BY FIELD(size, 'S', 'M', 'L', 'XL');

-- ############################################################################################

-- payment-type-distribution
WITH cte_query AS (
	SELECT 
		payment_type,
		COUNT(*) AS orders
	FROM orders
	WHERE TRUE
		AND order_date BETWEEN DATE(CONCAT(@year,'-01-01')) AND DATE(CONCAT(@year,'-12-31'))
	GROUP BY payment_type
)
SELECT 
	payment_type AS 'Payment Type',
    CONCAT('#', ROW_NUMBER() OVER (ORDER BY orders DESC)) AS 'Rank',
    FORMAT(orders, 0) AS 'Orders',
    REPEAT('●', ROUND(orders/SUM(orders) OVER () * 50, 0)) AS 'Bar',
    CONCAT(ROUND(orders/SUM(orders) OVER () * 100, 2), '%') AS '% of Total'
FROM cte_query;