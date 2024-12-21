import gleam/dict.{type Dict}
import gleam/list
import gleam/regexp
import gleam/result
import gleam/string
import internal/label

pub type MetricError {
  InvalidMetricName
  InvalidWordInName(word: String)
}

pub opaque type MetricName {
  MetricName(name: String)
}

pub type Metric(kind, record_type) {
  Metric(description: String, records: Dict(label.LabelSet, record_type))
}

const name_regex_pattern = "^[a-zA-Z][a-zA-Z0-9_:]*$"

pub fn is_valid_name(name: String) -> Bool {
  let assert Ok(reg) =
    name_regex_pattern
    |> regexp.from_string
  reg
  |> regexp.check(name)
}

pub fn new_name(
  from: String,
  blacklist: List(String),
) -> Result(MetricName, MetricError) {
  let r = {
    use word <- list.try_each(blacklist)
    case string.contains(from, word) {
      False -> Ok(Nil)
      True -> Error(InvalidWordInName(word))
    }
  }
  use _ <- result.try(r)
  case is_valid_name(from) {
    False -> Error(InvalidMetricName)
    True -> Ok(MetricName(from))
  }
}

pub fn name_to_string(from from: MetricName) -> String {
  from.name
}
