-- =====================================================================
-- 050_wg_transferencia_como_efectivo.sql
-- ---------------------------------------------------------------------
-- World Guns: transferencia = mismo % que efectivo (tenant-wide).
-- Restaura pricing_settings (se había perdido el bloque municion).
-- =====================================================================

begin;

create or replace function public._sale_unit_ars(
  p_unit_usd numeric,
  p_rate numeric,
  p_method text,
  p_pricing jsonb,
  p_product_type text default null,
  p_calibre text default null,
  p_descripcion text default null
) returns numeric
language plpgsql
stable
as $$
declare
  v_lista numeric;
  v_efectivo numeric;
  v_debito numeric;
  v_t1 numeric;
  v_t3 numeric;
  v_t6 numeric;
  v_t9 numeric;
  v_t12 numeric;
  v_t18 numeric;
  v_src jsonb;
  v_mun jsonb;
  v_transfer_efectivo boolean := false;
  v_t3_solo_larga boolean := false;
  v_method text;
  v_is_municion boolean;
begin
  v_lista := p_unit_usd * p_rate;
  v_src := coalesce(p_pricing, '{}'::jsonb);
  v_is_municion := lower(coalesce(nullif(trim(p_product_type), ''), '')) = 'municion';
  v_mun := case
    when v_is_municion and jsonb_typeof(v_src->'municion') = 'object'
      then v_src->'municion'
    else null
  end;

  -- Tenant-wide (World Guns) o override munición.
  v_transfer_efectivo := coalesce(
    (v_src->>'transferencia_como_efectivo')::boolean,
    false
  );

  if v_mun is not null then
    v_efectivo := public._sale_clamp_pct(
      coalesce((v_mun->>'efectivo')::numeric, (v_src->>'efectivo')::numeric),
      5, 0, 30
    );
    if not v_transfer_efectivo then
      v_transfer_efectivo := coalesce(
        (v_mun->>'transferencia_como_efectivo')::boolean,
        false
      );
    end if;
    v_t3_solo_larga := coalesce(
      (v_mun->>'tarjeta3_solo_arma_larga')::boolean,
      true
    );
    if v_t3_solo_larga
       and not public._is_municion_arma_larga(p_calibre, p_descripcion) then
      v_t3 := public._sale_clamp_pct((v_src->>'tarjeta3')::numeric, 15, 0, 100);
    else
      v_t3 := public._sale_clamp_pct(
        coalesce((v_mun->>'tarjeta3')::numeric, (v_src->>'tarjeta3')::numeric),
        15, 0, 100
      );
    end if;
  else
    v_efectivo := public._sale_clamp_pct((v_src->>'efectivo')::numeric, 5, 0, 30);
    v_t3 := public._sale_clamp_pct((v_src->>'tarjeta3')::numeric, 15, 0, 100);
  end if;

  v_debito := public._sale_clamp_pct((v_src->>'debito')::numeric, 5, 0, 100);
  v_t1 := public._sale_clamp_pct((v_src->>'tarjeta1')::numeric, 10, 0, 100);
  v_t6 := public._sale_clamp_pct((v_src->>'tarjeta6')::numeric, 20, 0, 100);
  v_t9 := public._sale_clamp_pct((v_src->>'tarjeta9')::numeric, 30, 0, 100);
  v_t12 := public._sale_clamp_pct((v_src->>'tarjeta12')::numeric, 35, 0, 100);
  v_t18 := public._sale_clamp_pct((v_src->>'tarjeta18')::numeric, 45, 0, 100);

  v_method := coalesce(nullif(trim(p_method), ''), 'lista');

  return case v_method
    when 'efectivo' then v_lista * (1 - v_efectivo / 100)
    when 'dolar_billete' then v_lista * (1 - v_efectivo / 100)
    when 'transferencia' then
      case
        when v_transfer_efectivo then v_lista * (1 - v_efectivo / 100)
        else v_lista
      end
    when 'debito' then v_lista * (1 + v_debito / 100)
    when 'tarjeta1' then v_lista * (1 + v_t1 / 100)
    when 'tarjeta3' then v_lista * (1 + v_t3 / 100)
    when 'tarjeta6' then v_lista * (1 + v_t6 / 100)
    when 'tarjeta9' then v_lista * (1 + v_t9 / 100)
    when 'tarjeta12' then v_lista * (1 + v_t12 / 100)
    when 'tarjeta18' then v_lista * (1 + v_t18 / 100)
    else v_lista
  end;
end;
$$;

revoke all on function public._sale_unit_ars(numeric, numeric, text, jsonb, text, text, text)
  from public, anon, authenticated;

-- Restaura promos World Guns (bloque munición + transferencia=efectivo).
update public.app_config ac
   set pricing_settings = jsonb_build_object(
         'efectivo', 5,
         'debito', 5,
         'tarjeta1', 10,
         'tarjeta3', 15,
         'tarjeta6', 20,
         'tarjeta9', 30,
         'tarjeta12', 35,
         'tarjeta18', 45,
         'transferencia_como_efectivo', true,
         'municion', jsonb_build_object(
           'efectivo', 10,
           'tarjeta3', 0,
           'transferencia_como_efectivo', true,
           'tarjeta3_solo_arma_larga', true
         )
       ),
       updated_at = timezone('utc', now())
  from public.tenants t
 where ac.tenant_id = t.id
   and ac.id = 'global'
   and (
     lower(replace(t.slug, '_', '-')) = 'world-guns'
     or lower(replace(t.slug, '_', '-')) = 'worldguns'
   );

commit;
