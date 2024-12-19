import gleam/bool
import gleam/list
import gleam/result
import gleam/string_tree
import internal/prometheus.{type Number}
import themis/metric.{type Metric, Metric}
import themis/metric/gauge.{type Gauge}

pub opaque type Store {
  Store(gauges: List(Metric(Gauge, Number)))
}

pub fn new() -> Store {
  Store(gauges: [])
}

pub type StoreError {
  MetricNameAlreadyInUse
  MetricNameNotFound
}

pub fn add_gauge(
  store store: Store,
  to_add gauge: Metric(Gauge, Number),
) -> Result(Store, StoreError) {
  use <- bool.guard(
    is_metric_name_used(store, gauge.name),
    Error(MetricNameAlreadyInUse),
  )
  Ok(Store(gauges: [gauge, ..store.gauges]))
}

pub fn pop_gauge(
  store store: Store,
  gauge_name name: metric.MetricName,
) -> Result(#(Metric(Gauge, Number), Store), StoreError) {
  list.pop(store.gauges, fn(gauge) { gauge.name == name })
  |> result.replace_error(MetricNameNotFound)
  |> result.map(fn(res) {
    let #(popped, remainder) = res
    #(popped, Store(gauges: remainder))
  })
}

pub fn print(metrics_store store: Store) -> String {
  print_gauges(store.gauges)
}

fn print_gauges(gauges: List(Metric(Gauge, Number))) -> String {
  {
    use gauge <- list.map(gauges)
    gauge.print(gauge) <> "\n"
  }
  |> string_tree.from_strings
  |> string_tree.to_string
}

fn is_metric_name_used(store: Store, name: metric.MetricName) -> Bool {
  use <- bool.guard(
    list.any(store.gauges, fn(metric) { metric.name == name }),
    True,
  )
  False
}
