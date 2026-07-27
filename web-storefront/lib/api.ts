// Cliente de la tienda web: habla con las Edge Functions publicas de Supabase.
// No usa service-role ni anon con acceso directo a tablas: todo pasa por las
// funciones storefront-catalog / storefront-order.

const BASE = process.env.NEXT_PUBLIC_SUPABASE_FUNCTIONS_URL ?? "";
const ANON = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";

export type Product = {
  id: string;
  type: string;
  marca: string;
  calibre: string;
  codigo: string;
  modelo: string;
  descripcion: string;
  precio_usd: number;
  foto_url: string;
  stock: number | null;
  rounds_per_box: number | null;
};

export type Catalog = {
  tenant: { nombre: string; slug: string };
  productos: Product[];
};

export type CartItem = { productId: string; quantity: number };

export type Customer = {
  nombre: string;
  email: string;
  telefono: string;
  dni: string;
};

function headers() {
  return {
    "Content-Type": "application/json",
    apikey: ANON,
    Authorization: `Bearer ${ANON}`,
  };
}

export async function fetchCatalog(slug: string): Promise<Catalog> {
  const res = await fetch(
    `${BASE}/storefront-catalog?slug=${encodeURIComponent(slug)}`,
    { headers: headers(), cache: "no-store" },
  );
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error ?? "No se pudo cargar la tienda");
  }
  return res.json();
}

export async function createOrder(
  slug: string,
  cliente: Customer,
  items: CartItem[],
): Promise<{ id: string; total_usd: number; estado: string }> {
  const res = await fetch(`${BASE}/storefront-order`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ slug, cliente, items }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(body.error ?? "No se pudo crear el pedido");
  return body;
}
