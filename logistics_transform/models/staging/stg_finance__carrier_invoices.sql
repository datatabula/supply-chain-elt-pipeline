-- pulls data from raw.carrier_invoices
-- standardizes the shipment reference to the same digit-only format used in
-- stg_transportation__shipments, so the two can be joined later

-- deliberately does NOT dedupe the ~2% re-keyed invoices (same shipment, same
-- amount, different invoice number) -- unlike the sales orders' exact re-export
-- duplicates, these are a genuine business exception (a possible double-billing
-- or overcharge), not an export artifact. silently dropping one would hide real
-- financial data; it should stay visible here and get caught by a dbt test instead.

with source as (
    select * from {{source('raw','carrier_invoices')}}
),

renamed as (
    select
        BELNR                                    as invoice_document_id,
        LIFNR                                    as vendor_id,
        regexp_replace(VBELN_REF, '[^0-9]', '')  as shipment_ref_standardized,
        try_to_date(trim(BUDAT), 'DD.MM.YYYY')   as posting_date,
        try_to_date(trim(RECHNUNGSDATUM), 'DD.MM.YYYY') as invoice_date,
        try_to_number(trim(WRBTR))               as invoice_amount_jpy,
        WAERS                                    as currency_code
    from source
)

select * from renamed
