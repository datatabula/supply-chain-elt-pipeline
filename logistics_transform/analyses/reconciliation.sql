-- end-to-end row trace from ingestion to the final mart
-- Document the end-to-end row-count trace (312 → 300 → 287 → 283 → 233 → 300 final)
-- this query makes that trace something you can actually rerun and verify

--this query is typically used in reconciliation
--this part asks "how many rows are currently in the raw sap_sales_orders?"
select 'raw:sap_sales_orders' as stage,     --a label; tells you which layer the row count belongs to 
        count(*) as row_count               -- a row count
from {{ source('raw','sap_sales_orders')}}  --the source table

union all

select 'staging: stg_sap__sales_orders (deduped)', count(*)
from {{ ref('stg_sap__sales_orders')}}

union all

select 'staging: stg_ewm__warehouse_events (distinct shipments w/events)', count(distinct(sales_document_id))
from {{ref('stg_ewm__warehouse_events')}}

union all

select 'staging: stg_transportation__shipments(shipped)', count(*)
from {{ref('stg_transportation__shipments')}}

union all
select 'staging: stg_finance__carrier_invoices (raw invoice postings)', count(*)
from LOGISTICS_PLATFORM.STAGING.stg_finance__carrier_invoices
union all
select 'intermediate: int_shipment_costs (matched invoices)', count(*)
from LOGISTICS_PLATFORM.intermediate.int_shipment_costs
where invoice_match_status = 'matched'

union all

select 'marts: fct_logistics_performance(final grain)', count(*)
from {{ref('fct_logistics_performance')}}