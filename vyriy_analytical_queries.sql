-- ============================================================================
-- VYRIY INDUSTRIES: ANALYTICAL SQL QUERIES (DATA MART & KPI LAYER)
-- Author: Hanna Makryshcheva
-- Description: Production quality (FTT Rate), vendor reliability, and rework cost analysis
-- ============================================================================

-- 1. Monthly Production Plan vs Fact & FTT Rate Dynamics
WITH MonthlyActuals AS (
    SELECT 
        strftime('%Y-%m-01', AssemblyDate) AS MonthStart,
        ProductID,
        COUNT(DroneSN) AS ActualUnits,
        SUM(CASE WHEN TestStatus = 'Pass' THEN 1 ELSE 0 END) AS PassedUnits,
        SUM(ReworkCost_USD) AS ReworkLoss_USD
    FROM Fact_Production_Logs
    GROUP BY 1, 2
)
SELECT 
    t.MonthStart,
    p.ProductName,
    t.PlannedUnits,
    a.ActualUnits,
    ROUND(100.0 * a.ActualUnits / t.PlannedUnits, 1) AS PlanCompletion_Pct,
    ROUND(100.0 * a.PassedUnits / a.ActualUnits, 2) AS FTT_Rate_Pct,
    a.ReworkLoss_USD
FROM Fact_Production_Targets t
JOIN Dim_Products p ON t.ProductID = p.ProductID
LEFT JOIN MonthlyActuals a ON t.MonthStart = a.MonthStart AND t.ProductID = a.ProductID
ORDER BY t.MonthStart, p.ProductID;

-- 2. Vendor Scorecard: Defect Rate, Delivery Delay & Financial Impact
SELECT 
    v.VendorName,
    v.Country,
    COUNT(q.BatchID) AS DeliveriesCount,
    SUM(q.QtyOrdered) AS TotalUnitsOrdered,
    SUM(q.QtyDefective) AS DefectiveUnits,
    ROUND(100.0 * SUM(q.QtyDefective) / SUM(q.QtyOrdered), 2) AS IncomingDefectRate_Pct,
    ROUND(AVG(q.ActualLeadTime - q.ContractLeadTime), 1) AS AvgDeliveryDelay_Days,
    ROUND(SUM(q.QtyDefective * c.UnitCost_USD), 2) AS FinancialLoss_USD
FROM Fact_Procurement_QC q
JOIN Dim_Vendors v ON q.VendorID = v.VendorID
JOIN Dim_Components c ON q.ComponentID = c.ComponentID
GROUP BY v.VendorName, v.Country
ORDER BY FinancialLoss_USD DESC;

-- 3. Engineer Performance & Learning Curve Analysis (Window Functions)
SELECT 
    e.Workshop,
    e.EngineerName,
    e.Grade,
    COUNT(p.DroneSN) AS TotalAssembled,
    ROUND(100.0 * SUM(CASE WHEN p.TestStatus = 'Pass' THEN 1 ELSE 0 END) / COUNT(p.DroneSN), 2) AS FTT_Rate_Pct,
    ROUND(AVG(p.ActualAssemblyMin), 1) AS AvgTimeMin,
    RANK() OVER (PARTITION BY e.Workshop ORDER BY 100.0 * SUM(CASE WHEN p.TestStatus = 'Pass' THEN 1 ELSE 0 END) / COUNT(p.DroneSN) DESC) AS WorkshopQualityRank
FROM Fact_Production_Logs p
JOIN Dim_Engineers e ON p.EngineerID = e.EngineerID
GROUP BY e.Workshop, e.EngineerName, e.Grade
ORDER BY e.Workshop, WorkshopQualityRank;
