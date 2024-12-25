import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/result
import gleam/set.{type Set}
import gleam/string
import themis/internal/label.{type LabelSet}
import themis/internal/metric.{type MetricName}
import themis/internal/store
import themis/number.{type Number}

pub type HistogramError {
  MetricError(metric.MetricError)
  StoreError(store.StoreError)
  InvalidBucketValue
  CannotObserveNaN
}

const blacklist = ["histogram"]

pub fn new(
  store: store.Store,
  name: String,
  description: String,
  buckets: Set(Number),
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
  labels labels: LabelSet,
  value value: Number,
) -> Result(Nil, HistogramError) {
  use <- bool.guard(value == number.NaN, Error(CannotObserveNaN))
  // Observe a new record.
  // Lookup the metric metadata, retrieve the bucket definitions
  // Should increment all necessary buckets by 1
  // as well as count
  // and add to the sum.
  // values can not be +Inf, -Inf or NaN.
  // ets:counter_update for all selected buckets and count
  // ets:select_replace for sum because it can be decimal

  // DON'T FORGET TO ADD THE DEFAULT +INF BUCKET!!!

  use name <- result.try(
    metric.new_name(name, blacklist)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )

  let #(_description, _kind, buckets) = store.find_metric(store, name)
  // [
  //   "+Inf",
  //   "1",
  //   "0.1",
  //   "0.01",
  // ]
  // sorted, reversed
  let le_labels =
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

pub fn print_all(store store: store.Store) -> String {
  // lookup all histogram metrics metadata.
  //        The suffixes ARE included in the metric names stored in the table, and should be looked up manually:
  //        get all histogram names with `ets:match({'$1', '$2', 'Histogram', '$3'})
  //            -> $1 = metric name
  //            -> $2 = description
  //            -> $3 = buckets declaration
  //        then get all necessary records: $1_bucket, $1_count, $1_sum:
  // Loop through all found metric names...
  // ======================================================
  // get all buckets with ets:match({{name, '$1'}, '$2', '$3', HistogramBucket})
  //            -> $1 = metric name (with suffix)
  //            -> $2 = label set
  //            -> $3 = INT value (all that should matter for buckets)
  //            -> $4 = Float value (should be 0.0 for buckets)
  // get all sums with ets:match({{name, '$2'}, '$3', '$4', HistogramSum})
  // get all counts with ets:match({{name, '$2'}, '$3', '$4', HistogramCount})
  // At this point we should have variables like this:
  //        -> base_name: MetricName
  //        -> sums: List(#(LabelSet, value: Int & Float))
  //        -> count: List(#(LabelSet, value: Int & Float))
  //        -> buckets: List(#(LabelSet, value: Int & Float))
  // list.fold on all buckets :
  //        -> buckets: Dict(LabelSet (without le), List(le: Number, value: Number)))
  //            -> while you're at it ensure buckets are sorted by `le` order with `list.sort`
  // list.fold on all sums:
  //        -> sums: Dict(LabelSet, value: Number)
  // list.fold on all counts:
  //        -> counts: Dict(LabelSet, value: Number)
  // ensure key sets between the buckets, sums and counts are the same
  // dict.to_list, list.map and dict.from_list: combine buckets, sums and counts into a single dict of records:
  //        -> records: Dict(LabelSet, #(count: Number, sum: Number, buckets: Dict(le: Number, value: Number)))
  // ======================================================
  // End of loop. Now we have records: Dict(MetricName, Dict(LabelSet, #(count: Number, sum: Number, buckets: Dict(le: Number, value: Number))))

  // Print all dis shit like we did before. ez. simple. simple.

  todo
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
