import gleam/dict
import gleam/list
import gleam/result
import gleam/string_tree
import themis/internal/label.{type LabelSet}
import themis/internal/metric.{type Metric, type MetricName, Metric}
import themis/number.{type Number}

pub type Gauge

pub type GaugeError {
  NameError(metric.MetricError)
}

const blacklist = ["gauge"]

pub fn new(
  name name: String,
  description description: String,
) -> Result(#(MetricName, Metric(Gauge, Number, Nil)), metric.MetricError) {
  use name <- result.map(new_name(name))
  #(name, Metric(description, dict.new(), Nil))
}

pub fn observe(
  to to: Metric(Gauge, Number, Nil),
  labels labels: LabelSet,
  value value: Number,
) -> Metric(Gauge, Number, Nil) {
  Metric(..to, records: dict.insert(to.records, labels, value))
}

pub fn delete_record(
  from from: Metric(Gauge, Number, Nil),
  labels labels: LabelSet,
) -> Metric(Gauge, Number, Nil) {
  Metric(..from, records: dict.delete(from.records, labels))
}

pub fn print(
  metric metric: Metric(Gauge, Number, Nil),
  name name: metric.MetricName,
) -> String {
  let name = metric.name_to_string(name)
  let help = "# HELP " <> name <> " " <> metric.description
  let type_ = "# TYPE " <> name <> " gauge"
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
  name
  |> metric.new_name(blacklist)
  // |> result.try_recover(fn(e) { Error(NameError(e)) })
}
