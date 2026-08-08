-- joins sales orders, warehouse milestones, and transportation tracking into
-- one row per shipment. left joins throughout, since not every order has
-- progressed to every stage yet (backlog is expected, by design).

with orders as (

    select * from {{ ref('stg_sap__sales_orders') }}

),

milestones as (

    select * from {{ ref('int_shipment_milestones') }}

),

transportation as (

    select * from {{ ref('stg_transportation__shipments') }}

),

joined as (

    select
        orders.sales_document_id,
        orders.customer_id,
        orders.material_id,
        orders.plant_code,
        orders.order_created_date,
        orders.order_quantity,
        orders.requested_delivery_date,
        orders.schedule_line_date,
        orders.shipping_condition_code,
        orders.delivery_priority_code,
        orders.order_status,

        milestones.warehouse_code,
        milestones.pick_start_at,
        milestones.pick_confirm_at,
        milestones.pack_start_at,
        milestones.pack_confirm_at,
        milestones.load_at,
        milestones.goods_issue_at,
        milestones.quantity_picked,

        transportation.shipment_ref_standardized,
        transportation.carrier_raw,
        transportation.ship_date,
        transportation.planned_delivery_date,
        transportation.actual_delivery_date,
        transportation.freight_cost_jpy,
        transportation.shipment_status,
        transportation.destination_city

    from orders
    left join milestones
        on orders.sales_document_id = milestones.sales_document_id
    left join transportation
        on orders.sales_document_id = transportation.sales_document_id

)

select * from joined