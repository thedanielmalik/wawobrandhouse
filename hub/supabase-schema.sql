-- WAWO Hub Supabase schema (next backend phase)
create extension if not exists "uuid-ossp";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'Staff' check (role in ('Admin','Sales','Production','Inventory','Finance','Staff')),
  created_at timestamptz not null default now()
);

create table if not exists public.clients (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  contact_person text,
  phone text,
  email text,
  address text,
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create table if not exists public.products (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  category text not null,
  unit text not null default 'pcs',
  selling_price numeric(14,2) not null default 0,
  base_cost numeric(14,2) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.inventory_items (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  sku text unique,
  category text not null,
  unit text not null default 'pcs',
  current_stock numeric(14,2) not null default 0,
  reorder_level numeric(14,2) not null default 0,
  unit_cost numeric(14,2) not null default 0,
  supplier_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.suppliers (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  contact_person text,
  phone text,
  email text,
  address text,
  created_at timestamptz not null default now()
);

create table if not exists public.stock_movements (
  id uuid primary key default uuid_generate_v4(),
  inventory_item_id uuid not null references public.inventory_items(id) on delete cascade,
  movement_type text not null check (movement_type in ('receive','issue','adjustment')),
  quantity numeric(14,2) not null,
  unit_cost numeric(14,2),
  reference text,
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

alter table public.inventory_items
  add constraint inventory_supplier_fk foreign key (supplier_id) references public.suppliers(id);

create table if not exists public.quotes (
  id uuid primary key default uuid_generate_v4(),
  quote_number text unique not null,
  client_id uuid not null references public.clients(id),
  quote_date date not null default current_date,
  valid_until date,
  status text not null default 'Draft' check (status in ('Draft','Sent','Accepted','Rejected','Expired')),
  subtotal numeric(14,2) not null default 0,
  discount numeric(14,2) not null default 0,
  delivery numeric(14,2) not null default 0,
  other_charges numeric(14,2) not null default 0,
  tax numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.quote_items (
  id uuid primary key default uuid_generate_v4(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
  product_id uuid references public.products(id),
  description text not null,
  quantity numeric(14,2) not null default 1,
  unit_price numeric(14,2) not null default 0,
  line_total numeric(14,2) not null default 0
);

create table if not exists public.orders (
  id uuid primary key default uuid_generate_v4(),
  job_number text unique not null,
  client_id uuid not null references public.clients(id),
  quote_id uuid references public.quotes(id),
  order_date date not null default current_date,
  due_date date,
  priority text not null default 'Normal' check (priority in ('Low','Normal','High','Urgent')),
  status text not null default 'Draft' check (status in ('Draft','Confirmed','Deposit Received','In Production','Quality Check','Ready','Delivered / Completed','Cancelled')),
  revenue numeric(14,2) not null default 0,
  production_cost numeric(14,2) not null default 0,
  additional_expenses numeric(14,2) not null default 0,
  amount_paid numeric(14,2) not null default 0,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id),
  description text not null,
  quantity numeric(14,2) not null default 1,
  unit_price numeric(14,2) not null default 0,
  unit_cost numeric(14,2) not null default 0,
  line_total numeric(14,2) not null default 0
);

create table if not exists public.production_jobs (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid not null references public.orders(id) on delete cascade,
  assigned_to uuid references auth.users(id),
  progress integer not null default 0 check (progress between 0 and 100),
  quality_notes text,
  updated_at timestamptz not null default now()
);

create table if not exists public.production_materials (
  id uuid primary key default uuid_generate_v4(),
  production_job_id uuid not null references public.production_jobs(id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items(id),
  planned_quantity numeric(14,2) not null default 0,
  issued_quantity numeric(14,2) not null default 0
);

create table if not exists public.expenses (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid references public.orders(id),
  expense_date date not null default current_date,
  category text not null,
  payee text,
  amount numeric(14,2) not null default 0,
  reference text,
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create table if not exists public.payments (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid references public.orders(id),
  client_id uuid not null references public.clients(id),
  payment_date date not null default current_date,
  amount numeric(14,2) not null,
  reference text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.activity_logs (
  id uuid primary key default uuid_generate_v4(),
  actor_id uuid references auth.users(id),
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create or replace view public.order_financials as
select
  o.id,
  o.job_number,
  o.client_id,
  o.status,
  o.revenue,
  o.production_cost,
  o.additional_expenses,
  (o.revenue - o.production_cost - o.additional_expenses) as gross_profit,
  case when o.revenue = 0 then 0 else ((o.revenue - o.production_cost - o.additional_expenses) / o.revenue) * 100 end as gross_margin_pct,
  o.amount_paid,
  (o.revenue - o.amount_paid) as balance_due
from public.orders o;

-- Enable RLS for backend phase.
alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.products enable row level security;
alter table public.inventory_items enable row level security;
alter table public.suppliers enable row level security;
alter table public.stock_movements enable row level security;
alter table public.quotes enable row level security;
alter table public.quote_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.production_jobs enable row level security;
alter table public.production_materials enable row level security;
alter table public.expenses enable row level security;
alter table public.payments enable row level security;
alter table public.activity_logs enable row level security;

-- Policy design intentionally left for the backend integration step.
