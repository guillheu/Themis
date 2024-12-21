import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/order
import gleam/result
import gleam/set.{type Set}
import gleam/string_tree
import internal/label.{type LabelSet}
import internal/metric.{type Metric, type MetricName, Metric}
import internal/prometheus.{type Number}
import themis/number

pub type Histogram

pub type HistogramRecord {
  HistogramRecord(count: Number, sum: Number, buckets: Dict(Number, Number))
}

pub type HistogramError {
  RecordNotFound
  InvalidNaNLabel
  NumberError(number.ComparisonError)
}

const blacklist = ["histogram"]

pub fn new(
  name name: String,
  description description: String,
) -> Result(
  #(MetricName, Metric(Histogram, HistogramRecord)),
  metric.MetricError,
) {
  let r =
    name
    |> new_name
  use name <- result.map(r)
  #(name, Metric(description, dict.new()))
}

pub fn create_record(
  to to: Metric(Histogram, HistogramRecord),
  labels labels: LabelSet,
  bucket_thresholds thresholds: Set(Number),
) -> Result(Metric(Histogram, HistogramRecord), HistogramError) {
  let keys =
    thresholds
    |> set.insert(prometheus.PosInf)
    |> set.to_list
  let r = {
    use key <- list.any(keys)
    // histogram bucket `le` values cannot be NaN
    key == prometheus.NaN
  }
  use <- bool.guard(r, Error(InvalidNaNLabel))
  let values = list.repeat(number.int(0), list.length(keys))
  let buckets = list.zip(keys, values) |> dict.from_list
  let record =
    HistogramRecord(count: number.int(0), sum: number.int(0), buckets: buckets)
  Ok(Metric(..to, records: dict.insert(to.records, labels, record)))
}

pub fn measure(
  to to: Metric(Histogram, HistogramRecord),
  labels labels: LabelSet,
  measured value: Number,
) -> Result(Metric(Histogram, HistogramRecord), HistogramError) {
  use record <- result.try(
    dict.get(to.records, labels) |> result.replace_error(RecordNotFound),
  )
  let r = {
    // `count` is always initialized as a number.int(0)
    // See create_record
    use #(le, bucket_count) <- list.try_map(record.buckets |> dict.to_list)
    case number.compare(value, le) {
      Error(e) -> Error(NumberError(e))
      Ok(order.Lt) | Ok(order.Eq) ->
        Ok(#(le, number.add(bucket_count, number.int(1))))
      Ok(order.Gt) -> Ok(#(le, bucket_count))
    }
  }
  use new_record_list <- result.map(r)
  let new_record_buckets = dict.from_list(new_record_list)
  let new_record =
    HistogramRecord(
      sum: number.add(record.sum, value),
      count: number.add(record.count, number.int(1)),
      buckets: new_record_buckets,
    )
  Metric(..to, records: dict.insert(to.records, labels, new_record))
}

pub fn delete_record(
  from from: Metric(Histogram, HistogramRecord),
  labels labels: LabelSet,
) -> Metric(Histogram, HistogramRecord) {
  Metric(..from, records: dict.delete(from.records, labels))
}

pub fn print(
  metric metric: Metric(Histogram, HistogramRecord),
  name name: metric.MetricName,
) -> String {
  let name = metric.name_to_string(name)
  let help = "# HELP " <> name <> " " <> metric.description
  let type_ = "# TYPE " <> name <> " histogram"
  {
    use current, labels, record <- dict.fold(metric.records, [
      help <> "\n" <> type_ <> "\n",
    ])
    [print_histogram_record(name, labels, record) <> "\n", ..current]
  }
  |> list.reverse
  |> string_tree.from_strings
  |> string_tree.to_string
}

fn print_histogram_record(
  name: String,
  labels: LabelSet,
  record: HistogramRecord,
) -> String {
  let count_line =
    name
    <> "_count"
    <> label.print(labels)
    <> " "
    <> prometheus.print(record.count)
    <> "\n"
  let sum_line =
    name
    <> "_sum"
    <> label.print(labels)
    <> " "
    <> prometheus.print(record.count)
    <> "\n"
  let bucket_lines =
    record.buckets
    |> dict.to_list
    |> list.sort(fn(bucket1, bucket2) {
      let #(le1, _) = bucket1
      let #(le2, _) = bucket2
      result.lazy_unwrap(number.compare(le1, le2), fn() {
        panic as "`le` values comparison failed, one of them is NaN"
      })
    })
    |> list.map(fn(bucket) {
      let #(le, count) = bucket
      print_bucket(name, labels, le, count)
    })
  list.append(bucket_lines, [sum_line, count_line])
  |> string_tree.from_strings
  |> string_tree.to_string
}

fn print_bucket(
  name: String,
  labels: LabelSet,
  le: Number,
  count: Number,
) -> String {
  let label_string =
    label.add_label(labels, "le", prometheus.print(le))
    |> result.lazy_unwrap(fn() { panic as "`le` could not be added as a label" })
    |> label.print
  name <> "_bucket" <> label_string <> " " <> prometheus.print(count) <> "\n"
}

pub fn new_name(name name: String) -> Result(MetricName, metric.MetricError) {
  name
  |> metric.new_name(blacklist)
}
