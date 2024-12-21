import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gleam/string
import internal/label
import internal/prometheus

pub type MetricError {
  InvalidMetricName
  InvalidWordInName(word: String)
}

pub opaque type MetricName {
  MetricName(name: String)
}

pub type Metric(kind, record_type) {
  Metric(
    // name: MetricName,
    description: String,
    records: Dict(label.LabelSet, record_type),
  )
}

// pub type HistogramRecord {
//   HistogramRecord(count: Int, sum: Number, buckets: Dict(Number, Number))
// }

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
  case prometheus.is_valid_name(from) {
    False -> Error(InvalidMetricName)
    True -> Ok(MetricName(from))
  }
}

pub fn name_to_string(from from: MetricName) -> String {
  from.name
}
