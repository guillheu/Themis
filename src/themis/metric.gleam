import gleam/dict.{type Dict}
import internal/prometheus
import themis/label

pub type MetricError {
  InvalidMetricName
}

pub opaque type MetricName {
  MetricName(name: String)
}

pub type Metric(kind, record_type) {
  Metric(
    name: MetricName,
    description: String,
    records: Dict(label.LabelSet, record_type),
  )
}

// pub type HistogramRecord {
//   HistogramRecord(count: Int, sum: Number, buckets: Dict(Number, Number))
// }

pub fn new_name(from: String) -> Result(MetricName, MetricError) {
  case prometheus.is_valid_name(from) {
    False -> Error(InvalidMetricName)
    True -> Ok(MetricName(from))
  }
}

pub fn name_to_string(from from: MetricName) -> String {
  from.name
}
