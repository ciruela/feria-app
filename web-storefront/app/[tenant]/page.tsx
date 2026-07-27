"use client";

import { useEffect, useMemo, useState } from "react";
import {
  createOrder,
  fetchCatalog,
  type Catalog,
  type Customer,
  type Product,
} from "@/lib/api";

export default function TenantStore({
  params,
}: {
  params: { tenant: string };
}) {
  const slug = params.tenant;
  const [catalog, setCatalog] = useState<Catalog | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [cart, setCart] = useState<Record<string, number>>({});
  const [checkout, setCheckout] = useState(false);

  useEffect(() => {
    fetchCatalog(slug).then(setCatalog).catch((e) => setError(e.message));
  }, [slug]);

  const items = useMemo(
    () =>
      Object.entries(cart)
        .filter(([, q]) => q > 0)
        .map(([productId, quantity]) => ({ productId, quantity })),
    [cart],
  );

  const total = useMemo(() => {
    if (!catalog) return 0;
    const byId = new Map(catalog.productos.map((p) => [p.id, p]));
    return items.reduce(
      (sum, i) => sum + (byId.get(i.productId)?.precio_usd ?? 0) * i.quantity,
      0,
    );
  }, [items, catalog]);

  const count = items.reduce((s, i) => s + i.quantity, 0);

  if (error) {
    return (
      <div className="container">
        <h1 className="header">Tienda no disponible</h1>
        <p className="muted">{error}</p>
      </div>
    );
  }
  if (!catalog) {
    return (
      <div className="container">
        <p className="muted">Cargando...</p>
      </div>
    );
  }

  if (checkout) {
    return (
      <CheckoutForm
        slug={slug}
        items={items}
        total={total}
        onBack={() => setCheckout(false)}
      />
    );
  }

  const add = (p: Product) =>
    setCart((c) => ({ ...c, [p.id]: (c[p.id] ?? 0) + 1 }));
  const remove = (p: Product) =>
    setCart((c) => ({ ...c, [p.id]: Math.max(0, (c[p.id] ?? 0) - 1) }));

  return (
    <div className="container">
      <h1 className="header">{catalog.tenant.nombre}</h1>
      <div className="grid">
        {catalog.productos.map((p) => (
          <div key={p.id} className="card">
            {p.foto_url ? <img src={p.foto_url} alt={p.modelo} /> : null}
            <strong>
              {p.marca} {p.modelo}
            </strong>
            <span className="muted">
              {p.calibre} {p.codigo ? `· ${p.codigo}` : ""}
            </span>
            <span className="price">USD {p.precio_usd.toFixed(0)}</span>
            <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <button onClick={() => remove(p)}>-</button>
              <span>{cart[p.id] ?? 0}</span>
              <button className="btn-accent" onClick={() => add(p)}>
                +
              </button>
            </div>
          </div>
        ))}
      </div>

      {count > 0 ? (
        <div className="cart-bar">
          <span>
            {count} ítem(s) · <strong>USD {total.toFixed(0)}</strong>
          </span>
          <button className="btn-primary" onClick={() => setCheckout(true)}>
            Continuar
          </button>
        </div>
      ) : null}
    </div>
  );
}

function CheckoutForm({
  slug,
  items,
  total,
  onBack,
}: {
  slug: string;
  items: { productId: string; quantity: number }[];
  total: number;
  onBack: () => void;
}) {
  const [cliente, setCliente] = useState<Customer>({
    nombre: "",
    email: "",
    telefono: "",
    dni: "",
  });
  const [done, setDone] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const submit = async () => {
    setBusy(true);
    setErr(null);
    try {
      const res = await createOrder(slug, cliente, items);
      setDone(res.id);
    } catch (e) {
      setErr((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  if (done) {
    return (
      <div className="container">
        <h1 className="header">¡Pedido recibido!</h1>
        <p className="muted">
          Nº {done}. La armería se contactará para coordinar el pago y el retiro.
          La entrega de armas/munición requiere validación presencial de tus
          credenciales (ANMaC).
        </p>
      </div>
    );
  }

  return (
    <div className="container">
      <button onClick={onBack}>← Volver</button>
      <h1 className="header">Tus datos</h1>
      <p className="muted">Total: USD {total.toFixed(0)}</p>
      <input
        placeholder="Nombre y apellido"
        value={cliente.nombre}
        onChange={(e) => setCliente({ ...cliente, nombre: e.target.value })}
      />
      <input
        placeholder="Email"
        value={cliente.email}
        onChange={(e) => setCliente({ ...cliente, email: e.target.value })}
      />
      <input
        placeholder="Teléfono"
        value={cliente.telefono}
        onChange={(e) => setCliente({ ...cliente, telefono: e.target.value })}
      />
      <input
        placeholder="DNI"
        value={cliente.dni}
        onChange={(e) => setCliente({ ...cliente, dni: e.target.value })}
      />
      {err ? <p style={{ color: "#c0392b" }}>{err}</p> : null}
      <div style={{ marginTop: 16 }}>
        <button
          className="btn-primary"
          disabled={busy || !cliente.nombre}
          onClick={submit}
        >
          {busy ? "Enviando..." : "Confirmar pedido"}
        </button>
      </div>
    </div>
  );
}
