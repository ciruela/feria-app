-- Datos iniciales de vendedores (ejecutar después de schema.sql)
insert into public.vendedores (id, nombre, activo) values
  ('v1', 'Agustín', true),
  ('v2', 'Carlos', true),
  ('v3', 'Diego', true),
  ('v4', 'Eduardo', true),
  ('v5', 'Fernando', true),
  ('v6', 'Gabriel', true),
  ('v7', 'Hernán', true),
  ('v8', 'Jorge', true),
  ('v9', 'Lucas', true),
  ('v10', 'Marcos', true),
  ('v11', 'Martín', true),
  ('v12', 'Pablo', true),
  ('v13', 'Ricardo', true),
  ('v14', 'Roberto', true),
  ('v15', 'Sebastián', true)
on conflict (id) do nothing;

-- Para cargar productos iniciales: usá "Publicar catálogo a Supabase"
-- desde el panel admin con la app sin credenciales, o importá el JSON manualmente.
