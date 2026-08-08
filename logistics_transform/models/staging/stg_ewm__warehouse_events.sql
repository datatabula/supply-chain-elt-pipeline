--pulls data from raw.sap_ewm_warehouse_events, one row per warehouse execution event
--standardizes col names and casts types; row order in the raw file doesn't matter here
--since timestamps are always correct even when rows arrive out of order
with source as (
    select * from {{ source('raw', 'sap_ewm_warehouse_events') }}
),

renamed as (
    select 
        TANUM                                  as warehouse_task_id,
        VBELN                                  as sales_document_id,
        LGNUM                                  as warehouse_code,
        VORGA                                  as process_type,
        try_to_timestamp(trim(CONFIRM_TS), 'DD.MM.YYYY HH24:MI:SS') as confirmed_at,
        try_to_number(trim(MENGE_CONF))           as quantity_confirmed
    from source

)

select * from renamed