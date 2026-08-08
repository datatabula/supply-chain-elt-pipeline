select distinct
    standard_carrier_code as carrier_id,
    standard_carrier_code as carrier_name
from {{ ref ('carrier_mapping')}}
