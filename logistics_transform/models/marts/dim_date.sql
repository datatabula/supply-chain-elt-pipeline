--generates  one row per calendar day from the earliest order date to the latest known shipment date

with date_bounds as (
    select
        min(order_created_date) as min_date,
        --this is asking "what is the most recent date we have a shipment milestone for"
        max(coalesce(actual_delivery_date, planned_delivery_date, ship_date, order_created_date)) as max_date
    from {{ ref('int_orders_with_shipments') }}    
),

-- a date spine is every date in a continuous sequence
-- this is a common pattern as a date spine. table(generator(rowcount => 200)) means generate 200 empty rows,
--seq4() generates a sequence ofnumbers that numbers every generated row 
--dateadd() combines x days to the starting date. the syntax is dateadd(unit, amount, starting_date)
date_spine as(
    select dateadd(day, seq4(), (select min_date from date_bounds)) as date_day
    from table(generator(rowcount=>200))
),
--this section removes the extra dates generates after max_date
filtered as (
    select date_day
    from date_bounds, date_spine
    where date_day <= max_date
)

select 
    date_day                                    as date_id,
    year(date_day)                              as year_number,
    quarter(date_day)                           as quarter_number,
    month(date_day)                            as month_number,
    monthname(date_day)                          as month_name,
    day(date_day)                               as day_of_month,
    dayofweek(date_day)                         as day_of_week_number,
    dayname(date_day)                           as day_of_week_name,
    --Check what day of the week date_day is. If it is Saturday or Sunday, return true. Otherwise, return false.
    case when dayofweek(date_day) in (0,6) then true else false end as is_weekend
from filtered
order by date_day
    