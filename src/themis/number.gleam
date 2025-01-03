import gleam/float
import gleam/int
import gleam/order

pub type ComparisonError {
  NaNValue
}

/// Prometheus numbers.
/// Helpful for displaying and adding/comparing values
/// of different types.
pub type Number {
  PosInf
  NegInf
  NaN
  Dec(Float)
  Int(Int)
}

/// Creates a Number representing an integer value.
pub fn integer(value value: Int) -> Number {
  Int(value)
}

/// Creates a Number representing a decimal value.
pub fn decimal(value value: Float) -> Number {
  Dec(value)
}

/// Creates a Number representing positive infinity.
pub fn positive_infinity() -> Number {
  PosInf
}

/// Creates a Number representing negative infinity.
pub fn negative_infinity() -> Number {
  NegInf
}

/// Creates a Number representing NaN (Not a Number).
pub fn not_a_number() -> Number {
  NaN
}

/// Compare two numbers (see gleam_stdlib/order)
/// Will return an error if either value is NaN
pub fn compare(
  to val1: Number,
  compare val2: Number,
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

/// Compare two numbers (see gleam_stdlib/order)
/// Will panic if either value is NaN
pub fn unsafe_compare(compare val1: Number, to val2: Number) -> order.Order {
  case compare(val1, val2) {
    Error(_) -> panic as "cannot compare NaN"
    Ok(r) -> r
  }
}

/// Add two numbers.
/// Any `NaN` input value will always return `NaN`.
/// `PosInf` + `NegInf` = `NaN`
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

/// Prometheus-scrapable representation of a number
pub fn print(number: Number) -> String {
  case number {
    Dec(val) -> float.to_string(val)
    Int(val) -> int.to_string(val)
    NaN -> "NaN"
    NegInf -> "-Inf"
    PosInf -> "+Inf"
  }
}
