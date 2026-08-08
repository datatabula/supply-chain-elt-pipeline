--fact table using all int tables
-- one row per shipment

--order of writing: CTEs pulling refs > join logic >each metric formula at a time. 

---start with the shipments cost data that this model will build upon
with base as(
    select * from {{ ref('int_shipment_costs')}}
),
carrier_lookup as (
    select * from {{ ref('carrier_mapping')}}
),
warehouse_lookup as (
    select * from {{ref('warehouse_mapping')}}
),

joined as ( 
    select 
        --get the cleaned shipment id
        coalesce(base.shipment_ref_standardized, base.sales_document_id) as shipment_id,
        base.sales_document_id                              as sales_order_id,
        --get the standard one
        warehouse_lookup.standard_warehouse_id              as warehouse_id,
        carrier_lookup.standard_carrier_code                as carrier_id,

        base.order_created_date                             as order_date,
        base.requested_delivery_date,
        base.schedule_line_date,
        base.pick_start_at,
        base.pick_confirm_at,
        base.pack_start_at,
        base.pack_confirm_at,
        base.goods_issue_at,
        base.ship_date,
        base.planned_delivery_date,
        base.actual_delivery_date,

        base.order_quantity,
        base.quantity_picked,
        base.freight_cost_jpy,
        
        base.shipment_status,
        base.invoice_count,
        base.total_invoiced_amount_jpy,
        base.invoice_match_status

    from base
    left join carrier_lookup
        on base.carrier_raw = carrier_lookup.raw_carrier_name
    left join warehouse_lookup
        on base.plant_code = warehouse_lookup.raw_warehouse_code

),

metrics as (
    select 
        *,

        --warehouse execution timings, in hrs (KPI dictionary : pick time, pack time, warehouse processing time)
        --datediff('unit', start, end) in this case, total picking time in sec / 1hr (3600secs), rounded to 1
        round(datediff('second', pick_start_at, pick_confirm_at) / 3600.0, 1)
            as pick_time_hours,
        round(datediff('second', pack_start_at, pack_confirm_at) / 3600.0, 1)
            as pack_time_hours,
        round(datediff('second', pick_start_at, coalesce(goods_issue_at, pack_confirm_at)) / 3600.0, 1)
            as warehouse_processing_hours,

        --shipment-level timing in days 
        datediff('day', ship_date, actual_delivery_date)            as transit_days,
        datediff('day', order_date, actual_delivery_date)           as total_lead_time_days,

        --delay measured against the customer's originally requested date
        datediff('day', requested_delivery_date, actual_delivery_date) as delay_days,

        case
            when actual_delivery_date is null then null
            when actual_delivery_date <= requested_delivery_date then true
            else false
        end as on_time_delivery_flag,

        -- Order accuracy rate : quantity actually picked vs. quantity ordered
        case 
            when quantity_picked is null then null
            when quantity_picked = order_quantity then true
            else false
        end as order_accuracy_flag,

        --invoice_match_flag
        case when invoice_match_status = 'matched' then true else false end
            as invoice_match_flag
        
    from joined

)

select * from metrics


