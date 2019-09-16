WITH
upcoming_max_deal_discount_percent AS (
  SELECT
    iso_week,
    pud.product_id,
    MAX(pud.deal_percent) max_deal_discount_percent
  FROM
  `tiki-dwh.ops_demand_forecast.product_upcoming_deal_*` pud
  WHERE
    format_date("%Y%V",parse_date("%Y%m%d",_table_suffix)) = format_date("%Y%V", parse_date("%Y%m%d",'{{tomorrow_ds_nodash}}'))
  GROUP BY 1,2
),

upcoming_coupon_discount_percent AS (
  SELECT
    iso_week,
    puc.product_id,
    MAX(puc.percent_discount) max_coupon_discount_percent
  FROM
    `tiki-dwh.ops_demand_forecast.product_upcoming_coupons_*` puc
  WHERE
    format_date("%Y%V",parse_date("%Y%m%d",_table_suffix)) = format_date("%Y%V", parse_date("%Y%m%d",'{{tomorrow_ds_nodash}}'))
  GROUP BY 1,2
),

product_info AS (
SELECT
  DISTINCT
  ccp.product_id,
  ccp.category_id AS primary_cate,
  dp.sub_cate_report
FROM
  `tiki-dwh.ecom.catalog_category_product` ccp
left join `tiki-dwh.dwh.dim_product_full` dp on product_id = product_key 
WHERE
  ccp.is_primary = 1
  AND entity_type like "%seller_simple%"
  AND business_type like "%1P%"
  AND is_listed is true
),

deal_and_coupon_data as(
  select 
    coalesce(dp.product_id,cp.product_id) as product_id,
    coalesce(dp.iso_week,cp.iso_week) as iso_week,
    max_deal_discount_percent,
    max_coupon_discount_percent
  from upcoming_max_deal_discount_percent dp
  full join upcoming_coupon_discount_percent cp on dp.product_id = cp.product_id and dp.iso_week = cp.iso_week 
),

map_week_and_product as (
  select iso_week, pi.*
  from(select distinct iso_week
       from deal_and_coupon_data)
  cross join product_info pi
  order by product_id, iso_week
)

select
  pd.iso_week,
  pd.product_id,
  sub_cate_report,
  primary_cate,
  0 as total_orders,
  0 as total_orders_ignore_cancel,
  ifnull(max_deal_discount_percent, 0) as max_deal_discount_percent,
  ifnull(max_coupon_discount_percent, 0) as max_coupon_discount_percent,
  0 as weight_coupon,
  0 as most_freq_coupon
from 
  map_week_and_product pd 
left join 
  deal_and_coupon_data dc using(product_id, iso_week)
order by pd.product_id, iso_week