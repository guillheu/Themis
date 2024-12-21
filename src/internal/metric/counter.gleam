import gleam/bool
import gleam/dict
import gleam/list
import gleam/result
import gleam/string_tree
import internal/label.{type LabelSet}
import internal/metric.{type Metric, type MetricError, type MetricName, Metric}
import themis/number.{type Number, Int}

pub type Counter

pub type CounterError {
  RecordAlreadyExists
  RecordNotFound
  NameError(metric.MetricError)
}

const blacklist = ["counter"]

pub fn new(
  name name: String,
  description description: String,
) -> Result(#(MetricName, Metric(Counter, Number)), MetricError) {
  let r =
    name
    |> new_name
  use name <- result.map(r)
  #(name, Metric(description, dict.new()))
}

pub fn create_record(
  from from: Metric(Counter, Number),
  with_labels labels: LabelSet,
) -> Result(Metric(Counter, Number), CounterError) {
  use <- bool.guard(
    dict.has_key(from.records, labels),
    Error(RecordAlreadyExists),
  )
  Ok(Metric(..from, records: from.records |> dict.insert(labels, Int(0))))
}

pub fn increment(
  from from: Metric(Counter, Number),
  labels labels: LabelSet,
) -> Result(Metric(Counter, Number), CounterError) {
  increment_by(from, labels, Int(1))
}

pub fn increment_by(
  from from: Metric(Counter, Number),
  labels labels: LabelSet,
  by by: Number,
) -> Result(Metric(Counter, Number), CounterError) {
  let new_val_result = case dict.get(from.records, labels) {
    Error(_) -> Error(RecordNotFound)
    Ok(number) -> Ok(number.add(number, by))
  }
  use new_val <- result.map(new_val_result)
  Metric(..from, records: from.records |> dict.insert(labels, new_val))
}

pub fn delete_record(
  from from: Metric(Counter, Number),
  labels labels: LabelSet,
) -> Metric(Counter, Number) {
  Metric(..from, records: dict.delete(from.records, labels))
}

pub fn print(
  metric metric: Metric(Counter, Number),
  name name: metric.MetricName,
) -> String {
  let name = metric.name_to_string(name)
  let help = "# HELP " <> name <> " " <> metric.description
  let type_ = "# TYPE " <> name <> " counter"
  {
    use current, labels, value <- dict.fold(metric.records, [
      help <> "\n" <> type_ <> "\n",
    ])
    [
      name <> label.print(labels) <> " " <> number.print(value) <> "\n",
      ..current
    ]
  }
  |> list.reverse
  |> string_tree.from_strings
  |> string_tree.to_string
}

pub fn new_name(name name: String) -> Result(MetricName, metric.MetricError) {
  { name <> "_total" }
  |> metric.new_name(blacklist)
}
