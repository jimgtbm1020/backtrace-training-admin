-- Restore the Resource Library's jurisdiction query contract after the rebuild.
-- Existing IDs, assignments, active flags, and custom ordering are preserved.
begin;

alter table public.training_jurisdictions
  add column if not exists active boolean not null default true,
  add column if not exists sort_order integer not null default 0;

-- The upload form defaults to GENERAL and offers US states in name order.
-- Conflict handling preserves existing configuration and makes the seed repeatable.
insert into public.training_jurisdictions (code, name, active, sort_order)
values
  ('GENERAL', 'National / General', true, 0),
  ('AL', 'Alabama', true, 10),
  ('AK', 'Alaska', true, 20),
  ('AZ', 'Arizona', true, 30),
  ('AR', 'Arkansas', true, 40),
  ('CA', 'California', true, 50),
  ('CO', 'Colorado', true, 60),
  ('CT', 'Connecticut', true, 70),
  ('DE', 'Delaware', true, 80),
  ('DC', 'District of Columbia', true, 90),
  ('FL', 'Florida', true, 100),
  ('GA', 'Georgia', true, 110),
  ('HI', 'Hawaii', true, 120),
  ('ID', 'Idaho', true, 130),
  ('IL', 'Illinois', true, 140),
  ('IN', 'Indiana', true, 150),
  ('IA', 'Iowa', true, 160),
  ('KS', 'Kansas', true, 170),
  ('KY', 'Kentucky', true, 180),
  ('LA', 'Louisiana', true, 190),
  ('ME', 'Maine', true, 200),
  ('MD', 'Maryland', true, 210),
  ('MA', 'Massachusetts', true, 220),
  ('MI', 'Michigan', true, 230),
  ('MN', 'Minnesota', true, 240),
  ('MS', 'Mississippi', true, 250),
  ('MO', 'Missouri', true, 260),
  ('MT', 'Montana', true, 270),
  ('NE', 'Nebraska', true, 280),
  ('NV', 'Nevada', true, 290),
  ('NH', 'New Hampshire', true, 300),
  ('NJ', 'New Jersey', true, 310),
  ('NM', 'New Mexico', true, 320),
  ('NY', 'New York', true, 330),
  ('NC', 'North Carolina', true, 340),
  ('ND', 'North Dakota', true, 350),
  ('OH', 'Ohio', true, 360),
  ('OK', 'Oklahoma', true, 370),
  ('OR', 'Oregon', true, 380),
  ('PA', 'Pennsylvania', true, 390),
  ('RI', 'Rhode Island', true, 400),
  ('SC', 'South Carolina', true, 410),
  ('SD', 'South Dakota', true, 420),
  ('TN', 'Tennessee', true, 430),
  ('TX', 'Texas', true, 440),
  ('UT', 'Utah', true, 450),
  ('VT', 'Vermont', true, 460),
  ('VA', 'Virginia', true, 470),
  ('WA', 'Washington', true, 480),
  ('WV', 'West Virginia', true, 490),
  ('WI', 'Wisconsin', true, 500),
  ('WY', 'Wyoming', true, 510)
on conflict (code) do nothing;

notify pgrst, 'reload schema';
commit;
