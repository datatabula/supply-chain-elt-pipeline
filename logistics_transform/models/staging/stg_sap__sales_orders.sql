--pulls data from raw.sap_sales_orders, nota hardcoded tablename.
--also renames the columns to match the conventions ofthe warehouse.
with source as (
    select * from logistics_platform.raw.sap_sales_orders
),

--standardization work
renamed as (
    select
        VBELN                                  as sales_document_id,
        try_to_date(trim(ERDAT), 'DD.MM.YYYY') as order_created_date,
        KUNNR                                  as customer_id,
        MATNR                                  as material_id,
        try_to_number(trim(KWMENG))           as order_quantity,
        WERKS                                  as plant_code,
        try_to_date(trim(VDATU), 'DD.MM.YYYY') as requested_delivery_date,
        try_to_date(trim(EDATU), 'DD.MM.YYYY') as schedule_line_date,
        VSBED                                  as shipping_condition_code,
        LPRIO                                  as delivery_priority_code,
        AUFT_STATUS                            as order_status

    from source

),

deduplicated as (
    select * 
    from renamed
    qualify row_number() over(
        partition by sales_document_id
        order by order_created_date
    ) = 1
)

select * from deduplicated