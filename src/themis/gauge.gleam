import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gleam/string_tree
import themis/internal/label
import themis/internal/metric
import themis/internal/store
import themis/number.{type Number}

pub type GaugeError {
  MetricError(metric.MetricError)
  StoreError(store.StoreError)
  LabelError(label.LabelError)
}

const blacklist = ["gauge"]

/// Registers a new gauge metric to the store.
/// Will return an error if the metric name is invalid
/// or already used by another metric.
pub fn new(
  // store store: Store,
  name name: String,
  description description: String,
) -> Result(Nil, GaugeError) {
  use name <- result.try(
    metric.new_name(name, blacklist)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  let buckets = []
  use store_error <- result.try_recover(store.new_metric(
    name,
    description,
    "gauge",
    buckets,
  ))
  Error(StoreError(store_error))
}

/// Sets a gauge value for the given metric name.
/// Will return an error if the name is invalid, not a registered metric
/// or not of the correct metric type.
/// Will return an error if any of the labels have an invalid key.
/// NaN, PosInf and NegInf values are valid but not recommended.
pub fn observe(
  // store store: Store,
  name name: String,
  labels labels: Dict(String, String),
  value value: Number,
) -> Result(Nil, GaugeError) {
  use name <- result.try(
    metric.new_name(name, blacklist)
    |> result.map_error(fn(e) { MetricError(e) }),
  )
  use _ <- result.try(
    store.find_metric(name, "gauge")
    |> result.map_error(fn(e) { StoreError(e) }),
  )
  use labels <- result.try(
    label.from_dict(labels) |> result.map_error(fn(e) { LabelError(e) }),
  )
  use store_error <- result.map_error(store.insert_record(name, labels, value))
  StoreError(store_error)
}

pub fn print() -> Result(String, GaugeError) {
  use metrics <- result.try(
    store.match_metrics("gauge")
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
    use metric_records <- result.try(
      store.match_records(name)
      |> result.map_error(fn(e) { StoreError(e) }),
    )
    let help_string = "# HELP " <> name_string <> " " <> description <> "\n"
    let type_string = "# TYPE " <> name_string <> " " <> "gauge\n"
    let records_strings =
      dict.to_list(metric_records)
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
