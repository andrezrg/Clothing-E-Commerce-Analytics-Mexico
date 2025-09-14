
CREATE TABLE orders (
	order_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_date DATE NOT NULL,
    state VARCHAR(19) NOT NULL,
    category VARCHAR(17) NOT NULL,
    item VARCHAR(15) NOT NULL,
    gender VARCHAR(13) NOT NULL,
    size VARCHAR(2) NOT NULL,
    is_subscriber TINYINT NOT NULL,
    quantity INT NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL,
    review TINYINT NOT NULL,
    age TINYINT NOT NULL,
    payment_type VARCHAR(13)
);

SET cte_max_recursion_depth = 50000;

-- INSERT INTO orders
WITH RECURSIVE cte_rows AS (
    SELECT 1 AS num, RAND() AS quantity_rnd
    UNION ALL
    SELECT num + 1, RAND()
    FROM cte_rows 
    WHERE num < 50000
), cte_dates AS (
	-- Generate dates for the last 4 years (48 months), excluding the current year
	-- Each row is assigned a sequential date_id
	-- Example: starting at Dec of last year and going back month by month
	SELECT 
		1 AS date_id,
		DATE(DATE_FORMAT(CURDATE() - INTERVAL 1 YEAR, '%Y-12-01')) AS date_name
	UNION ALL
    SELECT
		date_id + 1,
        date_name - INTERVAL 1 MONTH
	FROM cte_dates
    WHERE date_id < 48
), cte_sizes (size_id, size_name) AS (
	VALUES
		ROW(1,'M'),
        ROW(2,'XL'),
        ROW(3,'L'),
        ROW(4,'S')
), cte_payment_types (payment_type_id, payment_type_name) AS (
    VALUES
        ROW(1, 'Credit Card'),
        ROW(2, 'Debit Card'),
        ROW(3, 'Cash'),
        ROW(4, 'PayPal'),
        ROW(5, 'Bank Transfer')
), cte_genders (gender_id, gender_name) AS (
	VALUES
		ROW(1,'Male'),
		ROW(2,'Female'),
		ROW(3,'Non-specified')
), cte_items (item_id, category_id, item_name, price) AS (
	VALUES
		ROW(1, 1, 'Swim Shorts', 150.55),
		ROW(2, 1, 'Rash Guard', 180.90),
		ROW(3, 1, 'Board Shorts', 120.30),
		ROW(4, 2, 'T-Shirt', 99.99),
		ROW(5, 2, 'Polo Shirt', 135.50),
		ROW(6, 2, 'Tank Top', 89.25),
		ROW(7, 2, 'Button-Up Shirt', 220.40),
		ROW(8, 3, 'Jeans', 299.99),
		ROW(9, 3, 'Cargo Pants', 250.75),
		ROW(10, 3, 'Shorts', 145.60),
		ROW(11, 3, 'Utility Pants', 160.00),
		ROW(12, 4, 'Jacket', 480.90),
		ROW(13, 4, 'Coat', 650.00),
		ROW(14, 4, 'Hoodie', 275.45),
		ROW(15, 4, 'Blazer', 520.30),
		ROW(16, 5, 'Jumpsuit', 899.99),
		ROW(17, 5, 'Tunic', 340.20),
		ROW(18, 5, 'Rompers', 720.10),
		ROW(19, 5, 'Kaftan', 415.35),
		ROW(20, 6, 'Sneakers', 599.50),
		ROW(21, 6, 'Loafers', 480.40),
		ROW(22, 6, 'Sandals', 210.25),
		ROW(23, 6, 'Slip-Ons', 750.00),
		ROW(24, 6, 'Boots', 890.99),
		ROW(25, 7, 'Belt', 120.60),
		ROW(26, 7, 'Scarf', 140.80),
		ROW(27, 7, 'Cap', 99.40),
		ROW(28, 7, 'Messenger Bag', 650.75),
		ROW(29, 7, 'Backpack', 540.90),
		ROW(30, 7, 'Wallet', 330.25),
		ROW(31, 8, 'Compression Top', 250.55),
		ROW(32, 8, 'Training Pants', 310.70),
		ROW(33, 8, 'Joggers', 345.10),
		ROW(34, 8, 'Track Jacket', 420.60),
		ROW(35, 8, 'Running Shorts', 180.30)
), cte_categories (category_id, category_name) AS (
    VALUES
		ROW(1, 'Swimwear'),
		ROW(2, 'Tops'),
		ROW(3, 'Bottoms'),
		ROW(4, 'Outerwear'),
		ROW(5, 'One-Piece Outfits'),
		ROW(6, 'Shoes'),
		ROW(7, 'Accessories'),
		ROW(8, 'Activewear')
), cte_states AS (
	SELECT DISTINCT *,

        -- Generate a JSON array for item_ids
        -- Each array corresponds to a state, allowing item distribution to vary by state
        -- The ORDER BY clause works as follows:
        --   ● "i.item_id IN (...)" - Prioritizes a set of items to simulate "most sold" products
        --   ● "c.rnd_cat" - Groups items by randomized category order
        --   ● "RAND()" - Randomizes remaining items within each category
        -- This simulates best-sellers per state while maintaining variation by category
        (
			SELECT CAST(CONCAT('[',GROUP_CONCAT(
					i.item_id 
					ORDER BY 
					i.item_id IN (2, 3, 7, 11, 15, 16, 18, 19, 21, 23, 28, 30, 31, 34), 
					c.rnd_cat, 
					RAND()
				),']') AS JSON) AS item_array
			FROM cte_items AS i
			JOIN LATERAL (
				SELECT DISTINCT category_id, RAND() AS rnd_cat
				FROM cte_categories
				WHERE i.item_id IS NOT NULL 
			) AS c USING(category_id)
			WHERE states.state_id IS NOT NULL
        ) AS item_ids,
        
        -- Generate a JSON array for date_ids
        -- Each array corresponds to a state, allowing date distribution to vary by state
        -- The ORDER BY clause works as follows:
        --   ● "YEAR(date_name) DESC" - Years are sorted in descending order
        --   ● "MONTH(date_name) IN (6,7,8,9) DESC" - Months Jun–Sep prioritized to simulate seasonal peaks
        --   ● "RAND()" - Randomizes months within each year
        -- This simulates yearly sales cycles with peaks in summer
        (
			SELECT CAST(CONCAT('[',GROUP_CONCAT(
					date_id 
                    ORDER BY 
                    YEAR(date_name) DESC, 
                    MONTH(date_name) IN (6,7,8,9) DESC, 
                    RAND()),
				']') AS JSON) 
			FROM cte_dates
		) AS date_ids,
        
        -- Generate a JSON array of arrays for gender_ids
        -- Each sub-array corresponds to a size, allowing gender distribution to vary by state and size
        -- The ORDER BY clause works as follows:
        --   ● "g.gender_id IN (1,2) DESC" - Prioritizes Male and Female
        --   ● "RAND()" - Randomizes order of remaining genders
        -- This simulates that most cases are gender-specified, while Non-specified (ID 3) appears last
        (
			SELECT JSON_ARRAYAGG(gender_array) 
			FROM (
				SELECT CAST(CONCAT('[',GROUP_CONCAT(
						g.gender_id 
                        ORDER BY 
                        g.gender_id IN (1,2) DESC, 
                        RAND()),
					']') AS JSON) AS gender_array
				FROM cte_genders AS g
				CROSS JOIN cte_sizes AS sz
                WHERE states.state_id IS NOT NULL
				GROUP BY sz.size_id
			) AS t
		) AS gender_ids,
        
        -- Generate a JSON array of arrays for payment_type_ids
        -- Each sub-array corresponds to a gender, allowing payment distribution to vary by state and gender
        -- The ORDER BY clause works as follows:
        --   ● "pt.payment_type_id IN (1,2) DESC" - Prioritizes Credit Card and Debit
        --   ● "pt.payment_type_id IN (3,4) DESC" - Next comes Cash and PayPal
        --   ● "RAND()" - Bank Transfer always last, as least frequent
        -- This simulates realistic payment preferences
        (
			SELECT JSON_ARRAYAGG(gender_array) 
			FROM (
				SELECT CAST(CONCAT('[',GROUP_CONCAT(
						pt.payment_type_id 
						ORDER BY 
                        pt.payment_type_id IN (1,2) DESC, 
						pt.payment_type_id IN (3,4) DESC, 
						RAND()),
					']') AS JSON) AS gender_array
				FROM cte_payment_types AS pt
				CROSS JOIN cte_genders AS g
                WHERE states.state_id IS NOT NULL
				GROUP BY g.gender_id
			) AS t
		) AS payment_type_ids,
		
        -- Generate a JSON array of arrays for size_ids
        -- Each sub-array corresponds to an item, allowing size distribution to vary by state and item
        -- The ORDER BY clause works as follows:
        --   ● "FLOOR(POW(RAND(), 2) * (SELECT COUNT(*) FROM cte_sizes)) + 1 = sz.size_id DESC"
        --       - Gives higher probability for one randomly selected size to appear first
        --   ● "RAND()" - Randomizes the order of remaining sizes
        -- This simulates size preferences per item while keeping randomness
        (
			SELECT JSON_ARRAYAGG(size_array) 
			FROM (
				SELECT CAST(CONCAT('[',GROUP_CONCAT(
						sz.size_id 
                        ORDER BY 
                        FLOOR(POW(RAND(), 2) * (SELECT COUNT(*) FROM cte_sizes)) + 1 = sz.size_id DESC, 
                        RAND()),
                    ']') AS JSON) AS size_array
				FROM cte_sizes AS sz
				CROSS JOIN cte_items AS i
                WHERE states.state_id IS NOT NULL
				GROUP BY i.item_id
			) AS t
		) AS size_ids,
        
        -- Generate a JSON array of arrays for review_ids
        -- Each sub-array corresponds to a category, with possible review scores 1–5
        -- The ORDER BY clause works as follows:
        --   ● "IF(RAND() < 0.3, TRUE, num = 5) DESC" - ~30% chance to prioritize 5-star reviews
        --   ● "IF(RAND() < 0.6, TRUE, num IN (3,4)) DESC" - ~60% chance to prioritize 3–4 stars
        --   ● "RAND()" - Randomizes remaining scores
        -- This simulates more frequent high and mid reviews, fewer low ones
        (
			SELECT JSON_ARRAYAGG(review_array) 
			FROM (
				SELECT CAST(CONCAT('[',GROUP_CONCAT(
						num 
						ORDER BY 
                        IF(RAND() < 0.3, TRUE, num = 5) DESC, 
						IF(RAND() < 0.6, TRUE, num IN (3,4)) DESC, 
						RAND()),
					']') AS JSON) AS review_array
				FROM cte_rows AS r
				JOIN cte_categories AS c
				WHERE num <= 5
				GROUP BY category_id
			) AS t
		) AS review_ids,
        
        -- Generate a JSON array for age_ids
        -- Values range from 15 to 62
        -- The ORDER BY clause works as follows:
        --   ● "(23–27) DESC" - Most common buyers
        --   ● "(20–22, 28–35) DESC" - Next frequent groups
        --   ● "(15–19, 36–49) DESC" - Less common groups
        --   ● "(50–58) DESC" - Older but active buyers
        --   ● "(59–62) DESC" - Least frequent buyers
        --   ● "RAND()" - Randomizes ages within each group
        -- This simulates realistic age distribution in purchases
        (
			SELECT CAST(CONCAT('[', GROUP_CONCAT(
					num 
					ORDER BY
					(num BETWEEN 23 AND 27) DESC, 
					(num BETWEEN 20 AND 22 OR num BETWEEN 28 AND 35) DESC,
					(num BETWEEN 15 AND 19 OR num BETWEEN 36 AND 49) DESC,
					(num BETWEEN 50 AND 58) DESC,
					(num BETWEEN 59 AND 62) DESC,
					RAND()), 
				']') AS JSON)
			FROM cte_rows AS a 
            WHERE num BETWEEN 15 AND 62
		) AS age_ids
	FROM (
		VALUES
			ROW(1, 'Estado de México'),
			ROW(2, 'Ciudad de México'),
			ROW(3, 'Jalisco'),
			ROW(4, 'Veracruz'),
			ROW(5, 'Puebla'),
			ROW(6, 'Guanajuato'),
			ROW(7, 'Nuevo León'),
			ROW(8, 'Chiapas'),
			ROW(9, 'Michoacán'),
			ROW(10, 'Oaxaca'),
			ROW(11, 'Chihuahua'),
			ROW(12, 'Guerrero'),
			ROW(13, 'Coahuila'),
			ROW(14, 'Hidalgo'),
			ROW(15, 'Sinaloa'),
			ROW(16, 'Sonora'),
			ROW(17, 'Tamaulipas'),
			ROW(18, 'San Luis Potosí'),
			ROW(19, 'Tabasco'),
			ROW(20, 'Yucatán'),
			ROW(21, 'Querétaro'),
			ROW(22, 'Morelos'),
			ROW(23, 'Durango'),
			ROW(24, 'Quintana Roo'),
			ROW(25, 'Zacatecas'),
			ROW(26, 'Aguascalientes'),
			ROW(27, 'Tlaxcala'),
			ROW(28, 'Nayarit'),
			ROW(29, 'Baja California'),
			ROW(30, 'Campeche'),
			ROW(31, 'Colima'),
			ROW(32, 'Baja California Sur')
	) AS states (state_id, state_name)
), cte_random AS (
	-- CTE: cte_random
	-- Generates 300 random variants of state orderings to avoid equal or too-similar distributions across states
	-- Each variant produces a JSON array of state_ids ordered as follows:
	--   ● "state_id BETWEEN 1 AND 7 DESC" - States 1–7 prioritized first, representing the most populated
	--   ● "state_id BETWEEN 27 AND 32" - States with lowest population (27–32) pushed to the end
	--   ● "RAND()" - Remaining states randomized in the middle of the sequence
	-- Using 300 variants is sufficient to ensure diversity of distributions, though any number could be used
	SELECT 
		DISTINCT
		num AS random_id,
        (
			SELECT 
				CAST(CONCAT('[',GROUP_CONCAT(
					state_id 
					ORDER BY 
					state_id BETWEEN 1 AND 7 DESC, 
					state_id BETWEEN 27 AND 32, 
					RAND()
				),']') AS JSON) 
            FROM cte_states
		) AS state_ids
    FROM cte_rows
	WHERE num < 300 + 1
), cte_dataset AS (
SELECT
	t.num AS order_id,
    d.date_name + INTERVAL FLOOR(RAND() * (DAY(LAST_DAY(d.date_name)) - 1)) DAY AS order_date,
	s.state_name AS state,
	c.category_name AS category,
    i.item_name AS item,
    g.gender_name AS gender,
    sz.size_name AS size,
    NOT RAND() < MOD(CAST(CONCAT('0.', d.date_id, s.state_id, c.category_id, i.item_id, SUBSTRING(RAND(), 3)) AS DOUBLE), 0.3) + 0.6 AS is_subscriber,
    t.quantity,
    ROUND(t.quantity * i.price, 2) AS total_amount,
    FLOOR(JSON_EXTRACT(s.review_ids, CONCAT('$[',(c.category_id - 1),'][', idx_review, ']'))) AS review,
    FLOOR(JSON_EXTRACT(s.age_ids, CONCAT('$[', idx_age, ']'))) AS age,
	pt.payment_type_name AS payment_type
FROM (
	-- Note: POW(RAND(), N): the higher the N, the more likely smaller indices appear
	SELECT DISTINCT num,
    
        --  random_id → Random integer from 1–300, proritizing towards lower values (bias from POW(RAND(), 2))
		FLOOR(1 + POW(RAND(), 2) * 300) AS random_id,
        
        -- idx_state → Random integer 0–31, skewed to prefer smaller values (POW(RAND(), 1.5))
		FLOOR(POW(RAND(), 1.5) * 32) AS idx_state,
        
        -- idx_date → Random integer 0–47, most likely to show up smaller idx positions (POW(RAND(), 1.25))
		FLOOR(POW(RAND(), 1.25) * 48) AS idx_date,
        
        -- idx_item → Random integer 0–34, stronger skew towards lower idx positions (POW(RAND(), 2))
		FLOOR(POW(RAND(), 2) * 35) AS idx_item,
        
        -- idx_gender → Using POW(RAND(), 2) makes index 2 (non-specified) less likely.
		-- If it still hits 2, retry with POW(RAND(), 1.5) to further reduce its chance.
		IF(FLOOR(POW(RAND(), 2) * 3) = (3 - 1), FLOOR(POW(RAND(), 1.5) * 3), FLOOR(POW(RAND(), 2) * (3 - 1))) AS idx_gender,
        
        -- idx_payment_type → Similar logic as gender but with 5 (Bank Transfer)
		IF(FLOOR(POW(RAND(), 1) * 5) = (5 - 1), FLOOR(POW(RAND(), 1.5) * 5), FLOOR(POW(RAND(), 2) * (5 - 1))) AS idx_payment_type,
        
        -- idx_size → Random integer 0–3 (4 possible sizes), biased by POW(RAND(), 2)
		FLOOR(POW(RAND(), 2) * 4) AS idx_size,
        
        -- idx_review → Random integer 0–4 (5 review options), heavily biased to favor lower values (POW(RAND(), 4))
        FLOOR(POW(RAND(), 4) * 5) AS idx_review,
        
        -- idx_age → Random integer 0–47, exponent N varies between 1.8–2 to slightly bias toward smaller indices
		FLOOR(POW(RAND(), (1.8 + (2 - 1.8) * RAND())) * 47) AS idx_age,
        
		CASE
			WHEN quantity_rnd < 0.96 THEN 1                          -- 96% chance: purchase = 1
			WHEN quantity_rnd < 0.98 THEN 2                          -- 2% chance: purchase = 2
			WHEN quantity_rnd < 0.99 THEN FLOOR(3 + (RAND() * 4))    -- 1% chance: purchase = 3–6
			WHEN quantity_rnd < 0.999 THEN FLOOR(7 + (RAND() * 9))   -- 0.9% chance: purchase = 7–15
			ELSE FLOOR(16 + (RAND() * 35))                           -- 0.1% chance: purchase = 16–50
		END AS quantity
	FROM cte_rows
) AS t
JOIN cte_random AS r USING(random_id)
JOIN cte_states AS s ON state_id = FLOOR(JSON_EXTRACT(r.state_ids, CONCAT('$[', idx_state, ']')))
JOIN cte_dates AS d ON date_id = FLOOR(JSON_EXTRACT(s.date_ids, CONCAT('$[', idx_date, ']')))
JOIN cte_items AS i ON item_id = FLOOR(JSON_EXTRACT(s.item_ids, CONCAT('$[', idx_item, ']')))
JOIN cte_sizes AS sz ON size_id = FLOOR(JSON_EXTRACT(s.size_ids, CONCAT('$[',(i.item_id - 1),'][', idx_size, ']')))
JOIN cte_categories AS c USING(category_id)
JOIN cte_genders AS g ON gender_id = FLOOR(JSON_EXTRACT(s.gender_ids, CONCAT('$[',(size_id - 1),'][', idx_gender, ']')))
JOIN cte_payment_types AS pt ON payment_type_id = FLOOR(JSON_EXTRACT(s.payment_type_ids, CONCAT('$[',(g.gender_id - 1),'][', idx_payment_type, ']')))
)
SELECT * FROM cte_dataset ORDER BY order_id;