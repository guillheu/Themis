import gleam/dict
import gleam/list
import gleam/result
import gleam/string_tree
import themis/internal/label.{type LabelSet}
import themis/internal/metric
import themis/internal/store.{type Store}
import themis/number.{type Number}

pub type GaugeError {
  MetricError(metric.MetricError)
  StoreError(store.StoreError)
}

const blacklist = ["gauge"]

pub fn new(
  store store: Store,
  name name: String,
  description description: String,
) -> Result(Nil, GaugeError) {
  use name <- result.try(
    metric.new_name(name, blacklist)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  let buckets = []
  use store_error <- result.try_recover(store.new_metric(
    store,
    name,
    description,
    "gauge",
    buckets,
  ))
  Error(StoreError(store_error))
}

pub fn observe(
  store store: Store,
  name name: String,
  labels labels: LabelSet,
  value value: Number,
) -> Result(Nil, GaugeError) {
  use name <- result.try(
    metric.new_name(name, blacklist)
    |> result.map_error(fn(e) { MetricError(e) }),
  )
  use store_error <- result.map_error(store.insert_record(
    store,
    name,
    labels,
    value,
  ))
  StoreError(store_error)
}

pub fn print_all(store store: Store) -> Result(String, GaugeError) {
  use metrics <- result.try(
    store.match_metrics(store, "gauge")
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
      store.match_records(store, name)
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
