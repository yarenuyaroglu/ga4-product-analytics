# GA4 e-commerce analysis in BigQuery

I wanted to practice product analytics on real event data, so I took Google's public GA4 sample (the Google Merchandise Store) and tried to answer a few questions a PM would actually ask: where do people drop off, does mobile behave differently, who comes back, and what would I test first.

Data: `bigquery-public-data.ga4_obfuscated_sample_ecommerce`, Nov 1 2020 to Jan 31 2021, roughly 270K users. All queries are in [`ga4-product-analytics.sql`](ga4-product-analytics.sql) and run fine on the free BigQuery sandbox.

## 1. Purchase funnel

I built the funnel as an ordered sequence, so a user only counts at a step if they hit the previous one first.

| Step | Users | Conversion from previous step |
|---|---|---|
| Viewed item | 61,252 | |
| Added to cart | 11,114 | 18.1% |
| Began checkout | 4,167 | 37.5% |
| Purchased | 2,356 | 56.5% |

About 3.9% of people who viewed an item ended up buying. The product page loses the most people in raw numbers, but the step I care more about is cart to checkout. 62.5% of people who put something in their cart never started checkout, and those are users who already wanted to buy.

## 2. Device split

I expected mobile to be the weak spot. It isn't.

| Device | Users | View to cart | Checkout to purchase | Converted |
|---|---|---|---|---|
| Desktop | 156,952 | 20.3% | 44.9% | 1.60% |
| Mobile | 107,133 | 20.8% | 46.3% | 1.69% |
| Tablet | 6,069 | 19.5% | 44.9% | 1.58% |

Mobile is actually slightly ahead at every step. So whatever is wrong with the funnel probably isn't a mobile UI problem. I'd look at what the cart shows (price, shipping, delivery time) before redesigning anything for small screens.

## 3. Retention by weekly cohort

This was the most interesting result for me. Users who first showed up in November came back the next week at around 5.9% on average. For the December cohorts (Dec 6 to Dec 27) that dropped to about 2.9%.

My read: the holiday season brings in a lot of one-time gift shoppers. More traffic, but half as likely to return.

## 4. Checkout abandonment by channel

| Channel | Started checkout | Abandoned | Rate |
|---|---|---|---|
| Other | 1,298 | 794 | 61.2% |
| Organic | 3,065 | 1,795 | 58.6% |
| Paid (cpc) | 380 | 219 | 57.6% |
| Direct | 2,217 | 1,222 | 55.1% |
| Referral | 1,888 | 948 | 50.2% |

Referral users abandon about 8 points less than organic ones. Organic is the biggest channel though, so in absolute terms it loses the most buyers.

## 5. Daily trend

Conversion peaks around Black Friday and Cyber Monday (3.17% on Nov 30) and again on Dec 11 (2.93%). After about Dec 19 it falls off a cliff. The average daily rate goes from around 2.1% (Dec 1 to 18) to around 0.8% (Dec 20 to Jan 11), even though traffic doesn't drop much. My guess is that people realize orders won't arrive before Christmas and stop buying.

There are also a couple of days with big traffic spikes and no matching sales (Dec 8 had 6,689 users at 1.64%, Jan 6 had 5,486 at 0.51%). Looks like campaigns that brought visits but not buyers.

## What I'd test

**Show shipping cost and delivery date in the cart.** If people leave the cart because the total or the delivery date surprises them at checkout, showing it earlier should help. I'd target users with at least one item in the cart and measure cart to checkout rate (currently 37.5%), with purchase rate as a guardrail so we don't just push people into checkout and lose them there.

**"Won't arrive in time" messaging after the shipping cutoff.** From around Dec 18, tell visitors honestly and offer a digital gift card instead. Main metric would be daily purchase conversion compared with the same period.

Two smaller ideas: a re-engagement email for holiday cohorts in their first two weeks (compare week 1 and week 2 retention against November), and looking at what referral sources say about the store to see if some of that messaging works on organic landing pages.

## Notes on the method

- Queries 2 and 4 count users who triggered an event at any point, not in order, so their numbers don't line up exactly with the ordered funnel in query 1.
- Weeks start on Sunday. The dataset ends on Jan 31, so the last few weeks of each cohort are partial. The tiny numbers at the end of the retention table come from that, not from users suddenly leaving.
- I left out the "(data deleted)" traffic, which GA4 strips for privacy.
- Google obfuscates this dataset, so the patterns are useful but the exact numbers aren't the store's real figures.
