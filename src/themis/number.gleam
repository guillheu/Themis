import internal/prometheus.{type Number}

/// Creates a Number representing an integer value.
pub fn int(value value: Int) -> Number {
  prometheus.Int(value)
}

/// Creates a Number representing a decimal value.
pub fn dec(value value: Float) -> Number {
  prometheus.Dec(value)
}

/// Creates a Number representing positive infinity.
pub fn pos_inf() -> Number {
  prometheus.PosInf
}

/// Creates a Number representing negative infinity.
pub fn neg_inf() -> Number {
  prometheus.NegInf
}

/// Creates a Number representing NaN (Not a Number).
pub fn nan() -> Number {
  prometheus.NaN
}
