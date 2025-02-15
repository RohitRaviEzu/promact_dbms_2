CREATE TABLE Customers(
   CustomerID INT PRIMARY KEY,    
   Name VARCHAR(55),
   Email VARCHAR(50),
   RegistrationDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Products (
  ProductID INT PRIMARY KEY,      
  Name VARCHAR(50),
  Category VARCHAR(100),
  Price DECIMAL(10,2),
  Qty INT
);

CREATE TABLE Orders (
  OrderID INT PRIMARY KEY,         
  CustomerID INT,
  Order_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  Tot_Amt DECIMAL(10,2),
  FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE CASCADE         
);

CREATE TABLE OrderDetails (
  OrderDetail_ID INT PRIMARY KEY,      
  OrderID INT,
  ProductID INT,
  Qty INT,
  Tot_Amt DECIMAL(10,2),
  FOREIGN KEY (OrderID) REFERENCES Orders(OrderID) ON DELETE CASCADE,          
  FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE CASCADE     
);

INSERT INTO Customers (CustomerID, Name, Email)
VALUES
(1, 'John Doe', 'johndoe@email.com'),
(2, 'Jane Smith', 'janesmith@email.com'),
(3, 'Alice Johnson', 'alice.johnson@email.com'),
(4, 'Bob Williams', 'bob.williams@email.com'),
(5, 'Charlie Brown', 'charlie.brown@email.com');

SELECT * FROM Customers ;

INSERT INTO Products (ProductID, Name, Category, Price, Qty)
VALUES
(101, 'Laptop', 'Electronics', 1200.00, 50),
(102, 'Smartphone', 'Electronics', 800.00, 100),
(103, 'Headphones', 'Electronics', 150.00, 200),
(104, 'Coffee Maker', 'Home Appliances', 60.00, 150),
(105, 'Blender', 'Home Appliances', 120.00, 80);

SELECT * FROM Products ;

INSERT INTO Orders (OrderID, CustomerID, Tot_Amt)
VALUES
(1, 1, 2400.00),
(2, 2,  950.00),
(3, 3,  180.00),
(4, 4,  120.00),
(5, 5,  240.00);

SELECT * FROM  Orders ;

INSERT INTO OrderDetails (OrderDetail_ID, OrderID, ProductID, Qty, Tot_Amt)
VALUES
(1, 1, 101, 1, 1200.00), 
(2, 1, 102, 1, 800.00),
(3, 2, 103, 2, 300.00),
(4, 3, 104, 1, 60.00),
(5, 5, 105, 2, 240.00);

SELECT * FROM OrderDetails ;

-- Task 1: Advanced SQL Queries (3 Points)

-- Part 1  : Retrieve the top 3 customers with the highest total purchase amount

SELECT Name, (SELECT SUM(Tot_Amt) -- Outputing the asked columns
FROM Orders                    -- Work with the orders table 
WHERE CustomerID = Orders.CustomerID) AS TotalPurchase       -- On this condition
FROM Orders  
JOIN Customers ON Orders.CustomerID = Customers.CustomerID     -- matches each order in the Orders table with the corresponding customer in the Customers table on same CustomerID 
GROUP BY Orders.CustomerID, Customers.Name     -- Grouping CustomerID & Name
ORDER BY TotalPurchase DESC           -- Sorting in desceding for TotalPurchase  column
LIMIT 3;                 --limits the result to the first 3 rows.


-- Part 2 : Show monthly sales revenue for the last 6 months using PIVOT.

SELECT 
    TO_CHAR(Order_Date, 'YYYY-MM') AS Month,        -- extracts the year and month from the Order_Date column and aliased as Month.
    SUM(CASE WHEN EXTRACT(MONTH FROM Order_Date) = 1 THEN Tot_Amt ELSE 0 END) AS January,   -- checks if the month extracted from Order_Date is January, if so tot_amt is added else 0
    SUM(CASE WHEN EXTRACT(MONTH FROM Order_Date) = 2 THEN Tot_Amt ELSE 0 END) AS February,  -- same as above 
    SUM(CASE WHEN EXTRACT(MONTH FROM Order_Date) = 3 THEN Tot_Amt ELSE 0 END) AS March,     -- same as above
    SUM(CASE WHEN EXTRACT(MONTH FROM Order_Date) = 4 THEN Tot_Amt ELSE 0 END) AS April,     -- same as above
    SUM(CASE WHEN EXTRACT(MONTH FROM Order_Date) = 5 THEN Tot_Amt ELSE 0 END) AS May,       -- same as above
    SUM(CASE WHEN EXTRACT(MONTH FROM Order_Date) = 6 THEN Tot_Amt ELSE 0 END) AS June       -- same as above
FROM Orders
WHERE Order_Date >= CURRENT_DATE - INTERVAL '6 months'      -- Here we filter the rows to include only the orders placed in the last 6 months from the current date.
GROUP BY TO_CHAR(Order_Date, 'YYYY-MM')     -- This sorts the result by Month in descending order
ORDER BY Month DESC;


-- Part 3 : Find the second most expensive product in each category using window functions

SELECT RankedProducts.Category,        -- Outer query 
       RankedProducts.Name, 		 -- Selecting these columns
       RankedProducts.Price
FROM (
    SELECT p.Category,      -- Inner query 
           p.Name, 
           p.Price,
           RANK() OVER (PARTITION BY p.Category ORDER BY p.Price DESC) AS PriceRank   -- Assigning a rank to each products that are grouped by Category based on its price.
    FROM Products p
) AS RankedProducts
WHERE RankedProducts.PriceRank = 2;       -- filters the results to only include the 2nd row. 

-- TASK 2 : Stored Procedures and Functions

-- Part 1 : Create a stored procedure to place an order, which:
--           Deducts stock from the Products table.
--           Inserts data into the Orders and OrderDetails tables.
--           Returns the new OrderId.

SELECT * FROM Products; 
SELECT * FROM Orders;
SELECT * FROM OrderDetails;


CREATE OR REPLACE FUNCTION f1_name (
    p_customer_id INT,
    p_product_details JSONB -- JSON array of products with their quantities and prices for multiple products in a order
)
RETURNS INT -- Return the latest OrderID
LANGUAGE plpgsql
AS $$
DECLARE
    new_order_id INT;
    new_order_detail_id INT;
    total_amount DECIMAL(10,2) := 0;
    var_prod_id INT;
    var_qty INT;
    var_prod_price DECIMAL(10,2);
    var_cnt INT;
    product JSONB;
BEGIN
    -- Get the maximum OrderID and increment by 1 for the new order
    SELECT MAX(OrderID)
    INTO new_order_id
    FROM Orders;

    -- Insert the new order into Orders table first to get the new OrderID
    INSERT INTO Orders (OrderID, CustomerID, Tot_Amt)
    VALUES (new_order_id + 1, p_customer_id, 0); -- Tot_Amt will be calculated later

    -- Loop through each product in the JSON array
    FOR product IN
        SELECT * FROM jsonb_array_elements(p_product_details) AS products
    LOOP
        -- Extract product_id and quantity from the JSON object
        var_prod_id := (product->>'product_id')::INT;
        var_qty := (product->>'qty')::INT;

        -- Check if the product has enough stock
        SELECT COUNT(*)
        INTO var_cnt            -- Store the product qty in var_cnt
        FROM Products
        WHERE productid = var_prod_id        -- Should be equal to var_prod_id
        AND qty >= var_qty;            	 -- And qty should be greater than var_qty

        -- If not enough stock, raise an exception
        IF var_cnt = 0 THEN
            RAISE EXCEPTION 'Not enough stock for ProductID: % (Requested: %, Available: %)', 
                var_prod_id, var_qty, (SELECT qty FROM Products WHERE productid = var_prod_id);
        END IF;

        -- Get the price of the selected product and store it in var_prod_price
        SELECT price
        INTO var_prod_price
        FROM Products
        WHERE productid = var_prod_id;

        
        SELECT MAX(OrderDetail_ID)  -- Get the maximum OrderDetail_ID and increment by 1 for the new order detail
        INTO new_order_detail_id			-- Store it in new_order_detail_id
        FROM OrderDetails;

        -- Insert into the OrderDetails table for each product
        INSERT INTO OrderDetails (OrderDetail_ID, OrderID, ProductID, Qty, Tot_Amt)
        VALUES (new_order_detail_id + 1, new_order_id + 1, var_prod_id, var_qty, (var_qty * var_prod_price));

       
        UPDATE Products                
        SET Qty = Qty - var_qty            -- Update the stock for the product
        WHERE ProductID = var_prod_id;

        
        total_amount := total_amount + (var_qty * var_prod_price);      -- Calculate the total amount for the order
    END LOOP;

    -- Update the total amount for the order in Orders table
    UPDATE Orders
    SET Tot_Amt = total_amount
    WHERE OrderID = new_order_id + 1;

    RETURN new_order_id + 1;

END;
$$;

SELECT f1_name(
    1,
    '[{"product_id": 101, "qty": 2}, {"product_id": 102, "qty": 1}]'::jsonb  
);


-- TASK 2 : Write a user-defined function that takes a CustomerID and returns the total amount spent by that customer.

CREATE OR REPLACE FUNCTION f2_name (
    p_cust_id INT         -- CustomerID passed as Parameter.
)
RETURNS DECIMAL(10,2)
LANGUAGE plpgsql
AS $$
DECLARE
    var_tot_amt DECIMAL(10,2);                     -- Declaring the variable used in the below query
BEGIN
    -- Calculating the total amount spent by the customer
    SELECT SUM(OrderDetails.Tot_Amt)  
    INTO var_tot_amt
    FROM Orders 
    JOIN OrderDetails ON Orders.OrderID = OrderDetails.OrderID     -- Joining orders and orderdetails on equal orderID 
    WHERE Orders.CustomerID = p_cust_id;

    -- Check if the result is Not NULL, return the total amount
    IF var_tot_amt IS NOT NULL THEN
        RETURN var_tot_amt;
    ELSE
        RETURN 0;     -- else return 0  
    END IF;
END;
$$;

SELECT f2_name(1);  


-- TASK 3 : Transactions and Concurrency Control

-- Part 1 : Write a transaction to ensure an order is placed only if all products are in stock. If any product is out of stock, rollback the transaction.

CREATE OR REPLACE PROCEDURE process_order_and_place_order(
    p_customer_id INT,
    p_product_details JSONB  
) 
LANGUAGE plpgsql 
AS $$ 
DECLARE 
    product JSONB;
    available_qty INT;
    ordered_qty INT;
    product_id INT;
    new_order_id INT;
    success BOOLEAN := TRUE;
BEGIN
    BEGIN
        -- Checking stock availability
        FOR product IN 
            SELECT * FROM jsonb_array_elements(p_product_details) AS products
        LOOP
            product_id := (product->>'product_id')::INT;                -- Storing each product id in product_id
            ordered_qty := (product->>'qty')::INT;                      -- Storing each product quantity id in ordered_qty

            -- Fetch available stock 
            SELECT Qty INTO available_qty FROM Products WHERE ProductID = product_id;        

            
            IF ordered_qty > available_qty THEN           -- If stock is insufficient, raise an exception
                success := FALSE;						   -- Mark success as FALSE
                RAISE EXCEPTION 'Order cannot be placed. Product ID: % is out of stock (Requested: %, Available: %)', 
                    product_id, ordered_qty, available_qty;
            END IF;
        END LOOP;

        -- Place the order & update stock by calling my already created function f1_name
        SELECT f1_name(p_customer_id, p_product_details) INTO new_order_id;

    EXCEPTION 
        WHEN OTHERS THEN
            -- If any error occurs, set success flag to FALSE and log the error
            success := FALSE;
            RAISE NOTICE 'Transaction failed: %', SQLERRM;
    END;

    
    IF success THEN           -- If success == TRUE then commit 
        COMMIT;
        RAISE NOTICE 'Transaction committed successfully.';
    ELSE 					  -- Else Rollback
        ROLLBACK;
        RAISE NOTICE 'Transaction rolled back due to errors.';
    END IF;

END $$;


-- Valid 
CALL process_order_and_place_order(
    4,  
    '[{"product_id": 101, "qty": 2}, {"product_id": 102, "qty": 1}]'::jsonb
);

-- Rollback
CALL process_order_and_place_order(
    1,  
    '[{"product_id": 101, "qty": 1000}]'::jsonb  -- Exceeds stock
);


SELECT * FROM Orders;
SELECT * FROM OrderDetails;





-- TASK 4 : SQL for Reporting and Analytics

-- Part 1 : 1. Generate a customer purchase report using ROLLUP that includes:
--			   Total purchases by customer
--             Total of all purchases


SELECT CustomerID, SUM(Tot_Amt) AS Total_Purchases
FROM Orders
GROUP BY ROLLUP (CustomerID)  ;        -- Subtotal calculated using Rollup for only CustomerID

-- Part 2 : Use window functions (LEAD, LAG) to show how a customer's order amount compares to their previous order amount.

SELECT 
    CustomerID,OrderID,Tot_Amt AS Current_Order_Amount,
	LAG(Tot_Amt) OVER (PARTITION BY CustomerID ORDER BY OrderID) AS Previous_Order_Amount,  -- retrieving the Tot_Amt of the previous order for the same CustomerID based on the OrderID clause
    LEAD(Tot_Amt) OVER (PARTITION BY CustomerID ORDER BY OrderID) AS Next_Order_Amount,  -- retrieving the Tot_Amt of the next order for the same CustomerID based on the OrderID clause.
    Tot_Amt - LAG(Tot_Amt) OVER (PARTITION BY CustomerID ORDER BY OrderID) AS Difference_From_Previous_Order          -- Calculating the difference with the previous order
FROM Orders
ORDER BY CustomerID, OrderID;
