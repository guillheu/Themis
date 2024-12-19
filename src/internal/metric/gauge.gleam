import gleam/dict
import gleam/list
import gleam/string_tree
import internal/label.{type LabelSet}
import internal/metric.{type Metric, Metric}
import internal/prometheus.{type Number}

pub type Gauge

pub fn new(description description: String) -> Metric(Gauge, Number) {
  Metric(description, dict.new())
}

pub fn insert_record(
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

pub fn print(
  metric metric: Metric(Gauge, Number),
  name name: metric.MetricName,
) -> String {
  let name = metric.name_to_string(name)
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
