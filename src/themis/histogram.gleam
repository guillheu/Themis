import gleam/bool
import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/string_tree
import themis/internal/label.{type LabelSet}
import themis/internal/metric
import themis/internal/store
import themis/number.{type Number}

pub type HistogramError {
  MetricError(metric.MetricError)
  StoreError(store.StoreError)
  InvalidBucketValue
  CannotObserveNaN
  LabelError(label.LabelError)
}

const blacklist = ["histogram"]

pub fn new(
  store store: store.Store,
  name name: String,
  description description: String,
  buckets buckets: Set(Number),
) -> Result(Nil, HistogramError) {
  // Create a new metadata entry.
  // Return an error if the name is incorrect or already taken.
  // If it worked, return a MetricName which is the only way to
  // use `observe`, ensuring all metrics which are `observe`d on
  // have properly been inserted.

  case metric.new_name(name, blacklist) {
    Error(e) -> Error(MetricError(e))
    Ok(metric_name) -> {
      use buckets <- result.try(buckets |> buckets_to_list_float)
      case
        store.new_metric(store, metric_name, description, "histogram", buckets)
      {
        Error(e) -> Error(StoreError(e))
        Ok(_) -> Ok(Nil)
      }
    }
  }
}

pub fn observe(
  store store: store.Store,
  name name: String,
  labels labels: Dict(String, String),
  value value: Number,
) -> Result(Nil, HistogramError) {
  use <- bool.guard(value == number.NaN, Error(CannotObserveNaN))
  use name <- result.try(
    metric.new_name(name, blacklist)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )

  use labels <- result.try(
    label.from_dict(labels) |> result.map_error(fn(e) { LabelError(e) }),
  )
  let #(_description, _kind, buckets) = store.find_metric(store, name)
  // [
  //   "+Inf",
  //   "1",
  //   "0.1",
  //   "0.01",
  // ]
  // sorted, reversed
  let le_labels = buckets_floats_to_numbers(buckets)
  let #(bucket_name, count_name, sum_name) =
    metric.make_histogram_metric_names(name)

  // see if the record with le=+Inf exists
  // if not, assume no record was created for this histogram
  // create them all by incrementing all buckets, counts and sums by integer(0)

  let assert Ok(posinf_labels) =
    labels |> label.to_dict |> dict.insert("le", "+Inf") |> label.from_dict
  // When looping through all buckets with fold_until, if this variable is true,
  // will set all non-matching buckets to 0 to initialize them.
  let must_initialize_records =
    store.find_record(store, bucket_name, posinf_labels) |> result.is_error

  list.fold_until(le_labels, Nil, fn(_, bucket) {
    let value_belongs_to_bucket =
      number.unsafe_compare(value, bucket) != order.Gt
    let #(stop, by) = case value_belongs_to_bucket, must_initialize_records {
      True, _ -> #(False, number.integer(1))
      False, False -> #(True, number.integer(1))
      False, True -> #(False, number.integer(0))
    }
    use <- bool.guard(stop, list.Stop(Nil))

    let labels = case
      {
        dict.insert(labels |> label.to_dict, "le", bucket |> number.print)
        |> label.from_dict
      }
    {
      Error(_) ->
        panic as "rebuilding labels after only adding the \"le\" label should work"
      Ok(labels) -> labels
    }
    case store.increment_record_by(store, bucket_name, labels, by) {
      Error(e) ->
        panic as {
          "failed to increment a bucket record : \nName: "
          <> bucket_name |> metric.name_to_string
          <> "\nError: "
          <> string.inspect(e)
        }
      Ok(_) -> list.Continue(Nil)
    }
  })

  case store.increment_record(store, count_name, labels) {
    Error(e) ->
      panic as {
        "failed to increment a count record : \nName: "
        <> count_name |> metric.name_to_string
        <> "\nError: "
        <> string.inspect(e)
      }
    Ok(_) -> Nil
  }

  case store.increment_record_by(store, sum_name, labels, value) {
    Error(e) ->
      panic as {
        "failed to increment a sum record : \nName: "
        <> sum_name |> metric.name_to_string
        <> "\nError: "
        <> string.inspect(e)
      }
    Ok(_) -> Nil
  }

  Ok(Nil)
}

pub fn print_all(store store: store.Store) -> Result(String, HistogramError) {
  use metrics <- result.try(
    store.match_metrics(store, "histogram")
    |> result.try_recover(fn(e) { Error(StoreError(e)) }),
  )
  let r = {
    use metrics_strings, #(name_string, description, _buckets) <- list.try_fold(
      metrics,
      [],
    )
    use name <- result.try(
      metric.new_name(name_string, blacklist)
      |> result.try_recover(fn(e) { Error(MetricError(e)) }),
    )

    let #(buckets_name, count_name, sum_name) =
      metric.make_histogram_metric_names(name)
    use bucket_records <- result.try(
      store.match_records(store, buckets_name)
      |> result.try_recover(fn(e) { Error(StoreError(e)) }),
    )
    use sum_records <- result.try(
      store.match_records(store, sum_name)
      |> result.try_recover(fn(e) { Error(StoreError(e)) }),
    )
    use count_records <- result.try(
      store.match_records(store, count_name)
      |> result.try_recover(fn(e) { Error(StoreError(e)) }),
    )

    let records =
      group_histogram_records(bucket_records, sum_records, count_records)

    // Print all dis shit like we did before. ez. simple. simple.

    let help_string = "# HELP " <> name_string <> " " <> description <> "\n"
    let type_string = "# TYPE " <> name_string <> " " <> "histogram\n"
    let records_strings = {
      use lines, #(labels, #(buckets, sum, count)) <- list.fold(
        dict.to_list(records),
        [],
      )
      let sum_line =
        { sum_name |> metric.name_to_string }
        <> label.print(labels)
        <> " "
        <> number.print(sum)
        <> "\n"
      let count_line =
        { count_name |> metric.name_to_string }
        <> label.print(labels)
        <> " "
        <> number.print(count)
        <> "\n"
      let bucket_lines = {
        use #(bucket_label, bucket_value) <- list.map(dict.to_list(buckets))
        let bucket_labels =
          label.add_label(labels, "le", bucket_label)
          |> result.lazy_unwrap(fn() {
            panic as {
              "bucket label should be `le` and should not throw an error"
            }
          })
        { buckets_name |> metric.name_to_string }
        <> label.print(bucket_labels)
        <> " "
        <> number.print(bucket_value)
        <> "\n"
      }
      ["\n", count_line, sum_line, ..bucket_lines] |> list.append(lines)
    }

    Ok([
      "\n",
      type_string,
      help_string,
      ..list.append(records_strings, metrics_strings)
    ])
  }
  use metrics_strings <- result.map(r)
  metrics_strings
  // |> list.reverse
  |> string_tree.from_strings
  |> string_tree.to_string
}

// Fetching all the buckets, sums and counts from a metric name is easy
// But reconstricting all record (set of buckets, a sum, a count) for
// that metric is hard.
// A "record" is essentially a Dict(labels, (record data))
// for simpler metrics like gauge or counter, (record data) is just a single number.
// But here, (record data) is : buckets, sum, count.
// buckets: Dict(le,value) -> with `le` standing for "lesser equal". Sometimes it's a label, sometimes it's a string, sometimes it's a number.
// sum: value
// count: value
// The records
fn group_histogram_records(
  buckets: Dict(LabelSet, Number),
  sum: Dict(LabelSet, Number),
  count: Dict(LabelSet, Number),
  // Dict of labels, value = #(buckets, sum, count)
) -> Dict(LabelSet, #(Dict(String, Number), Number, Number)) {
  // 1: extract LE labels from buckets: Dict(LabelSet, Dict(String, Number))
  buckets
  |> dict.to_list
  use result, bucket_entry <- list.fold(buckets |> dict.to_list(), dict.new())
  let #(bucket_labels, bucket_value) = bucket_entry
  let #(le_value, bucket_labels) =
    label.to_dict(bucket_labels)
    |> dict.to_list
    |> list.key_pop("le")
    |> result.lazy_unwrap(fn() {
      panic as "could not find label `le` for bucket"
    })
  // TODO: might have to convert the le_value to number.Number,
  // to properly sort the `le` values later, just to turn them back
  // into strings later.
  let labels =
    bucket_labels
    |> dict.from_list
    |> label.from_dict
    |> result.lazy_unwrap(fn() {
      panic as "failed to recombine bucket labels after extracting le label"
    })
  let #(found_buckets, found_sum, found_count) = case dict.get(result, labels) {
    Error(_) -> {
      let record_sum_value =
        dict.get(sum, labels)
        |> result.lazy_unwrap(fn() {
          panic as "recombined bucket labels did not match any found sum record"
        })
      let record_count_value =
        dict.get(count, labels)
        |> result.lazy_unwrap(fn() {
          panic as "recombined bucket labels did not match any found count record"
        })
      #(dict.new(), record_sum_value, record_count_value)
    }
    Ok(record) -> record
  }
  let new_buckets = dict.insert(found_buckets, le_value, bucket_value)
  dict.insert(result, labels, #(new_buckets, found_sum, found_count))
}

fn buckets_to_list_float(
  buckets: Set(Number),
) -> Result(List(Float), HistogramError) {
  {
    use bucket <- list.map(buckets |> set.to_list)
    case bucket {
      number.Dec(val) -> Ok(val)
      number.Int(val) -> Ok(int.to_float(val))
      number.NaN | number.PosInf | number.NegInf -> Error(InvalidBucketValue)
    }
  }
  |> result.all
}

fn buckets_floats_to_numbers(buckets: List(Float)) -> List(Number) {
  list.map(buckets, fn(bucket) {
    let assert Ok(bucket_decimal) = float.modulo(bucket, 1.0)
    case bucket_decimal == 0.0 {
      False -> number.decimal(bucket)
      True -> number.integer(bucket |> float.truncate)
    }
  })
  |> list.append([number.positive_infinity()])
  |> list.sort(number.unsafe_compare)
  |> list.reverse
}
