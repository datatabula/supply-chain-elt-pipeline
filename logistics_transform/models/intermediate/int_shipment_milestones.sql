
--ref() should be used, not source(). source() points at 
--raw snowflake tables that exist outside dbt. ref() points at a model dbt itself built.
--ref() lets dbt understand the dependency chain so that int_shipment_milestones cant 
--run until stg_ewn_warehouse_events exists
with events as (
    select * from {{ ref('stg_ewm__warehouse_events') }}
),

--this part is called milestones bc each col represents a major step (milestone)  
--in the shipment's journey through the warehouse. they could be any: order creates>pick start>pick conf>
--pack start>pack conf>loaded>googs issued>delivered 
milestones as (
    select 
        sales_document_id,
        --why max?
        max(warehouse_code) as warehouse_code,
        --clever way to extract the timestamp of each milestone from the events table.
        --case when picks out the rows that match the milestone, and that creates a bunch of 
        -- nulls for the rest of the rows that doesnt match.
        -- and max() returns the timestamp of the row that matches the non-null value
        max(case when process_type = 'PICK_START' then confirmed_at end) as pick_start_at,  
        max(case when process_type = 'PICK_CONFIRM' then confirmed_at end) as pick_confirm_at,
        max(case when process_type = 'PACK_START' then confirmed_at end) as pack_start_at,
        max(case when process_type = 'PACK_CONFIRM' then confirmed_at end) as pack_confirm_at,
        max(case when process_type = 'LOAD' then confirmed_at end) as load_at,
        max(case when process_type = 'GOODS_ISSUE' then confirmed_at end) as goods_issue_at,

        -- the actual quantity confirmed during picking -- this is the true fulfillment 
        --quantity to compare against ordered quantity.
        max(case when process_type = 'PICK_CONFIRM' then quantity_confirmed end) as quantity_picked
    from events
    group by sales_document_id
)

select * from milestones