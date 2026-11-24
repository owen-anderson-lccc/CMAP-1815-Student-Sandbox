-- ============================================================================
-- CMAP 1815: Introduction to Modern SQL
-- Unit 6: Query Modularity, CTEs & Window Functions
-- In-Class Paired Coding Challenges
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CHALLENGE 1: Refactoring Nested Subqueries into CTEs (Session 1)
-- Scenario: Refactor this messy nested query into a clean, readable CTE pipeline:
-- SELECT * FROM (
--     SELECT department, AVG(salary) as avg_sal
--     FROM employees
--     WHERE is_active = TRUE
--     GROUP BY department
-- ) sub WHERE avg_sal > 65000;
-- ----------------------------------------------------------------------------

-- Write your modular CTE solution below:

WITH active_dept_averages AS (
    SELECT
        department,
        AVG(salary) AS avg_sal
    FROM employees
    WHERE is_active = TRUE
    GROUP BY department
)
SELECT
    department,
    avg_sal
FROM active_dept_averages
WHERE avg_sal > 65000;

-- ----------------------------------------------------------------------------
-- CHALLENGE 2: Multi-Tier Customer Spend Pipeline (Session 1)
-- Scenario: The Marketing Director wants customer lifetime metrics.
-- Task:
-- 1. CTE 1 (order_totals): Join orders and order_lines to calculate total
--    spend per order (order_id, customer_id, order_subtotal).
-- 2. CTE 2 (customer_spends): Aggregate by customer_id to find total_orders
--    and total_spend.
-- 3. Main Query: Filter for customers with total_spend >= 500, sorted descending.
-- ----------------------------------------------------------------------------

WITH order_totals AS (
    SELECT
        o.order_id,
        o.employee_id,
        SUM(ol.quantity * ol.unit_price) AS order_subtotal
    FROM orders AS o
    INNER JOIN order_lines AS ol
        ON o.order_id = ol.order_id
    GROUP BY
        o.order_id,
        o.employee_id
),
customer_spends AS (
    SELECT
        employee_id,
        COUNT(order_id) AS total_orders,
        SUM(order_subtotal) AS total_spend
    FROM order_totals
    GROUP BY employee_id
)
SELECT
    employee_id,
    total_orders,
    total_spend
FROM customer_spends
WHERE total_spend >= 500
ORDER BY total_spend DESC;


-- ----------------------------------------------------------------------------
-- CHALLENGE 3: Department Salary Variance via Window Functions (Session 2)
-- Scenario: HR needs to identify individual compensation anomalies compared
-- to departmental averages without collapsing rows.
-- Task:
-- 1. Display employee_id, first_name, last_name, department, salary.
-- 2. Calculate dept_avg_salary using AVG(salary) OVER(PARTITION BY department).
-- 3. Calculate salary_variance as (salary - dept_avg_salary).
-- 4. Order by department, salary_variance DESC.
-- ----------------------------------------------------------------------------

WITH salary_comparison AS (
    SELECT
        employee_id,
        first_name,
        last_name,
        department,
        salary,
        AVG(salary) OVER (PARTITION BY department) AS dept_avg_salary
    FROM employees
)
SELECT
    employee_id,
    first_name,
    last_name,
    department,
    salary,
    dept_avg_salary,
    salary - dept_avg_salary AS salary_variance
FROM salary_comparison
ORDER BY
    department ASC,
    salary_variance DESC;


-- ----------------------------------------------------------------------------
-- CHALLENGE 4: Top-N Performer Filter with CTE (Session 2)
-- Scenario: Management wants to identify the top 2 highest-paid employees in
-- every department, handling ties gracefully without skipping ranks.
-- Task:
-- 1. Use DENSE_RANK() OVER(PARTITION BY department ORDER BY salary DESC).
-- 2. Wrap the window query in a CTE.
-- 3. In the outer query, filter for rank <= 2.
-- ----------------------------------------------------------------------------


WITH ranked_employees AS (
    SELECT
        employee_id,
        first_name,
        last_name,
        department,
        salary,
        DENSE_RANK() OVER (
            PARTITION BY department
            ORDER BY salary DESC
        ) AS dept_rank
    FROM employees
)
SELECT
    employee_id,
    first_name,
    last_name,
    department,
    salary,
    dept_rank
FROM ranked_employees
WHERE dept_rank <= 2
ORDER BY
    department ASC,
    dept_rank ASC,
    last_name ASC;

-- ----------------------------------------------------------------------------
-- CHALLENGE 5: The Golden Order Deduplication Pattern (Session 2)
-- Scenario: Find each customer's single most recent order.
-- Task:
-- 1. Use ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date DESC, order_id DESC).
-- 2. Wrap in a CTE named ranked_orders.
-- 3. Filter WHERE rn = 1.
-- ----------------------------------------------------------------------------

WITH ranked_orders AS (
    SELECT
        o.order_id,
        o.employee_id,
        o.order_date,
        o.status,
        ROW_NUMBER() OVER (
            ORDER BY o.order_date DESC, o.order_id DESC
        ) AS rn
    FROM orders AS o
    WHERE o.status = 'Completed'
)
SELECT
    ro.order_id,
    l.city AS sales_office_city,
    e.last_name AS rep_last_name,
    ol.quantity,
    ol.unit_price
FROM ranked_orders AS ro
INNER JOIN employees AS e
    ON ro.employee_id = e.employee_id
INNER JOIN locations AS l
    ON e.location_id = l.location_id
INNER JOIN order_lines AS ol
    ON ro.order_id = ol.order_id
WHERE ro.rn = 1
ORDER BY ro.order_id ASC;