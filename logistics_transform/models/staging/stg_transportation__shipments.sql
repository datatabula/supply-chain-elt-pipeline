--pulls data from raw.transportation tracking(shipments sheet only)
--standardizes the shipment ref, parses mixed dates formts,
--and cleans freight cost values entered as text

with source as (
    select * from {{source('raw','transportation_tracking')}}
),

renamed as (
    select
        --strip everything except digits, so SH1001/SH-1001/1001 all become 1001
        regexp_replace(SHIPMENT_REF, '[^0-9]', '') as shipment_ref_standardized,
        ORDER_REF                                  as sales_document_id,
        CARRIER                                    as carrier_raw,
        SHIP_DATE                                  as ship_date_raw,
        PLANNED_DELIVERY_DATE                      as planned_delivery_date_raw,
        ACTUAL_DELIVERY_DATE                       as actual_delivery_date_raw,
        FREIGHT_COST_JPY                           as freight_cost_raw,
        STATUS                                     as shipment_status,
        DESTINATION_CITY                           as destination_city,
        SERVICE_LEVEL                              as service_level_raw,
        TRACKING_NUMBER                            as tracking_number
    from source
),

cleaned as (
    select
        shipment_ref_standardized,
        sales_document_id,
        carrier_raw,
        --dates arrived in 3 diff formats and a a few raw excel serial #s. 
        --try each pattern in order; whichever matches wins
        COALESCE(
            try_to_date(ship_date_raw, 'MM/DD/YYYY'),
            try_to_date(ship_date_raw, 'YYYY/MM/DD'), 
            --excel serial numbers are days since 1899-12-30, so we can add the number to that date to get the actual date
            try_to_date('1899-12-30'::date + try_to_number(ship_date_raw))
        ) as ship_date,

        COALESCE(
            try_to_date(planned_delivery_date_raw, 'MM/DD/YYYY'),
            try_to_date(planned_delivery_date_raw, 'YYYY/MM/DD'), 
            try_to_date('1899-12-30'::date + try_to_number(planned_delivery_date_raw))  
        ) as planned_delivery_date,

        COALESCE(
            try_to_date(actual_delivery_date_raw, 'MM/DD/YYYY'),
            try_to_date(actual_delivery_date_raw, 'YYYY/MM/DD'), 
            try_to_date('1899-12-30'::date + try_to_number(actual_delivery_date_raw))  
        ) as actual_delivery_date,

        --freight cost someimtes has a ¥ symbol. strip both before casting
        try_to_number(
                regexp_replace(freight_cost_raw, '[¥,]', '')
        ) as freight_cost_jpy,

        shipment_status,
        destination_city,
        service_level_raw,
        tracking_number
    from renamed

)

select * from cleaned