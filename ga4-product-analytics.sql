-- GA4 E-commerce Product Analytics (BigQuery)
-- Dataset: bigquery-public-data.ga4_obfuscated_sample_ecommerce (Google Merchandise Store)
-- Period: 2020-11-01 to 2021-01-31
-- Runs on the free BigQuery sandbox.


-- 1) Ordered purchase funnel: view_item -> add_to_cart -> begin_checkout -> purchase
--    A user counts at a step only if they reached the previous step first.
WITH user_steps AS (
  SELECT
    user_pseudo_id,
    MIN(IF(event_name = 'view_item',      event_timestamp, NULL)) AS t_view,
    MIN(IF(event_name = 'add_to_cart',    event_timestamp, NULL)) AS t_cart,
    MIN(IF(event_name = 'begin_checkout', event_timestamp, NULL)) AS t_checkout,
    MIN(IF(event_name = 'purchase',       event_timestamp, NULL)) AS t_purchase
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  GROUP BY user_pseudo_id
),
funnel AS (
  SELECT
    COUNTIF(t_view IS NOT NULL)                                              AS viewed,
    COUNTIF(t_cart > t_view)                                                 AS carted,
    COUNTIF(t_checkout > t_cart AND t_cart > t_view)                         AS checkout,
    COUNTIF(t_purchase > t_checkout AND t_checkout > t_cart AND t_cart > t_view) AS purchased
  FROM user_steps
)
SELECT
  viewed, carted, checkout, purchased,
  ROUND(100 * SAFE_DIVIDE(carted, viewed), 2)      AS view_to_cart_pct,
  ROUND(100 * SAFE_DIVIDE(checkout, carted), 2)    AS cart_to_checkout_pct,
  ROUND(100 * SAFE_DIVIDE(purchased, checkout), 2) AS checkout_to_purchase_pct,
  ROUND(100 * SAFE_DIVIDE(purchased, viewed), 2)   AS overall_conversion_pct
FROM funnel;


-- 2) Funnel conversion by device category (does mobile drop off more?)
WITH user_steps AS (
  SELECT
    user_pseudo_id,
    ANY_VALUE(device.category) AS device,
    LOGICAL_OR(event_name = 'view_item')      AS viewed,
    LOGICAL_OR(event_name = 'add_to_cart')    AS carted,
    LOGICAL_OR(event_name = 'begin_checkout') AS checkout,
    LOGICAL_OR(event_name = 'purchase')       AS purchased
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  GROUP BY user_pseudo_id
)
SELECT
  device,
  COUNT(*)            AS users,
  COUNTIF(viewed)     AS viewed,
  COUNTIF(purchased)  AS purchased,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(carted),    COUNTIF(viewed)), 2)   AS view_to_cart_pct,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased), COUNTIF(checkout)), 2) AS checkout_to_purchase_pct,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased), COUNT(*)), 2)          AS user_conversion_pct
FROM user_steps
GROUP BY device
ORDER BY users DESC;


-- 3) Weekly cohort retention (week 0 to week 8)
WITH base AS (
  SELECT user_pseudo_id, PARSE_DATE('%Y%m%d', event_date) AS d
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
first_seen AS (
  SELECT user_pseudo_id, DATE_TRUNC(MIN(d), WEEK) AS cohort_week
  FROM base
  GROUP BY user_pseudo_id
),
activity AS (
  SELECT DISTINCT user_pseudo_id, DATE_TRUNC(d, WEEK) AS active_week
  FROM base
),
cohort_size AS (
  SELECT cohort_week, COUNT(*) AS size
  FROM first_seen
  GROUP BY cohort_week
)
SELECT
  f.cohort_week,
  c.size AS cohort_users,
  DATE_DIFF(a.active_week, f.cohort_week, WEEK) AS week_n,
  COUNT(DISTINCT a.user_pseudo_id) AS active_users,
  ROUND(100 * COUNT(DISTINCT a.user_pseudo_id) / c.size, 2) AS retention_pct
FROM first_seen f
JOIN activity a    ON a.user_pseudo_id = f.user_pseudo_id
JOIN cohort_size c ON c.cohort_week = f.cohort_week
WHERE DATE_DIFF(a.active_week, f.cohort_week, WEEK) BETWEEN 0 AND 8
GROUP BY f.cohort_week, c.size, week_n
ORDER BY f.cohort_week, week_n;


-- 4) Checkout abandonment by acquisition channel (traffic medium)
WITH u AS (
  SELECT
    user_pseudo_id,
    ANY_VALUE(traffic_source.medium)    AS medium,
    LOGICAL_OR(event_name = 'begin_checkout') AS started,
    LOGICAL_OR(event_name = 'purchase')       AS purchased
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  GROUP BY user_pseudo_id
)
SELECT
  medium,
  COUNTIF(started)                    AS started_checkout,
  COUNTIF(started AND NOT purchased)  AS abandoned,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(started AND NOT purchased), COUNTIF(started)), 2) AS abandonment_pct
FROM u
GROUP BY medium
HAVING started_checkout >= 50
ORDER BY abandonment_pct DESC;


-- 5) Daily active users and purchase conversion trend (spot holiday spikes / drops)
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS day,
  COUNT(DISTINCT user_pseudo_id) AS dau,
  COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)) AS buyers,
  ROUND(100 * SAFE_DIVIDE(
    COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)),
    COUNT(DISTINCT user_pseudo_id)), 2) AS conversion_pct
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY day
ORDER BY day;
