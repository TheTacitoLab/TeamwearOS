-- Migration 043: brand_shopify_templates
-- Stores the list of Shopify Liquid product template suffixes available
-- per brand (e.g. "teamwear"). Products select from this list instead of
-- typing a free-text value.

create table if not exists public.brand_shopify_templates (
    id            uuid primary key default gen_random_uuid(),
    brand_id      uuid not null references public.brands(id) on delete cascade,
    template_key  text not null,
    template_name text not null,
    sort_order    integer not null default 0,
    is_active     boolean not null default true,
    created_at    timestamptz default now(),
    unique(brand_id, template_key)
);

alter table public.brand_shopify_templates enable row level security;

create policy "brand members can manage shopify templates"
    on public.brand_shopify_templates for all
    using (
        brand_id in (
            select brand_id from public.brand_members where user_id = auth.uid()
        )
    );
