-- joins carrier invoices onto the shipment/order model, using the
-- standardized shipment ref (not sales_document_id -- invoices don't
-- reference the sales order directly, only the shipment).
--
-- invoices are aggregated per shipment first, rather than joined directly,
-- because ~2% of shipments legitimately have more than one invoice posting
-- (a real business exception, not export noise -- see stg_finance__carrier_invoices).
-- collapsing to invoice_count + total lets that exception stay visible
-- as data, instead of silently duplicating shipment rows in this join.

--this loads the shipment data 
with shipments as (

    select * from {{ ref('int_orders_with_shipments') }}

),
--this loads the invoice data
invoices as (

    select * from {{ ref('stg_finance__carrier_invoices') }}

),
--Aggregate invoices per shipment
--we aggregate invoices per shipment first, to avoid duplicating shipment rows in the join
invoices_aggregated as (

    select
        shipment_ref_standardized,
        count(*)                          as invoice_count,
        sum(invoice_amount_jpy)           as total_invoiced_amount_jpy,
        min(invoice_date)                 as first_invoice_date

    from invoices
    group by shipment_ref_standardized

),
-- This part selects the shipment and invoice columns
joined as (

    select
        --this selects evth frm shipment
        shipments.*,
        --this selects the new invoice col we just made
        invoices_aggregated.invoice_count,
        invoices_aggregated.total_invoiced_amount_jpy,
        invoices_aggregated.first_invoice_date,

        -- per A-006: a shipment without an invoice yet isn't automatically
        -- invalid -- invoices lag delivery by a normal AP cycle. this status
        -- distinguishes "genuinely not invoiced yet" from "actually matched"
        case
            when invoices_aggregated.invoice_count is not null then 'matched'
            when shipments.actual_delivery_date is not null       then 'delivered, awaiting invoice'
            when shipments.ship_date is not null                 then 'shipped, awaiting invoice'
            else 'not yet shipped'
        end as invoice_match_status

    from shipments
    left join invoices_aggregated
        on shipments.shipment_ref_standardized = invoices_aggregated.shipment_ref_standardized

)

select * from joined