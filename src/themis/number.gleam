import gleam/float
import gleam/int
import gleam/order
import internal/prometheus.{type Number, Dec, Int, NaN, NegInf, PosInf}

pub type ComparisonError {
  NaNValue
}

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

/// Compare two numbers (see gleam_stdlib/order)
/// Will return an error if either value is NaN
pub fn compare(
  compare val1: Number,
  to val2: Number,
) -> Result(order.Order, ComparisonError) {
  case val1, val2 {
    v1, v2 if v1 == v2 -> Ok(order.Eq)
    Int(v1), Int(v2) -> Ok(int.compare(v1, v2))
    Dec(v1), Dec(v2) -> Ok(float.compare(v1, v2))
    PosInf, _ -> Ok(order.Gt)
    NegInf, _ -> Ok(order.Lt)
    _, PosInf -> Ok(order.Lt)
    _, NegInf -> Ok(order.Gt)
    Dec(d), Int(i) -> Ok(float.compare(d, int.to_float(i)))
    Int(i), Dec(d) -> Ok(float.compare(int.to_float(i), d))
    NaN, _ | _, NaN -> Error(NaNValue)
  }
}

pub fn add(value1 val1: Number, value2 val2: Number) -> Number {
  case val1, val2 {
    NaN, _ | _, NaN -> NaN
    Int(first), Int(second) -> Int(first + second)
    Dec(first), Dec(second) -> Dec(float.add(first, second))
    Dec(dec), Int(int) | Int(int), Dec(dec) ->
      Dec(float.add(int.to_float(int), dec))
    PosInf, NegInf | NegInf, PosInf -> NaN
    PosInf, _ | _, PosInf -> PosInf
    NegInf, _ | _, NegInf -> NegInf
  }
}
