import gleam/dict.{type Dict}
import gleam/list
import gleam/regexp
import gleam/result
import gleam/string
import gleam/string_tree

pub opaque type LabelName {
  LabelName(name: String)
}

pub opaque type LabelSet {
  LabelSet(labels: Dict(LabelName, String))
}

pub type LabelError {
  InvalidLabelName
}

const label_regex_pattern = "^[a-zA-Z][a-zA-Z0-9_]*$"

pub fn is_valid_label(label: String) -> Bool {
  let assert Ok(reg) =
    label_regex_pattern
    |> regexp.from_string
  reg
  |> regexp.check(label)
}

pub fn from_dict(
  labels labels: Dict(String, String),
) -> Result(LabelSet, LabelError) {
  let r = {
    use #(name_string, value) <- list.try_map(dict.to_list(labels))
    use name <- result.try(new_label_name(name_string))
    Ok(#(name, value))
  }
  use checked_dict <- result.map(r)
  LabelSet(dict.from_list(checked_dict))
}

pub fn new() -> LabelSet {
  LabelSet(dict.new())
}

pub fn add_label(
  labels labels: LabelSet,
  new_label key: String,
  new_label_value value: String,
) -> Result(LabelSet, LabelError) {
  use label_name <- result.map(new_label_name(key))
  LabelSet(dict.insert(labels.labels, label_name, value))
}

pub fn delete_label(
  labels labels: LabelSet,
  label_to_remove key: String,
) -> Result(LabelSet, LabelError) {
  use label_name <- result.map(new_label_name(key))
  LabelSet(dict.delete(labels.labels, label_name))
}

pub fn print(labels labels: LabelSet) -> String {
  {
    use current, name, value <- dict.fold(labels.labels, ["{"])
    [name.name <> "=\"" <> value <> "\",", ..current]
  }
  |> list.reverse
  |> string_tree.from_strings
  |> string_tree.to_string
  |> string.drop_end(1)
  |> string.append("}")
}

fn new_label_name(from: String) -> Result(LabelName, LabelError) {
  case is_valid_label(from) {
    False -> Error(InvalidLabelName)
    True -> Ok(LabelName(from))
  }
}
