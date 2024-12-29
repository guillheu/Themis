import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/order
import gleam/result
import gleam/string
import gleam/string_tree
import themis/internal/label
import themis/internal/metric
import themis/internal/store.{type Store}
import themis/number.{type Number}

pub type CounterError {
  MetricError(metric.MetricError)
  StoreError(store.StoreError)
  InvalidIncrement(value: Number)
  NegativeIncrement
  CounterNameShouldEndWithTotal
  LabelError(label.LabelError)
}

const blacklist = ["counter"]

/// Registers a new counter metric to the store.
/// Counter metric names must end with `_total`.
/// Will return an error if the metric name is invalid
/// or already used by another metric.
pub fn new(
  store store: Store,
  name name: String,
  description description: String,
) -> Result(Nil, CounterError) {
  use <- bool.guard(
    !string.ends_with(name, "total"),
    Error(CounterNameShouldEndWithTotal),
  )
  use name <- result.try(
    metric.new_name(name, blacklist)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  let buckets = []
  use store_error <- result.try_recover(store.new_metric(
    store,
    name,
    description,
    "counter",
    buckets,
  ))
  Error(StoreError(store_error))
}

/// Increments a counter metric for the given metric name.
/// Will return an error if the name is invalid, not a registered metric
/// or not of the correct metric type.
/// Will return an error if any of the labels have an invalid key.
/// Will return an error if the value is NaN, PosInf or NegInf.
pub fn increment_by(
  store store: Store,
  name name: String,
  labels labels: Dict(String, String),
  value value: Number,
) -> Result(Nil, CounterError) {
  use <- bool.guard(
    !string.ends_with(name, "total"),
    Error(CounterNameShouldEndWithTotal),
  )
  use <- bool.guard(
    value == number.NaN || value == number.PosInf || value == number.NegInf,
    Error(InvalidIncrement(value)),
  )
  use <- bool.guard(
    number.unsafe_compare(value, number.integer(0)) == order.Lt,
    Error(NegativeIncrement),
  )
  use name <- result.try(
    metric.new_name(name, blacklist)
    |> result.map_error(fn(e) { MetricError(e) }),
  )
  use _ <- result.try(
    store.find_metric(store, name, "counter")
    |> result.map_error(fn(e) { StoreError(e) }),
  )
  use labels <- result.try(
    label.from_dict(labels) |> result.map_error(fn(e) { LabelError(e) }),
  )
  use store_error <- result.map_error(store.increment_record_by(
    store,
    name,
    labels,
    value,
  ))
  StoreError(store_error)
}

/// Increments a counter metric for the given metric name.
/// Will return an error if the name is invalid, not a registered metric
/// or not of the correct metric type.
/// Will return an error if any of the labels have an invalid key.
pub fn increment(
  store store: Store,
  name name: String,
  labels labels: Dict(String, String),
) -> Result(Nil, CounterError) {
  increment_by(store, name, labels, number.integer(1))
}

/// Formats all counter metrics in the store 
/// as a Prometheus-compatible text string.
pub fn print(store store: Store) -> Result(String, CounterError) {
  use metrics <- result.try(
    store.match_metrics(store, "counter")
    |> result.try_recover(fn(e) { Error(StoreError(e)) }),
  )
  let r = {
    use metrics_strings, #(name_string, description, _buckets) <- list.try_fold(
      metrics,
      [],
    )
    use name <- result.try(
      metric.new_name(name_string, [])
      |> result.map_error(fn(e) { MetricError(e) }),
    )
    use counter_records <- result.try(
      store.match_records(store, name)
      |> result.map_error(fn(e) { StoreError(e) }),
    )
    let help_string = "# HELP " <> name_string <> " " <> description <> "\n"
    let type_string = "# TYPE " <> name_string <> " " <> "counter\n"
    let records_strings =
      dict.to_list(counter_records)
      |> list.map(fn(record) {
        let #(labels, value) = record
        name_string <> label.print(labels) <> " " <> number.print(value) <> "\n"
      })

    Ok([
      "\n",
      type_string,
      help_string,
      ..list.append(records_strings, metrics_strings)
    ])
  }

  use metrics_strings <- result.map(r)
  metrics_strings
  |> string_tree.from_strings
  |> string_tree.to_string
}
