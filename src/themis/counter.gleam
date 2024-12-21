import gleam/bool
import gleam/dict.{type Dict}
import gleam/result
import internal/label
import internal/metric/counter
import themis.{
  type Store, type StoreError, LabelError, MetricError, MetricNameNotFound,
  Store,
}
import themis/number.{type Number}

/// Registers a new counter metric to the store.
///
/// ## Arguments
///
/// - `store`: The metrics store to add the counter to
/// - `name`: The name of the new counter metric (must be a valid Prometheus metric name)
/// - `description`: A human-readable description of what the counter observes
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(store) = register(
///   store,
///   "http_request_failures",
///   "Count of HTTP request failures",
/// )
/// ```
pub fn register(
  store store: Store,
  name name_string: String,
  description description: String,
) -> Result(Store, StoreError) {
  use #(name, counter) <- result.try(
    counter.new(name_string, description)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )

  use <- bool.guard(
    themis.is_metric_name_used(store, name),
    Error(themis.MetricNameAlreadyInUse),
  )
  Ok(Store(..store, counters: dict.insert(store.counters, name, counter)))
}

/// Initializes a new counter metric record with the given labels.
///
/// ## Arguments
///
/// - `store`: The metrics store containing the counter
/// - `counter_name`: The name of the counter
/// - `labels`: A dictionary of labels
///
/// ## Examples
///
/// ```gleam
/// let labels = dict.from_list([#("instance", "localhost:9090")])
/// let assert Ok(store) = init_record(
///   store,
///   "http_request_failures",
///   labels,
/// )
/// ```
pub fn init_record(
  store store: Store,
  counter_name name_string: String,
  labels labels_dict: Dict(String, String),
) -> Result(Store, StoreError) {
  use labels <- result.try(
    label.from_dict(labels_dict)
    |> result.try_recover(fn(e) { Error(LabelError(e)) }),
  )
  use name <- result.try(
    counter.new_name(name_string)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  use counter <- result.try(
    dict.get(store.counters, name) |> result.replace_error(MetricNameNotFound),
  )
  let updated_counter = counter.init_record(counter, labels)

  Ok(
    Store(..store, counters: dict.insert(store.counters, name, updated_counter)),
  )
}

/// Increments a counter record with the given labels by 1.
///
/// ## Arguments
///
/// - `store`: The metrics store containing the counter
/// - `counter_name`: The name of the counter
/// - `labels`: A dictionary of labels
///
/// ## Examples
///
/// ```gleam
/// let labels = dict.from_list([#("instance", "localhost:9090")])
/// let assert Ok(store) = increment(
///   store,
///   "http_request_failures",
///   labels,
/// )
/// ```
pub fn increment(
  store store: Store,
  counter_name name_string: String,
  labels labels_dict: Dict(String, String),
) -> Result(Store, StoreError) {
  use labels <- result.try(
    label.from_dict(labels_dict)
    |> result.try_recover(fn(e) { Error(LabelError(e)) }),
  )
  use name <- result.try(
    counter.new_name(name_string)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  use counter <- result.try(
    dict.get(store.counters, name) |> result.replace_error(MetricNameNotFound),
  )
  let updated_counter = counter.increment(counter, labels)

  Ok(
    Store(..store, counters: dict.insert(store.counters, name, updated_counter)),
  )
}

/// Increments a counter record with the given labels by a specified value.
///
/// ## Arguments
///
/// - `store`: The metrics store containing the counter
/// - `counter_name`: The name of the counter
/// - `labels`: A dictionary of labels
///
/// ## Examples
///
/// ```gleam
/// let labels = dict.from_list([#("instance", "localhost:9090")])
/// let assert Ok(store) = increment(
///   store,
///   "http_request_failures",
///   labels,
///   number.int(12),
/// )
/// ```
pub fn increment_by(
  store store: Store,
  counter_name name_string: String,
  labels labels_dict: Dict(String, String),
  by by: Number,
) -> Result(Store, StoreError) {
  use labels <- result.try(
    label.from_dict(labels_dict)
    |> result.try_recover(fn(e) { Error(LabelError(e)) }),
  )
  use name <- result.try(
    counter.new_name(name_string)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  use counter <- result.try(
    dict.get(store.counters, name) |> result.replace_error(MetricNameNotFound),
  )
  let updated_counter = counter.increment_by(counter, labels, by)

  Ok(
    Store(..store, counters: dict.insert(store.counters, name, updated_counter)),
  )
}

/// Removes a counter metric and all its recorded values from the store.
///
/// ## Arguments
///
/// - `store`: The metrics store containing the counter
/// - `counter_name`: The name of the counter to delete
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(store) = unregister(store, "http_request_failures")
/// ```
pub fn unregister(
  store store: Store,
  counter_name name_string: String,
) -> Result(Store, StoreError) {
  use name <- result.try(
    counter.new_name(name_string)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  use <- bool.guard(
    !dict.has_key(store.counters, name),
    Error(MetricNameNotFound),
  )
  let new_counters = dict.delete(store.counters, name)
  Ok(Store(..store, counters: new_counters))
}
