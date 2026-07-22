import '../models/product_prices.dart';

/// Forma de pago por defecto al agregar productos (el cobro real se define en el carrito).
const defaultPaymentMethod = PaymentMethod.transferencia;

/// Límites al dividir el pago en dos formas.
const dualPaymentMinShare = 0.05;
const dualPaymentMaxShare = 0.95;
