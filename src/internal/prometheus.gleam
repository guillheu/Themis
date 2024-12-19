import gleam/float
import gleam/int
import gleam/regexp

const name_regex_pattern = "^[a-zA-Z][a-zA-Z0-9_:]*$"

const label_regex_pattern = "^[a-zA-Z][a-zA-Z0-9_]*$"

pub type Number {
  PosInf
  NegInf
  NaN
  Dec(Float)
  Int(Int)
}

pub fn is_valid_name(name: String) -> Bool {
  let assert Ok(reg) =
    name_regex_pattern
    |> regexp.from_string
  reg
  |> regexp.check(name)
}

pub fn is_valid_label(label: String) -> Bool {
  let assert Ok(reg) =
    label_regex_pattern
    |> regexp.from_string
  reg
  |> regexp.check(label)
}

pub fn print(number: Number) -> String {
  case number {
    Dec(val) -> float.to_string(val)
    Int(val) -> int.to_string(val)
    NaN -> "NaN"
    NegInf -> "-Inf"
    PosInf -> "+Inf"
  }
}
