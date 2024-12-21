import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gleam/set.{type Set}
import gleam/string_tree
import internal/label.{type LabelSet}
import internal/metric.{type Metric, type MetricName, Metric}
import internal/prometheus.{type Number}

pub type Histogram

pub type HistogramRecord {
  HistogramRecord(count: Number, sum: Number, buckets: Dict(Number, Number))
}

pub type HistogramError {
  RecordNotFound
}

pub fn new(
  name name: String,
  description description: String,
) -> Result(
  #(MetricName, Metric(Histogram, HistogramRecord)),
  metric.MetricError,
) {
  todo as "histogram.new"
}

pub fn create_record(
  to to: Metric(Histogram, HistogramRecord),
  labels labels: LabelSet,
  bucket_thresholds thresholds: Set(Number),
) -> Metric(Histogram, HistogramRecord) {
  todo as "histogram.create_record"
}

pub fn measure(
  to to: Metric(Histogram, HistogramRecord),
  labels labels: LabelSet,
  measured value: Number,
) -> Result(Metric(Histogram, HistogramRecord), HistogramError) {
  todo as "histogram.measure"
}

pub fn delete_record(
  from from: Metric(Histogram, HistogramRecord),
  labels labels: LabelSet,
) -> Metric(Histogram, HistogramRecord) {
  todo as "histogram.delete_record"
}

pub fn print(
  metric metric: Metric(Histogram, HistogramRecord),
  name name: metric.MetricName,
) -> String {
  todo as "histogram.print"
}

pub fn new_name(name name: String) -> Result(MetricName, metric.MetricError) {
  todo
}
