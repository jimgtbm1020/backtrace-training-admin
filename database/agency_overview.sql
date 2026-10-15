-- Optional agency-specific overview. Existing agency RLS and update-conflict checks apply.
alter table public.business_rules_agencies
 add column overview_heading text not null default 'Core Features (Quick Overview)' check(length(overview_heading)<=160),
 add column overview_introduction text not null default '' check(length(overview_introduction)<=6000),
 add column overview_features text not null default '' check(length(overview_features)<=12000);
