create database ecommerce_dw;

use ecommerce_dw;

CREATE TABLE dim_date (
    DateKey INT PRIMARY KEY,
    FullDate DATE,
    Year INT,
    Month INT,
    MonthName VARCHAR(20),
    Quarter INT
);


CREATE TABLE dim_customers (
    CustomerID INT PRIMARY KEY,
    Total_Revenue DECIMAL(12,2),
    Total_Orders INT,
    Recency_Days INT,
    RFM_Score INT,
    Segment VARCHAR(50)
);


CREATE TABLE fact_invoices (
    InvoiceNo INT,
    CustomerID INT,
    DateKey INT,
    Country VARCHAR(100),
    Revenue DECIMAL(12,2),

    FOREIGN KEY (CustomerID) REFERENCES dim_customers(CustomerID),
    FOREIGN KEY (DateKey) REFERENCES dim_date(DateKey)
);


-- 1 — Basic Revenue Validation
select sum(Revenue) as Total_revenue from fact_invoices;


-- 2 — Revenue by Segment (JOIN Query)
select c.segment, sum(f.revenue) as Total_revenue from fact_invoices f join dim_customers c
on f.CustomerID = c.CustomerID
group by c.segment
order by Total_Revenue DESC;


-- 3 — Monthly Revenue Trend
select d.year, d.month, sum(f.revenue) as Monthly_revenue from fact_invoices f join dim_date d
on f.DateKey = d.DateKey
group by d.Year, d.Month
order by d.year, d.Month;


-- 4 — Test Order Volume by Month
select d.year, d.month, count(InvoiceNo) as Total_orders from fact_invoices f join dim_date d 
on d.DateKey = f.DateKey
group by d.year, d.Month
order by d.year, d.month;


-- 5 — Test AOV by Month
select d.year, d.month, SUM(f.Revenue) / COUNT(f.InvoiceNo) AS AOV from fact_invoices f join dim_date d
on d.DateKey = f.DateKey
group by d.year, d.month
order by d.year, d.Month;


-- 6 — Check Which Segment Dropped in February
SELECT d.Month,c.Segment, SUM(f.Revenue) AS Revenue FROM fact_invoices f JOIN dim_date d  
ON f.DateKey = d.DateKey JOIN dim_customers c 
ON f.CustomerID = c.CustomerID 
WHERE d.Year = 2011 AND d.Month IN (1,2)
GROUP BY d.Month, c.Segment
ORDER BY d.Month, Revenue DESC;



-- 7 - Top 10 Customers by Revenue (Using RANK)
select customerID, sum(Revenue) as Total_revenue, rank() over(order by sum(Revenue) desc) as Revenue_rank from fact_invoices 
group by CustomerID
limit 10;


-- 8 - Running Monthly Revenue (Window Function)
SELECT  d.Year, d.Month, SUM(f.Revenue) AS Monthly_Revenue, SUM(SUM(f.Revenue)) OVER (ORDER BY d.Year, d.Month) AS Running_Total FROM fact_invoices f JOIN dim_date d  
ON f.DateKey = d.DateKey 
GROUP BY d.Year, d.Month
ORDER BY d.Year, d.Month;



-- 🧠 What Is a Cohort?
-- A cohort = group of customers who made their first purchase in the same month.

-- 1 — Find First Purchase Month Per Customer
select customerID, min(Datekey) as First_Frequency_Datekey from fact_invoices
group by CustomerID;

select f.customerID, min(d.year) as cohort_year, min(d.month) as cohort_month from fact_invoices f join dim_date d 
on f.DateKey = d.DateKey 
group by f.CustomerID;




-- 2 — Calculate Activity Month for Each Purchase

-- Now we need:
-- For every transaction:
-- What was the customer’s cohort month?
-- What month is this purchase?
-- How many months since first purchase?


SELECT 
    f.CustomerID,
    c.cohort_year,
    c.cohort_month,
    d.Year AS Order_Year,
    d.Month AS Order_Month,
    ((d.Year - c.cohort_year) * 12 + (d.Month - c.cohort_month)) AS Month_Index
FROM fact_invoices f
JOIN (
    SELECT 
        f.CustomerID,
        MIN(d.Year) AS cohort_year,
        MIN(d.Month) AS cohort_month
    FROM fact_invoices f
    JOIN dim_date d 
        ON f.DateKey = d.DateKey
    GROUP BY f.CustomerID
) c
    ON f.CustomerID = c.CustomerID
JOIN dim_date d 
    ON f.DateKey = d.DateKey;



-- 3 — Build Cohort Retention Table
-- What we need:
-- For each:
-- Cohort (Year + Month)
-- Month_Index (0,1,2,3…)
-- Count of distinct customers
-- That shows how many customers came back in each month.

SELECT 
    c.cohort_year,
    c.cohort_month,
    ((d.Year - c.cohort_year) * 12 + (d.Month - c.cohort_month)) AS Month_Index,
    COUNT(DISTINCT f.CustomerID) AS Active_Customers
FROM fact_invoices f

JOIN (
    SELECT 
        f.CustomerID,
        MIN(d.Year) AS cohort_year,
        MIN(d.Month) AS cohort_month
    FROM fact_invoices f
    JOIN dim_date d 
        ON f.DateKey = d.DateKey
    GROUP BY f.CustomerID
) c
    ON f.CustomerID = c.CustomerID

JOIN dim_date d 
    ON f.DateKey = d.DateKey

GROUP BY 
    c.cohort_year,
    c.cohort_month,
    Month_Index

ORDER BY 
    c.cohort_year,
    c.cohort_month,
    Month_Index;


-- 4 — Convert to Retention %

-- Logic:
-- Retention % =
-- Active_Customers in Month_Index / Active_Customers in Month_Index 0
-- Month_Index 0 = original cohort size.

WITH cohort_table AS (
    SELECT 
        c.cohort_year,
        c.cohort_month,
        ((d.Year - c.cohort_year) * 12 + (d.Month - c.cohort_month)) AS Month_Index,
        COUNT(DISTINCT f.CustomerID) AS Active_Customers
    FROM fact_invoices f
    JOIN (
        SELECT 
            f.CustomerID,
            MIN(d.Year) AS cohort_year,
            MIN(d.Month) AS cohort_month
        FROM fact_invoices f
        JOIN dim_date d 
            ON f.DateKey = d.DateKey
        GROUP BY f.CustomerID
    ) c
        ON f.CustomerID = c.CustomerID
    JOIN dim_date d 
        ON f.DateKey = d.DateKey
    GROUP BY 
        c.cohort_year,
        c.cohort_month,
        Month_Index
)

SELECT 
    cohort_year,
    cohort_month,
    Month_Index,
    Active_Customers,
    ROUND(
        Active_Customers / 
        FIRST_VALUE(Active_Customers) OVER (
            PARTITION BY cohort_year, cohort_month
            ORDER BY Month_Index
        ), 2
    ) AS Retention_Rate
FROM cohort_table
ORDER BY cohort_year, cohort_month, Month_Index;


commit;

SHOW DATABASES;



