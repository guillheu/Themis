import gleam/dict
import gleam/list
import gleam/result
import gleam/string_tree
import themis/internal/label.{type LabelSet}
import themis/internal/metric.{
  type Metric, type MetricError, type MetricName, Metric,
}
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
) -> Result(#(MetricName, Metric(Counter, Number, Nil)), MetricError) {
  let r =
    name
    |> new_name
  use name <- result.map(r)
  #(name, Metric(description, dict.new(), Nil))
}

pub fn init_record(
  from from: Metric(Counter, Number, Nil),
  with_labels labels: LabelSet,
) -> Metric(Counter, Number, Nil) {
  Metric(..from, records: from.records |> dict.insert(labels, Int(0)))
}

pub fn increment(
  from from: Metric(Counter, Number, Nil),
  labels labels: LabelSet,
) -> Metric(Counter, Number, Nil) {
  increment_by(from, labels, Int(1))
}

pub fn increment_by(
  from from: Metric(Counter, Number, Nil),
  labels labels: LabelSet,
  by by: Number,
) -> Metric(Counter, Number, Nil) {
  let new_val =
    dict.get(from.records, labels)
    |> result.unwrap(number.integer(0))
    |> number.add(by)
  Metric(..from, records: from.records |> dict.insert(labels, new_val))
}

pub fn delete_record(
  from from: Metric(Counter, Number, Nil),
  labels labels: LabelSet,
) -> Metric(Counter, Number, Nil) {
  Metric(..from, records: dict.delete(from.records, labels))
}

pub fn print(
  metric metric: Metric(Counter, Number, Nil),
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
