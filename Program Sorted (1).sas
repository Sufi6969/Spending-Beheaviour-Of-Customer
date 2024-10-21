/* Tables Load */
proc import datafile='/home/u63391350/sasuser.v94/Customer Aquisition.xlsx' out=Customer dbms=xlsx replace;
    sheet='Sheet1';
    getnames=yes;
run;

proc import datafile='/home/u63391350/sasuser.v94/Repayment.xlsx' out=Repayment dbms=xlsx replace;
    sheet='Sheet1';
    getnames=yes;
run;

proc import datafile='/home/u63391350/sasuser.v94/Spend.xlsx' out=Spend dbms=xlsx replace;
    sheet='Sheet1';
    getnames=yes;
run;

/* (1) Calculate Average Age & Replace under 18 */
proc means data=Customer noprint;
    var Age;
    output out=AverageAge(drop=_type_ _freq_) mean=AvgAge;
run;
data Customer;
    set Customer;
    if Age < 18 then Age = 18;
run;

/* (2) At the Last*/

/* (3)Monthly Spend of each Customer */
proc sql;
    create table MonthlySpend as
    select Customer, Month, Amount as Spend
    from Spend
    group by Customer, Month;
quit;

/* (4)Monthly Repayment of each Customer */
proc sql;
    create table MonthlyRepayment as
    select Customer, Month, sum(Amount) as Repayment
    from Repayment
    group by Customer, Month;
quit;

/* (5)Find highest paying 10 customers */
proc sql;
    create table CustomerRepay as
    select Customer, sum(Repayment) as TotalRepayment
    from MonthlyRepayment
    group by Customer
    order by TotalRepayment desc;    
quit;
proc sql;
    create table Top10Customers as
    select Customer, TotalRepayment
    from CustomerRepay
    where monotonic() <= 10;
quit;

/* (6)Segment with the highest spending */
proc sql;
    create table SegmentSpending as
    select c.Segment, sum(s.Spend) as TotalSpend
    from Customer c
    inner join MonthlySpend s on c.Customer = s.Customer
    group by c.Segment
    order by TotalSpend desc;
quit;

/* (7)Age group with the highest spending */
proc sql;
    create table AgeGroupSpending as
    select 
        case
            when c.Age between 18 and 30 then '18-30'
            when c.Age between 31 and 50 then '31-45'
            when c.Age between 51 and 70 then '46-60'
            else '60+'
        end as AgeGroup,
        sum(s.Amount) as TotalSpend
    from Customer c
    inner join Spend s on c.Customer = s.Customer
    group by AgeGroup;
quit;

/* (8)Most profitable segment */
proc sql;
    create table MostProfitableSegment as
    select c.Segment, sum(r.Amount - s.Amount) as Profit
    from Customer c
    inner join Spend s on c.Customer = s.Customer
    inner join Repayment r on c.Customer = r.Customer and s.Month = r.Month
    group by c.Segment
    having Profit > 0
    order by Profit desc;
quit;

/* (9)Category with the highest spending */
proc sql;
    create table CategorySpending as
    select Type, sum(Amount) as TotalSpend
    from Spend
    group by Type 
    order by TotalSpend desc;
quit;

/* (10)Monthly profit for the bank */
proc sql;
    create table MonthlyProfit as
    select r.Month, sum(r.Repayment - s.Spend) as Profit
    from MonthlyRepayment r
    inner join MonthlySpend s on r.Customer = s.Customer and r.Month = s.Month
    group by r.Month;
quit;

/*  (11)Intreset of 2.9% on due amounts */
proc sort data=Customer;
    by Customer;
run;
data DueInterest;
    merge MonthlyRepayment MonthlySpend(keep=Customer Spend) Customer(keep=Customer Limit);
    by Customer;
    DueAmount = Repayment - Spend;
    if DueAmount < 0 then do;
        Interest = abs(0.029 * DueAmount);
    end;
    else do;
        Interest = 0;
    end;
    keep Customer DueAmount Interest;
run;
/* (12)Surplus = Repay > Spend */
data SurplusAmount;
    merge MonthlyRepayment MonthlySpend(keep=Customer Spend) Customer(keep=Customer Limit);
    by Customer;
    Surplus = Repayment - Spend;
    if Surplus > 0 then do;
        SurplusAmount = Surplus + (0.02 * Surplus);
    end;
    else do;
        SurplusAmount = 0;
    end;
    keep Customer Surplus SurplusAmount;
run;


