import gleam/dict
import gleam/list
import gleam/result
import gleam/string_tree
import internal/prometheus.{type Number}
import themis/label.{type LabelSet}
import themis/metric.{type Metric, type MetricError, Metric}

pub type Gauge

pub fn new(
  name name: String,
  description description: String,
) -> Result(Metric(Gauge, Number), MetricError) {
  use metric_name <- result.map(metric.new_name(name))
  Metric(metric_name, description, dict.new())
}

pub fn add_record(
  to to: Metric(Gauge, Number),
  labels labels: LabelSet,
  value value: Number,
) -> Metric(Gauge, Number) {
  Metric(..to, records: dict.insert(to.records, labels, value))
}

pub fn delete_record(
  from from: Metric(Gauge, Number),
  labels labels: LabelSet,
) -> Metric(Gauge, Number) {
  Metric(..from, records: dict.delete(from.records, labels))
}

pub fn print(metric metric: Metric(Gauge, Number)) -> String {
  let name = metric.name_to_string(metric.name)
  let help = "HELP " <> name <> " " <> metric.description
  let type_ = "TYPE " <> name <> " gauge"
  {
    use current, labels, value <- dict.fold(metric.records, [
      help <> "\n" <> type_ <> "\n",
    ])
    [
      name <> label.print(labels) <> " " <> prometheus.print(value) <> "\n",
      ..current
    ]
  }
  |> list.reverse
  |> string_tree.from_strings
  |> string_tree.to_string
}
