begin;
alter table public.reward_transactions
  add column if not exists redemption_id uuid references public.reward_redemptions(id),
  add column if not exists reward_item_name text;
create unique index if not exists reward_transactions_redemption_idx
  on public.reward_transactions(redemption_id) where redemption_id is not null;

with matches as (
  select t.id tid, r.id rid, i.name,
    count(*) over (partition by t.id) tc,
    count(*) over (partition by r.id) rc
  from public.reward_transactions t
  join public.reward_redemptions r on r.donor_id = t.donor_id
    and r.created_at = t.created_at and r.points_spent = -t.points
  join public.reward_items i on i.id = r.reward_item_id
  where t.transaction_type = 'redeemed' and t.redemption_id is null
    and not exists (select 1 from public.reward_transactions linked where linked.redemption_id = r.id)
)
update public.reward_transactions t set redemption_id = m.rid, reward_item_name = m.name
from matches m where t.id = m.tid and m.tc = 1 and m.rc = 1;

create or replace function public.redeem_reward(p_reward_item_id uuid)
returns table (redemption_id uuid, redemption_code text, remaining_points integer)
language plpgsql security definer set search_path = public as $$
declare
  selected_item public.reward_items%rowtype;
  current_points integer;
  new_redemption_id uuid;
  new_code text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  perform 1 from public.profiles where id = auth.uid() for update;
  select * into selected_item from public.reward_items
    where id = p_reward_item_id and is_active for update;
  if not found then raise exception 'Reward is not available'; end if;
  if selected_item.stock_quantity <= 0 then raise exception 'Reward is out of stock'; end if;
  select coalesce(sum(points), 0)::integer into current_points
    from public.reward_transactions where donor_id = auth.uid();
  if current_points < selected_item.points_cost then raise exception 'Not enough reward points'; end if;
  new_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
  insert into public.reward_redemptions (donor_id, reward_item_id, points_spent, redemption_code)
    values (auth.uid(), selected_item.id, selected_item.points_cost, new_code)
    returning id into new_redemption_id;
  insert into public.reward_transactions (donor_id, points, transaction_type, redemption_id, reward_item_name)
    values (auth.uid(), -selected_item.points_cost, 'redeemed', new_redemption_id, selected_item.name);
  update public.reward_items set stock_quantity = stock_quantity - 1 where id = selected_item.id;
  return query select new_redemption_id, new_code, current_points - selected_item.points_cost;
end;
$$;
revoke all on function public.redeem_reward(uuid) from public;
grant execute on function public.redeem_reward(uuid) to authenticated;
commit;
