
begin;

create or replace function public.redeem_reward(p_reward_item_id uuid)
returns table (
  redemption_id uuid,
  redemption_code text,
  remaining_points integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_item public.reward_items%rowtype;
  current_points integer;
  new_redemption_id uuid;
  new_code text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = auth.uid() and role::text = 'donor'
  ) then
    raise exception 'Only donor accounts can redeem rewards';
  end if;

  perform 1
  from public.profiles
  where id = auth.uid()
  for update;

  select * into selected_item
  from public.reward_items
  where id = p_reward_item_id and is_active
  for update;

  if not found then
    raise exception 'Reward is not available';
  end if;
  if selected_item.stock_quantity <= 0 then
    raise exception 'Reward is out of stock';
  end if;

  select coalesce(sum(points), 0)::integer into current_points
  from public.reward_transactions
  where donor_id = auth.uid();

  if current_points < selected_item.points_cost then
    raise exception 'Not enough reward points';
  end if;

  new_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));

  insert into public.reward_redemptions (
    donor_id,
    reward_item_id,
    points_spent,
    redemption_code
  ) values (
    auth.uid(),
    selected_item.id,
    selected_item.points_cost,
    new_code
  )
  returning id into new_redemption_id;

  insert into public.reward_transactions (
    donor_id,
    points,
    transaction_type,
    redemption_id,
    reward_item_name
  ) values (
    auth.uid(),
    -selected_item.points_cost,
    'redeemed',
    new_redemption_id,
    selected_item.name
  );

  update public.reward_items
  set stock_quantity = stock_quantity - 1
  where id = selected_item.id;

  return query select
    new_redemption_id,
    new_code,
    current_points - selected_item.points_cost;
end;
$$;

revoke all on function public.redeem_reward(uuid) from public;
grant execute on function public.redeem_reward(uuid) to authenticated;

commit;
