import gleam/regexp

const name_regex_pattern = "^[a-zA-Z][a-zA-Z0-9_:]*$"

const label_regex_pattern = "^[a-zA-Z][a-zA-Z0-9_]*$"

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
