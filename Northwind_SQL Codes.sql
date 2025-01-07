--DATA CLEANING and MANIPULATION

-- 1) Tables `customercustomerdemo`, `customerdemographics`, and `shippers_tmp` were excluded from the dataset as they do not support data interpretation.

--2) No changes were made to the tables `shippers`, `shippers_tmp`, `usstates`, `region`, `territories`, `categories`, `employeeterritories`, `products`, and `order_details`.

--3) In the `customers` table, null values in the `region` column were examined and filled based on `country` instead of all European countries:
-- Mexico was filled with 'MX', Argentina with 'AR', and UK with 'London' as all null values for the UK corresponded to the city of London.

--4) In the `employees` table, four null values in the `region` column were filled based on their respective `country`.

--5) In the `orders` table, null values in the `ship_region` column were examined and filled based on `ship_country` instead of all European countries:
-- Mexico was filled with 'MX', Argentina with 'AR', and UK with 'London' as all null values for the UK corresponded to the city of London.

UPDATE customers
SET region = CASE 
    WHEN country = 'Mexico' THEN 'MX'
    WHEN country = 'Argentina' THEN 'AR'
	WHEN country = 'UK' THEN 'London'
    ELSE 'EU'
END
WHERE region IS NULL;

UPDATE employees
SET region = 'London'
WHERE region is NULL ;

UPDATE orders
SET ship_region = CASE 
    WHEN ship_country = 'Mexico' THEN 'MX'
    WHEN ship_country = 'Argentina' THEN 'AR'
	WHEN ship_country = 'UK' THEN 'London'
    ELSE 'EU'
END
WHERE ship_region IS NULL;

--SALES ANALYSIS

--1) Total Sales Amount

SELECT SUM(unit_price * quantity) AS Total_Sales
FROM order_details;

--2) Total Number of Orders

SELECT COUNT(DISTINCT order_id) AS Order_Count
FROM orders;

--3) Total Products Sold

SELECT SUM(quantity) AS Total_Quantity_Sold
FROM order_details;

--4) Total Discounts

SELECT SUM(unit_price * quantity * discount) AS Total_Discount
FROM order_details

--5) Net Sales Amount

SELECT SUM(unit_price * quantity * (1 - discount))  AS Net_Sales
    FROM order_details

--6) Net Income Amount
	
SELECT
    SUM(od.unit_price * od.quantity * (1 - od.discount)) - SUM(o.freight) AS Net_Income
FROM
    order_details od
JOIN
    orders o ON od.order_id = o.order_id;

--7) Ratio of Discount to Total Sales

WITH TotalSales AS (
    SELECT SUM(unit_price * quantity) AS Total_Sales
	FROM order_details
),
TotalDiscount AS (
    SELECT SUM(unit_price * quantity * discount) AS Total_Discount
    FROM order_details
)

SELECT
    (TotalDiscount.Total_Discount / TotalSales.Total_Sales) AS Discount_Percentage
FROM
    TotalSales, TotalDiscount;

--8) Sales Distribution by Quarters and Months

SELECT
    EXTRACT(YEAR FROM o.order_date) AS Year,
    CASE
        WHEN EXTRACT(MONTH FROM o.order_date) IN (1, 2, 3) THEN 'Q1'  -- 1. Dönem: Ocak, Şubat, Mart
        WHEN EXTRACT(MONTH FROM o.order_date) IN (4, 5, 6) THEN 'Q2'  -- 2. Dönem: Nisan, Mayıs, Haziran
        WHEN EXTRACT(MONTH FROM o.order_date) IN (7, 8, 9) THEN 'Q3'  -- 3. Dönem: Temmuz, Ağustos, Eylül
        ELSE 'Q4'  -- 4. Dönem: Ekim, Kasım, Aralık
    END AS Quarter,
	EXTRACT(MONTH FROM o.order_date) AS Month,
    SUM(unit_price * quantity * (1 - discount))  AS Net_Sales
FROM
    orders o
JOIN
    order_details od ON o.order_id = od.order_id
GROUP BY
    1,2,3
ORDER BY
    1,2,3;

--9) Quarterly Growth Rate Based on Net Sales

WITH QuarterlySales AS (
    SELECT
        EXTRACT(YEAR FROM o.order_date) AS Year,
        CASE
            WHEN EXTRACT(MONTH FROM o.order_date) IN (1, 2, 3) THEN 'Q1'
            WHEN EXTRACT(MONTH FROM o.order_date) IN (4, 5, 6) THEN 'Q2'
            WHEN EXTRACT(MONTH FROM o.order_date) IN (7, 8, 9) THEN 'Q3'
            ELSE 'Q4'
        END AS Quarter,
        SUM(unit_price * quantity * (1 - discount)) AS Net_Sales
    FROM
        orders o
    JOIN
        order_details od ON o.order_id = od.order_id
    GROUP BY
	1,2
),

QuarterlyGrowth AS (
    SELECT
        Year,
        Quarter,
        Net_Sales,
        LAG(Net_Sales) OVER (PARTITION BY Year ORDER BY Quarter) AS Previous_Quarter_Sales
    FROM
        QuarterlySales
)

SELECT
    Year,
    Quarter,
    Net_Sales,
    Previous_Quarter_Sales,
    CASE
        WHEN Previous_Quarter_Sales IS NULL OR Previous_Quarter_Sales = 0 THEN NULL
        ELSE ((Net_Sales - Previous_Quarter_Sales) / Previous_Quarter_Sales) * 100
    END AS QuarterlyGrowthPercentage
FROM
    QuarterlyGrowth
ORDER BY
    1, 2;

--10) Top 5 Best-Selling Products and Their Order Counts

SELECT
    p.product_name AS Product,
    c.category_name AS Category,
    COUNT(od.order_id) AS Total_Orders,
    SUM(unit_price * quantity * (1 - discount)) AS Net_Sales
FROM
    order_details od
JOIN
    products p ON od.product_id = p.product_id
JOIN
    categories c ON p.category_id = c.category_id
GROUP BY
    1,2
ORDER BY
    Net_Sales DESC
LIMIT 5

--11) Top 5 Customers Based on Sales and Their Total Orders
	
SELECT
    p.product_name AS Product,
    c.category_name AS Category,
    COUNT(od.order_id) AS Total_Orders,
    SUM(od.unit_price * od.quantity * (1 - od.discount)) AS Net_Sales
FROM
    order_details od
JOIN
    products p ON od.product_id = p.product_id
JOIN
    categories c ON p.category_id = c.category_id
GROUP BY
    1, 2
ORDER BY
    4 DESC
LIMIT 5;

--12) Country Ranking by Net Sales and Total Orders
	
SELECT
    c.country AS Country,
    COUNT(DISTINCT o.order_id) AS Total_Orders,
    SUM(unit_price * quantity * (1 - discount)) AS Net_Sales
FROM
    orders o
JOIN
    customers c ON o.customer_id = c.customer_id
JOIN
    order_details od ON o.order_id = od.order_id
GROUP BY
    1
ORDER BY
    3 DESC;
	
--13) Employee Ranking by Sales Performance

	SELECT
    e.country AS Office_Country,
    e.employee_id AS EmployeeID,
    e.first_name || ' ' || e.last_name AS Employee_Name,
	e.title AS Employee_Title,
    e.city AS Office_City,
    SUM(unit_price * quantity * (1 - discount)) AS Net_Sales
FROM
    orders o
JOIN
    employees e ON o.employee_id = e.employee_id
JOIN
    order_details od ON o.order_id = od.order_id
GROUP BY
    1,2,3,4,5
ORDER BY
    6 DESC;

--PRODUCT ANALYSIS

--1) Total Number of Products

SELECT SUM(quantity) AS Total_Quantity
FROM order_details;

--2) Product Counts by Category

SELECT
    ca.category_name,
    SUM(od.quantity) AS Total_Quantity,
	SUM(od.unit_price * od.quantity * (1 - discount)) AS Net_Sales
FROM
    order_details od
JOIN
    products p ON od.product_id = p.product_id
JOIN
    categories ca ON p.category_id = ca.category_id
GROUP BY
    1
ORDER BY
    2 DESC;
	
--3) Average Product Price

SELECT
    AVG(unit_price) AS Average_Price
FROM
    products;

--4) Ranking of the Most and Least Expensive Products

SELECT
    p.product_name AS Product,
    p.unit_price AS Price,
    c.category_name AS Category
FROM
    products p
JOIN
    categories c ON p.category_id = c.category_id
ORDER BY
    2 DESC;

--5) Top 5 Most Expensive and Least Expensive Products - Their Share of Total Sales
	
WITH ExpensiveProduct AS (
    SELECT
        p.product_name,
        ca.category_name,
        p.unit_price,
        SUM(od.unit_price * od.quantity * (1 - discount)) AS Per_Product_Net_Sales
    FROM
        order_details od
    JOIN
        products p ON od.product_id = p.product_id
    JOIN
        categories ca ON p.category_id = ca.category_id
    GROUP BY
        1,2,3
    ORDER BY
        3 DESC
    LIMIT 5
),

CheapProduct AS (
    SELECT
        p.product_name,
        ca.category_name,
        p.unit_price,
        SUM(od.unit_price * od.quantity * (1 - discount)) AS Per_Product_Net_Sales
    FROM
        order_details od
    JOIN
        products p ON od.product_id = p.product_id
    JOIN
        categories ca ON p.category_id = ca.category_id
    GROUP BY
        1,2,3
    ORDER BY
        3 ASC
    LIMIT 5
),

Net_Sales AS (
    SELECT
       SUM(od.unit_price * od.quantity * (1 - discount)) AS Net_Sales
    FROM
        order_details od
)

SELECT
    e.product_name,
    e.category_name,
    e.unit_price,
    e.Per_Product_Net_Sales,
    (e.Per_Product_Net_Sales / ti.Net_Sales) * 100 AS Share_Total_Sales
FROM
    (SELECT * FROM ExpensiveProduct
     UNION ALL
     SELECT * FROM CheapProduct) AS e
CROSS JOIN
    Net_Sales ti
ORDER BY
    3 DESC;

--6) Top 5 Most Ordered Products

SELECT
    p.product_name,
    ca.category_name,
    SUM(od.quantity) AS Total_Quantity,
	SUM(od.unit_price * od.quantity * (1 - discount)) AS Net_Sales
FROM
    order_details od
JOIN
    products p ON od.product_id = p.product_id
JOIN
    categories ca ON p.category_id = ca.category_id
GROUP BY
    1,2
ORDER BY
    3 DESC
LIMIT 5;

	
--7) Product and Discount Distribution - NO PRODUCTS WITHOUT A DISCOUNT
	
WITH ProductDiscounts AS (
    SELECT
        p.product_id,
        p.product_name,
        COUNT(od.discount) AS Discount_Count
    FROM
        products p
    LEFT JOIN
        order_details od ON p.product_id = od.product_id AND od.discount > 0
    GROUP BY
        1,2
)

SELECT
    SUM(CASE WHEN pd.Discount_Count > 0 THEN 1 ELSE 0 END) AS Products_With_Discount,
    SUM(CASE WHEN pd.Discount_Count = 0 THEN 1 ELSE 0 END) AS Products_Without_Discount
FROM
    ProductDiscounts pd;

--8) Top 5 Most Discounted Products

SELECT
    p.product_name,
    ca.category_name,
    SUM(od.discount * od.quantity * od.unit_price) AS Total_Discount
FROM
    order_details od
JOIN
    products p ON od.product_id = p.product_id
JOIN
    categories ca ON p.category_id = ca.category_id
GROUP BY
    1,2
ORDER BY
    3 DESC
LIMIT 5;

--9) Top 5 Most Discounted Products and Their Share of Total Sales

SELECT
    p.product_name,
	ca.category_name,
    SUM(od.discount * od.quantity * od.unit_price) AS Total_Discount,
	SUM(od.quantity * p.unit_price) AS Per_Product_Total_Sales,
    (SUM(od.discount * od.quantity * od.unit_price) / SUM(od.quantity * od.unit_price)) * 100 AS Discount_Percentage_TotalSales
FROM
    order_details od
JOIN
    products p ON od.product_id = p.product_id
JOIN
    categories ca ON p.category_id = ca.category_id
WHERE
    od.discount > 0
GROUP BY
    1,2
ORDER BY
    3 DESC
LIMIT 5;

--10) Best-Selling Product Categories by Month

WITH MonthlyCategorySales AS (
    SELECT
        EXTRACT(YEAR FROM o.order_date) AS Year,
        EXTRACT(MONTH FROM o.order_date) AS Month,
        c.category_name,
        SUM(od.quantity) AS Total_Quantity_Sold
    FROM
        order_details od
    JOIN
        products p ON od.product_id = p.product_id
    JOIN
        categories c ON p.category_id = c.category_id
    JOIN
        orders o ON od.order_id = o.order_id
    GROUP BY
        1,2,3
)
SELECT
    Year,
    Month,
    category_name,
    Total_Quantity_Sold
FROM
    MonthlyCategorySales
WHERE
    (Year, Month, Total_Quantity_Sold) IN (
        SELECT
            Year,
            Month,
            MAX(Total_Quantity_Sold)
        FROM
            MonthlyCategorySales
        GROUP BY
            1,2
    )
ORDER BY
    1,2;

--11) Top 5 Customers and Their Most Preferred Products

WITH Top5Customers AS (
    SELECT
        c.customer_id,
        c.company_name,
        SUM(unit_price * quantity * (1 - discount)) AS Net_Sales
    FROM
        customers c
    JOIN
        orders o ON c.customer_id = o.customer_id
    JOIN
        order_details od ON o.order_id = od.order_id
    GROUP BY
        1, 2
    ORDER BY
        3 DESC
    LIMIT 5
),
CustomerProductPreferences AS (
    SELECT
        c.customer_id,
        c.company_name,
        p.product_id,
        p.product_name,
        cat.category_name,
        SUM(od.quantity) AS Total_Quantity,
        ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY SUM(od.quantity) DESC) AS rn
    FROM
        Top5Customers c
    JOIN
        orders o ON c.customer_id = o.customer_id
    JOIN
        order_details od ON o.order_id = od.order_id
    JOIN
        products p ON od.product_id = p.product_id
    JOIN
        categories cat ON p.category_id = cat.category_id
    GROUP BY
        1,2,3,4,5
)
SELECT
    customer_id,
    company_name,
    product_name,
    category_name,
    Total_Quantity
FROM
    CustomerProductPreferences
WHERE
    rn = 1
ORDER BY
    Total_Quantity DESC;

--12) Top 5 Suppliers and Their Best-Selling Products

WITH TopSuppliers AS (
    SELECT 
        p.supplier_id,
        s.company_name,
        SUM(od.quantity) AS TotalQuantity
    FROM 
        products p
    JOIN 
        order_details od ON p.product_id = od.product_id
    JOIN 
        suppliers s ON p.supplier_id = s.supplier_id
    GROUP BY 
        p.supplier_id, s.company_name
    ORDER BY 
        TotalQuantity DESC
    LIMIT 5
),
TopProducts AS (
    SELECT 
        p.supplier_id,
        p.product_name,
        c.category_name,  
        SUM(od.quantity) AS TotalSoldQuantity
    FROM 
        products p
    JOIN 
        order_details od ON p.product_id = od.product_id
    JOIN 
        categories c ON p.category_id = c.category_id  
    GROUP BY 
        p.supplier_id, p.product_name, c.category_name  
)
SELECT 
    ts.company_name AS Supplier,
    tp.product_name AS Product,
    tp.category_name AS Category, 
    tp.TotalSoldQuantity AS TotalSold
FROM 
    TopSuppliers ts
JOIN 
    TopProducts tp ON ts.supplier_id = tp.supplier_id
ORDER BY 
    ts.TotalQuantity DESC, 
    tp.TotalSoldQuantity DESC;

--LOGISTICS ANALYSIS

--1) Total Freight Cost

SELECT 
    SUM(freight) AS Total_Freight_Cost
FROM 
    orders;
	
--2) Average Freight Cost

SELECT AVG(freight) AS Average_Freight
FROM orders;
	
--3) Number of On-Time Deliveries

SELECT COUNT(*) AS On_Time_Delivery_Count
FROM orders
WHERE shipped_date <= required_date;


--4) Number of Late Deliveries

SELECT COUNT(*) AS Late_Delivery_Count
FROM orders
WHERE shipped_date > required_date;

--5) Number of Undelivered Orders

SELECT COUNT(*) AS Not_Delivered_Count
FROM orders
WHERE shipped_date IS NULL;

--6) Delivery Status Distribution of Orders

SELECT 
	COUNT(order_id) as Total_Order_Number,
    SUM(CASE WHEN shipped_date <= required_date THEN 1 ELSE 0 END) AS On_Time_Delivery_Count,
    SUM(CASE WHEN shipped_date > required_date THEN 1 ELSE 0 END) AS Late_Delivery_Count,
    SUM(CASE WHEN shipped_date IS NULL THEN 1 ELSE 0 END) AS Not_Delivered_Count
FROM orders;

--7) Average Delivery Time

SELECT 
    AVG(shipped_date - order_date) AS Average_Delivery_Time
FROM 
    orders
WHERE 
    shipped_date IS NOT NULL;
	
--8) Monthly Order Counts by Shipping Companies

SELECT
    EXTRACT(YEAR FROM o.order_date) AS Year,
    EXTRACT(MONTH FROM o.order_date) AS Month,
    s.company_name AS Shipping_Company,
    COUNT(o.order_id) AS Order_Count
FROM
    orders o
JOIN
    shippers s ON o.ship_via = s.shipper_id
GROUP BY
    1,2,3
ORDER BY
    1,2,3;
	
--9) Order Counts by Shipping Company

SELECT
    s.company_name AS Shipping_Company,
    COUNT(o.order_id) AS Order_Count,
	SUM(od.unit_price * od.quantity * (1 - discount))  AS Net_Sales
FROM
    orders o
JOIN
    shippers s ON o.ship_via = s.shipper_id
JOIN order_details od ON od.order_id = o.order_id
GROUP BY
    1
ORDER BY
    2 DESC;
	
--10) Average Delivery Time by Shipping Company

SELECT
    s.company_name AS Shipping_Company,
    AVG(shipped_date - order_date) AS Average_Delivery_Days
FROM
    orders o
JOIN
    shippers s ON o.ship_via = s.shipper_id
WHERE
    o.shipped_date IS NOT NULL
GROUP BY
    1
ORDER BY
    2;

--11) Products in Stock by Category
	
SELECT
	c.category_id,
    c.category_name AS Category,
    SUM(p.unit_in_stock) AS Total_Units_In_Stock
FROM
    products p
JOIN
    categories c ON p.category_id = c.category_id
WHERE
    p.unit_in_stock > 0
GROUP BY
    1,2
ORDER BY
    3 DESC;
	
--12) Supplier and Product Diversity Analysis

WITH SupplierCategoryCounts AS (
    SELECT
        s.supplier_id,
        s.company_name,
        c.category_id,
        c.category_name,
        COUNT(p.product_id) AS Product_Count
    FROM
        suppliers s
    JOIN
        products p ON s.supplier_id = p.supplier_id
    JOIN
        categories c ON p.category_id = c.category_id
    GROUP BY
        1,2,3,4
),
TotalCategoryCounts AS (
    SELECT
        supplier_id,
        company_name,
        COUNT(DISTINCT category_id) AS Category_Count
    FROM
        SupplierCategoryCounts
    GROUP BY
        1,2
),
TotalProductQuantities AS (
    SELECT
        p.supplier_id,
        SUM(od.quantity) AS Total_Quantity
    FROM
        order_details od
    JOIN
        products p ON od.product_id = p.product_id
    GROUP BY
        1
)

SELECT
    sp.supplier_id,
    sp.company_name,
    COALESCE(cc.Category_Count, 0) AS Category_Count,
    COALESCE(tp.Total_Quantity, 0) AS Total_Quantity
FROM
    TotalCategoryCounts cc
LEFT JOIN
    SupplierCategoryCounts sp ON cc.supplier_id = sp.supplier_id
LEFT JOIN
    TotalProductQuantities tp ON cc.supplier_id = tp.supplier_id
WHERE
    cc.Category_Count >= 3
GROUP BY
    1,2,3,4
ORDER BY
    3 DESC;

	
--13) Top 5 Suppliers by Product Count

SELECT
    s.supplier_id,
    s.company_name,
	s.city,
    SUM(od.quantity) AS Total_Quantity_Supplied
FROM
    suppliers s
JOIN
    products p ON s.supplier_id = p.supplier_id
JOIN
    order_details od ON p.product_id = od.product_id
GROUP BY
    1,2
ORDER BY
    4 DESC
LIMIT 5;

--14) Average Delays and Number of Delayed Deliveries by Shipping Companies

SELECT
    s.company_name AS Shipping_Company,
	AVG(o.shipped_date - o.required_date) AS Average_Delay_Days,
    COUNT(CASE WHEN o.shipped_date > o.required_date THEN 1 ELSE NULL END) AS Delayed_Orders
FROM
    orders o
JOIN
    shippers s ON o.ship_via = s.shipper_id
WHERE
    o.shipped_date > o.required_date 
GROUP BY
    1
ORDER BY
    2 DESC;

--15) Freight Costs by Shipping Company

SELECT
    s.company_name AS Shipping_Company,
    SUM(o.freight) AS Total_Freight_Cost
FROM
    orders o
JOIN
    shippers s ON o.ship_via = s.shipper_id
GROUP BY
    1
ORDER BY
    2 DESC;

--16) Top Products Transported by Shipping Companies

WITH CategoryShipmentCounts AS (
    SELECT
        sh.company_name AS Shipper,
        c.category_name AS Category,
        SUM(od.quantity) AS Total_Quantity
    FROM
        orders o
    JOIN
        order_details od ON o.order_id = od.order_id
    JOIN
        products p ON od.product_id = p.product_id
    JOIN
        categories c ON p.category_id = c.category_id
    JOIN
        shippers sh ON o.ship_via = sh.shipper_id
    GROUP BY
        1,2
),
MaxCategoryShipment AS (
    SELECT
        Shipper,
        MAX(Total_Quantity) AS Max_Quantity
    FROM
        CategoryShipmentCounts
    GROUP BY
        1
)
SELECT
    csc.Shipper,
    csc.Category,
    csc.Total_Quantity
FROM
    CategoryShipmentCounts csc
JOIN
    MaxCategoryShipment mcs ON csc.Shipper = mcs.Shipper AND csc.Total_Quantity = mcs.Max_Quantity
ORDER BY
    1,3 DESC;

--17) Product Stock Status

SELECT
  p.product_id,
  p.product_name,
  unit_in_stock,
  CASE
    WHEN unit_in_stock > 100 THEN 'high'
    WHEN unit_in_stock > 50 THEN 'moderate'
    WHEN unit_in_stock > 0 THEN 'low'
    WHEN unit_in_stock = 0 THEN 'none'
 END AS availability
	
FROM
    products p
ORDER BY 3 DESC;

--CUSTOMER ANALYSIS

--1) Total Number of Customers

SELECT COUNT(DISTINCT customer_id) AS Customer_Count
FROM customers;

--2) Top 5 Customers by Sales and Their Annual Order-Sales Distribution

WITH Top5Customers AS (
    SELECT
        c.customer_id,
        c.company_name,
        SUM(unit_price * quantity * (1 - discount)) AS Net_Sales
    FROM
        customers c
    JOIN
        orders o ON c.customer_id = o.customer_id
    JOIN
        order_details od ON o.order_id = od.order_id
    GROUP BY
        1, 2
    ORDER BY
        3 DESC
    LIMIT 5
)
SELECT
    EXTRACT(YEAR FROM o.order_date) AS year,
    c.company_name AS Customer_Name,
    COUNT(o.order_id) AS Order_Count,
    SUM(unit_price * quantity * (1 - discount)) AS Net_Sales
FROM
    orders o
JOIN
    customers c ON o.customer_id = c.customer_id
JOIN
    order_details od ON o.order_id = od.order_id
JOIN
    Top5Customers t5c ON c.customer_id = t5c.customer_id
GROUP BY
    1, 2
ORDER BY
    1, 4 DESC;

--3) Country Distribution of Customers and Their Share of Total Sales

WITH NetSales AS (
    SELECT
        SUM(unit_price * quantity * (1 - discount)) AS Grand_Net_Sales
    FROM
        order_details od
)

SELECT
    c.country AS Country,
    COUNT(DISTINCT c.customer_id) AS Customer_Count,
    SUM(unit_price * quantity * (1 - discount)) AS Net_Sales,
    (SUM(od.unit_price * od.quantity) / ts.Grand_Net_Sales) * 100 AS Sales_Percentage
FROM
    customers c
JOIN
    orders o ON c.customer_id = o.customer_id
JOIN
    order_details od ON o.order_id = od.order_id
CROSS JOIN
    NetSales ts
GROUP BY
    1, ts.Grand_Net_Sales
ORDER BY
    3 DESC;
	
--4) Top 5 Customers and Their Most Preferred Products

WITH Top5Customers AS (
    SELECT
        c.customer_id,
        c.company_name,
        SUM(unit_price * quantity * (1 - discount)) AS Net_Sales
    FROM
        customers c
    JOIN
        orders o ON c.customer_id = o.customer_id
    JOIN
        order_details od ON o.order_id = od.order_id
    GROUP BY
        1, 2
    ORDER BY
        3 DESC
    LIMIT 5
),
CustomerProductPreferences AS (
    SELECT
        c.customer_id,
        c.company_name,
        p.product_id,
        p.product_name,
        cat.category_name,
        SUM(od.quantity) AS Total_Quantity,
        ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY SUM(od.quantity) DESC) AS rn
    FROM
        Top5Customers c
    JOIN
        orders o ON c.customer_id = o.customer_id
    JOIN
        order_details od ON o.order_id = od.order_id
    JOIN
        products p ON od.product_id = p.product_id
    JOIN
        categories cat ON p.category_id = cat.category_id
    GROUP BY
        1,2,3,4,5
)
SELECT
    customer_id,
    company_name,
    product_name,
    category_name,
    Total_Quantity
FROM
    CustomerProductPreferences
WHERE
    rn = 1
ORDER BY
    Total_Quantity DESC;

--5) Fastest and Slowest Delivery Times for Customers

WITH DeliveryTimes AS (
    SELECT
        c.customer_id AS Customer_ID,
        c.company_name AS Customer_Name,
		c.country AS Country,
        AVG(o.shipped_date - o.order_date) AS Average_Delivery_Time
    FROM
        orders o
    JOIN
        customers c ON o.customer_id = c.customer_id
    WHERE
        o.shipped_date IS NOT NULL
    GROUP BY
        1, 2, 3
)

(SELECT 
    Customer_ID,
    Customer_Name,
 	Country,
    Average_Delivery_Time
FROM 
    DeliveryTimes
ORDER BY 
    Average_Delivery_Time ASC
LIMIT 5)
UNION ALL


(SELECT 
    Customer_ID,
    Customer_Name,
 	Country,
    Average_Delivery_Time
FROM 
    DeliveryTimes
ORDER BY 
    Average_Delivery_Time DESC
LIMIT 5);
