import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gleam/string_tree
import internal/label
import internal/metric.{type Metric, Metric}
import internal/metric/gauge.{type Gauge}
import internal/prometheus.{type Number}

/// A Store manages a collection of metrics, ensuring unique metric names.
pub opaque type Store {
  Store(gauges: Dict(metric.MetricName, Metric(Gauge, Number)))
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
}

/// Creates a new empty metrics store.
pub fn new() -> Store {
  Store(gauges: dict.new())
}

/// Adds a new gauge metric to the store.
///
/// ## Arguments
///
/// - `store`: The metrics store to add the gauge to
/// - `name`: The name of the gauge metric (must be a valid Prometheus metric name)
/// - `description`: A human-readable description of what the gauge measures
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(store) = add_gauge(
///   store,
///   "process_cpu_seconds_total",
///   "Total user and system CPU time spent in seconds",
/// )
/// ```
pub fn add_gauge(
  store store: Store,
  name name_string: String,
  description description: String,
) -> Result(Store, StoreError) {
  use name <- result.try(
    metric.new_name(name_string)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  use <- bool.guard(
    is_metric_name_used(store, name),
    Error(MetricNameAlreadyInUse),
  )
  let gauge = gauge.new(description)
  Ok(Store(gauges: dict.insert(store.gauges, name, gauge)))
}

/// Records a value for a gauge metric with the given labels.
///
/// ## Arguments
///
/// - `store`: The metrics store containing the gauge
/// - `gauge_name`: The name of the gauge to record a value for
/// - `labels`: A dictionary of labels
/// - `value`: The numeric value to record
///
/// ## Examples
///
/// ```gleam
/// let labels = dict.from_list([#("instance", "localhost:9090")])
/// let assert Ok(store) = insert_gauge_record(
///   store,
///   "process_cpu_seconds_total",
///   labels,
///   int(42),
/// )
/// ```
pub fn insert_gauge_record(
  store store: Store,
  gauge_name name_string: String,
  labels labels_dict: Dict(String, String),
  value value: Number,
) -> Result(Store, StoreError) {
  use labels <- result.try(
    label.from_dict(labels_dict)
    |> result.try_recover(fn(e) { Error(LabelError(e)) }),
  )
  use name <- result.try(
    metric.new_name(name_string)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  use gauge <- result.try(
    dict.get(store.gauges, name) |> result.replace_error(MetricNameNotFound),
  )
  let updated_gauge = gauge.insert_record(gauge, labels, value)
  Ok(Store(gauges: dict.insert(store.gauges, name, updated_gauge)))
}

/// Removes a gauge metric and all its recorded values from the store.
///
/// ## Arguments
///
/// - `store`: The metrics store containing the gauge
/// - `gauge_name`: The name of the gauge to delete
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(store) = delete_gauge(store, "process_cpu_seconds_total")
/// ```
pub fn delete_gauge(
  store store: Store,
  gauge_name name_string: String,
) -> Result(Store, StoreError) {
  use name <- result.try(
    metric.new_name(name_string)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  use <- bool.guard(
    !dict.has_key(store.gauges, name),
    Error(MetricNameNotFound),
  )
  let new_gauges = dict.delete(store.gauges, name)
  Ok(Store(gauges: new_gauges))
}

/// Formats all metrics in the store as a Prometheus-compatible text string.
///
/// ## Examples
///
/// ```gleam
/// let metrics_text = print(store)
/// // HELP my_gauge My first gauge
/// // TYPE my_gauge gauge
/// // my_gauge{foo="bar"} 10
/// // my_gauge{toto="tata",wibble="wobble"} +Inf
/// ```
pub fn print(metrics_store store: Store) -> String {
  print_gauges(store.gauges)
}

/// Creates a Number representing an integer value.
pub fn int(value value: Int) -> Number {
  prometheus.Int(value)
}

/// Creates a Number representing a decimal value.
pub fn dec(value value: Float) -> Number {
  prometheus.Dec(value)
}

/// Creates a Number representing positive infinity.
pub fn pos_inf() -> Number {
  prometheus.PosInf
}

/// Creates a Number representing negative infinity.
pub fn neg_inf() -> Number {
  prometheus.NegInf
}

/// Creates a Number representing NaN (Not a Number).
pub fn nan() -> Number {
  prometheus.NaN
}

fn print_gauges(
  gauges: Dict(metric.MetricName, Metric(Gauge, Number)),
) -> String {
  {
    use current, gauge, name <- dict.fold(gauges, [])
    [gauge.print(name, gauge) <> "\n", ..current]
  }
  |> list.reverse
  |> string_tree.from_strings
  |> string_tree.to_string
}

fn is_metric_name_used(store: Store, name: metric.MetricName) -> Bool {
  use <- bool.guard(dict.has_key(store.gauges, name), True)
  False
}
