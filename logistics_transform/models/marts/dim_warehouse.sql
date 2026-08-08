select 
    standard_warehouse_id as warehouse_id,
    warehouse_name,
    region_site_type
from {{ ref('warehouse_mapping')}}