import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/order
import gleam/result
import gleam/set.{type Set}
import gleam/string_tree
import themis/internal/label.{type LabelSet}
import themis/internal/metric.{type Metric, type MetricName, Metric}
import themis/number.{type Number}

pub type Histogram

pub type HistogramRecord {
  HistogramRecord(count: Number, sum: Number, buckets: Dict(Number, Number))
}

pub type HistogramError {
  InvalidNaNLabel
  NumberError(number.ComparisonError)
  MetricError(metric.MetricError)
}

const blacklist = ["histogram"]

pub fn new(
  name name: String,
  description description: String,
  buckets buckets: Set(Number),
) -> Result(
  #(MetricName, Metric(Histogram, HistogramRecord, Set(Number))),
  HistogramError,
) {
  let r =
    name
    |> new_name
    |> result.try_recover(fn(e) { Error(MetricError(e)) })
  use name <- result.try(r)

  let r = {
    use key <- list.any(buckets |> set.to_list)
    // histogram bucket `le` values cannot be NaN
    key == number.NaN
  }
  use <- bool.guard(r, Error(InvalidNaNLabel))

  Ok(#(name, Metric(description, dict.new(), buckets)))
}

pub fn init_record(
  to to: Metric(Histogram, HistogramRecord, Set(Number)),
  labels labels: LabelSet,
) -> Metric(Histogram, HistogramRecord, Set(Number)) {
  let record = new_record(to)
  Metric(..to, records: dict.insert(to.records, labels, record))
}

fn new_record(
  to to: Metric(Histogram, HistogramRecord, Set(Number)),
) -> HistogramRecord {
  let keys =
    to.extra
    |> set.insert(number.PosInf)
    |> set.to_list

  let values = list.repeat(number.integer(0), list.length(keys))
  let buckets = list.zip(keys, values) |> dict.from_list
  HistogramRecord(
    count: number.integer(0),
    sum: number.integer(0),
    buckets: buckets,
  )
}

pub fn observe(
  to to: Metric(Histogram, HistogramRecord, Set(Number)),
  labels labels: LabelSet,
  observed value: Number,
) -> Metric(Histogram, HistogramRecord, Set(Number)) {
  let record = result.unwrap(dict.get(to.records, labels), new_record(to))
  let updated_buckets_list = {
    // `count` is always initialized as a number.integer(0)
    // See init_record
    use #(le, bucket_count) <- list.map(record.buckets |> dict.to_list)
    case number.compare(value, le) {
      Error(_) -> panic as "found NaN bucket boundary"
      Ok(order.Lt) | Ok(order.Eq) -> #(
        le,
        number.add(bucket_count, number.integer(1)),
      )
      Ok(order.Gt) -> #(le, bucket_count)
    }
  }

  let updated_buckets = dict.from_list(updated_buckets_list)
  let new_record =
    HistogramRecord(
      sum: number.add(record.sum, value),
      count: number.add(record.count, number.integer(1)),
      buckets: updated_buckets,
    )
  Metric(..to, records: dict.insert(to.records, labels, new_record))
}

pub fn delete_record(
  from from: Metric(Histogram, HistogramRecord, Set(Number)),
  labels labels: LabelSet,
) -> Metric(Histogram, HistogramRecord, Set(Number)) {
  Metric(..from, records: dict.delete(from.records, labels))
}

pub fn print(
  metric metric: Metric(Histogram, HistogramRecord, Set(Number)),
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
    <> number.print(record.count)
    <> "\n"
  let sum_line =
    name
    <> "_sum"
    <> label.print(labels)
    <> " "
    <> number.print(record.count)
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
    label.add_label(labels, "le", number.print(le))
    |> result.lazy_unwrap(fn() { panic as "`le` could not be added as a label" })
    |> label.print
  name <> "_bucket" <> label_string <> " " <> number.print(count) <> "\n"
}

pub fn new_name(name name: String) -> Result(MetricName, metric.MetricError) {
  name
  |> metric.new_name(blacklist)
}
