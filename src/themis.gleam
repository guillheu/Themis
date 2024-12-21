import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/string_tree
import internal/label
import internal/metric.{type Metric, Metric}
import internal/metric/counter.{type Counter}
import internal/metric/gauge.{type Gauge}
import internal/metric/histogram.{type Histogram, type HistogramRecord}
import themis/number.{type Number}

/// A Store manages a collection of metrics, ensuring unique metric names.
pub type Store {
  Store(
    gauges: Dict(metric.MetricName, Metric(Gauge, Number)),
    counters: Dict(metric.MetricName, Metric(Counter, Number)),
    histograms: Dict(metric.MetricName, Metric(Histogram, HistogramRecord)),
  )
}

/// Represents possible errors that can occur when operating on the Store.
pub type StoreError {
  /// Returned when attempting to create a metric with a name that's already in use
  MetricNameAlreadyInUse
  /// Returned when attempting to operate on a metric that doesn't exist
  MetricNameNotFound
  /// Wraps errors related to metric name validation
  MetricError(metric.MetricError)
  /// Wraps errors related to label validation
  LabelError(label.LabelError)
  /// Wraps errors related to counters
  CounterError(counter.CounterError)
  /// Wraps errors related to counters
  HistogramError(histogram.HistogramError)
}

/// Creates a new empty metrics store.
pub fn new() -> Store {
  Store(gauges: dict.new(), counters: dict.new(), histograms: dict.new())
}

/// Formats all metrics in the store as a Prometheus-compatible text string.
///
/// ## Examples
///
/// ```gleam
/// let metrics_text = print(store)
/// // # HELP my_metric My first gauge
/// // # TYPE my_metric gauge
/// // my_metric{foo="bar"} 10
/// // my_metric{toto="tata",wibble="wobble"} +Inf
/// ```
pub fn print(metrics_store store: Store) -> String {
  print_gauges(store.gauges)
  <> print_counters(store.counters)
  <> print_histograms(store.histograms)
}

fn print_gauges(
  gauges: Dict(metric.MetricName, Metric(Gauge, Number)),
) -> String {
  {
    use current, name, gauge <- dict.fold(gauges, [])
    [gauge.print(gauge, name) <> "\n", ..current]
  }
  |> list.reverse
  |> string_tree.from_strings
  |> string_tree.to_string
}

fn print_counters(
  counters: Dict(metric.MetricName, Metric(Counter, Number)),
) -> String {
  {
    use current, name, counter <- dict.fold(counters, [])
    [counter.print(counter, name) <> "\n", ..current]
  }
  |> list.reverse
  |> string_tree.from_strings
  |> string_tree.to_string
}

fn print_histograms(
  histograms: Dict(metric.MetricName, Metric(Histogram, HistogramRecord)),
) -> String {
  {
    use current, counter, name <- dict.fold(histograms, [])
    [histogram.print(name, counter) <> "\n", ..current]
  }
  |> list.reverse
  |> string_tree.from_strings
  |> string_tree.to_string
}

pub fn is_metric_name_used(store: Store, name: metric.MetricName) -> Bool {
  use <- bool.guard(dict.has_key(store.gauges, name), True)
  use <- bool.guard(dict.has_key(store.counters, name), True)
  use <- bool.guard(dict.has_key(store.histograms, name), True)
  False
}
