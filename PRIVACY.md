# Política de Privacidad

Última actualización: 2026-07-25

Esta aplicación y su versión web ("la Plataforma") son herramientas de gestión
para armerías (catálogo, ventas, stock y pedidos). Cada armería ("tenant")
opera como responsable de los datos de sus clientes; el proveedor de la
Plataforma actúa como encargado del tratamiento.

## Datos que se recolectan

- De administradores/vendedores: nombre, email, PIN (almacenado hasheado).
- De clientes finales: nombre, DNI, y opcionalmente email y teléfono, cuando la
  armería genera un comprobante o recibe un pedido web.
- Datos de operación: ventas, movimientos de stock y registro de actividad.

## Finalidad

Los datos se usan exclusivamente para operar la armería: emitir comprobantes,
controlar stock, atribuir ventas, auditar acciones y gestionar pedidos. No se
venden ni se comparten con terceros con fines publicitarios.

## Aislamiento entre armerías

Los datos de cada armería están aislados de las demás mediante autenticación por
usuario y políticas de seguridad a nivel de fila (RLS) en la base de datos. Una
armería no puede acceder a los datos de otra.

## Seguridad

- Todo el tráfico viaja cifrado por HTTPS/TLS.
- Los PIN se guardan hasheados (SHA-256), nunca en texto plano.
- El acceso a datos agregados de la plataforma está restringido al
  administrador de la plataforma mediante funciones de servidor.

## Conservación y derechos

Los datos se conservan mientras la armería mantenga su cuenta. El cliente puede
solicitar acceso, rectificación o eliminación de sus datos personales
contactando a la armería correspondiente.

## Contacto

Para consultas sobre privacidad, escribir a: soporte@tudominio.com
