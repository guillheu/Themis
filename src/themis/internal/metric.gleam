import gleam/function
import gleam/list
import gleam/regexp
import gleam/result
import gleam/string

pub type MetricError {
  InvalidMetricName(name: String)
  InvalidWordInName(word: String)
}

pub opaque type MetricName {
  MetricName(name: String)
}

// pub type Metric(
//   kind,
//   record_type,
//   //  extra
// ) {
//   Metric(
//     description: String,
//     records: Dict(label.LabelSet, record_type),
//     // extra: extra,
//   )
// }

const name_regex_pattern = "^[a-zA-Z][a-zA-Z0-9_:]*$"

const blacklisted_suffixes = ["_count", "_sum", "_bucket"]

pub fn is_valid_name(name: String) -> Bool {
  let assert Ok(reg) =
    name_regex_pattern
    |> regexp.from_string
  reg
  |> regexp.check(name)
  && list.map(blacklisted_suffixes, fn(word) { !string.ends_with(name, word) })
  |> list.all(function.identity)
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
    False -> Error(InvalidMetricName(from))
    True -> Ok(MetricName(from))
  }
}

pub fn make_histogram_metric_names(
  from: MetricName,
) -> #(MetricName, MetricName, MetricName) {
  let base_name = from.name
  #(
    MetricName(base_name <> "_bucket"),
    MetricName(base_name <> "_count"),
    MetricName(base_name <> "_sum"),
  )
}

pub fn name_to_string(from from: MetricName) -> String {
  from.name
}
