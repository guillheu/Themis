import gleam/bool
import gleam/dict.{type Dict}
import gleam/result
import internal/label
import internal/metric/gauge
import themis.{
  type Store, type StoreError, LabelError, MetricError, MetricNameNotFound,
  Store,
}
import themis/number.{type Number}

/// Registers a new gauge metric to the store.
///
/// ## Arguments
///
/// - `store`: The metrics store to add the gauge to
/// - `name`: The name of the new gauge metric (must be a valid Prometheus metric name)
/// - `description`: A human-readable description of what the gauge observes
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(store) = register(
///   store,
///   "process_cpu_seconds_total",
///   "Total user and system CPU time spent in seconds",
/// )
/// ```
pub fn register(
  store store: Store,
  name name_string: String,
  description description: String,
) -> Result(Store, StoreError) {
  use #(name, gauge) <- result.try(
    gauge.new(name_string, description)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )

  use <- bool.guard(
    themis.is_metric_name_used(store, name),
    Error(themis.MetricNameAlreadyInUse),
  )
  Ok(Store(..store, gauges: dict.insert(store.gauges, name, gauge)))
}

/// Records a value for a gauge metric with the given labels.
///
/// ## Arguments
///
/// - `store`: The metrics store containing the gauge
/// - `gauge_name`: The name of the gauge
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
pub fn observe(
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
    gauge.new_name(name_string)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  use gauge <- result.try(
    dict.get(store.gauges, name) |> result.replace_error(MetricNameNotFound),
  )
  let updated_gauge = gauge.observe(gauge, labels, value)
  Ok(Store(..store, gauges: dict.insert(store.gauges, name, updated_gauge)))
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
/// let assert Ok(store) = unregister(store, "process_cpu_seconds_total")
/// ```
pub fn unregister(
  store store: Store,
  gauge_name name_string: String,
) -> Result(Store, StoreError) {
  use name <- result.try(
    gauge.new_name(name_string)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  use <- bool.guard(
    !dict.has_key(store.gauges, name),
    Error(MetricNameNotFound),
  )
  let new_gauges = dict.delete(store.gauges, name)
  Ok(Store(..store, gauges: new_gauges))
}
