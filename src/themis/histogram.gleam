import gleam/bool
import gleam/dict.{type Dict}
import gleam/result
import gleam/set.{type Set}
import internal/label
import internal/metric/histogram
import themis.{
  type Store, type StoreError, LabelError, MetricError, MetricNameNotFound,
  Store,
}
import themis/number.{type Number}

/// Registers a new histogram metric to the store.
///
/// ## Arguments
///
/// - `store`: The metrics store to add the histogram to
/// - `name`: The name of the new histogram metric (must be a valid Prometheus metric name)
/// - `description`: A human-readable description of what the histogram observes
/// - `buckets`: A set of numbers defining the buckets by their `le` limits
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(store) = register(
///   store,
///   "app_request_processing_seconds",
///   "Time spent processing request",
/// )
/// ```
pub fn register(
  store store: Store,
  name name_string: String,
  description description: String,
  buckets buckets: Set(Number),
) -> Result(Store, StoreError) {
  use #(name, histogram) <- result.try(
    histogram.new(name_string, description, buckets)
    |> result.try_recover(fn(e) { Error(themis.HistogramError(e)) }),
  )
  use <- bool.guard(
    themis.is_metric_name_used(store, name),
    Error(themis.MetricNameAlreadyInUse),
  )
  Ok(Store(..store, histograms: dict.insert(store.histograms, name, histogram)))
}

/// Initializes a new histogram metric record with the given labels.
///
/// ## Arguments
///
/// - `store`: The metrics store containing the histogram
/// - `histogram_name`: The name of the histogram
/// - `labels`: A dictionary of labels
/// - `bucket_boundaries`: A set of numbers defining the buckets by their `le` limits
/// 
/// Note that a `+Inf` bucket is always added by default if it isn't provided.
///
/// ## Examples
///
/// ```gleam
/// let labels = dict.from_list([#("instance", "localhost:9090")])
/// let buckets = set.from_list(
///   [
///     number.dec(0.05), 
///     number.dec(0.1), 
///     number.dec(0.2), 
///     number.dec(0.5),
///     number.int(1),
///   ]
/// )
/// let assert Ok(store) = init_record(
///   store,
///   "app_request_processing_seconds",
///   labels,
///   buckets,
/// )
/// ```
pub fn init_record(
  store store: Store,
  histogram_name name_string: String,
  labels labels_dict: Dict(String, String),
) -> Result(Store, StoreError) {
  use labels <- result.try(
    label.from_dict(labels_dict)
    |> result.try_recover(fn(e) { Error(LabelError(e)) }),
  )
  use name <- result.try(
    histogram.new_name(name_string)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  use histogram <- result.try(
    dict.get(store.histograms, name) |> result.replace_error(MetricNameNotFound),
  )
  let updated_histogram = histogram.init_record(histogram, labels)

  Ok(
    Store(
      ..store,
      histograms: dict.insert(store.histograms, name, updated_histogram),
    ),
  )
}

/// Records an observation value for a histogram metric.
///
/// ## Arguments
///
/// - `store`: The metrics store containing the histogram
/// - `histogram_name`: The name of the histogram metric
/// - `labels`: A dictionary of labels
/// - `value`: The value to record in the histogram
///
/// ## Examples
///
/// ```gleam
/// let labels = dict.from_list([#("instance", "localhost:9090")])
/// let value = number.dec(0.123)
/// let assert Ok(store) = observe(
///   store,
///   "app_request_processing_seconds", 
///   labels,
///   value,
/// )
/// ```
pub fn observe(
  store store: Store,
  histogram_name name_string: String,
  labels labels_dict: Dict(String, String),
  value value: Number,
) -> Result(Store, StoreError) {
  use labels <- result.try(
    label.from_dict(labels_dict)
    |> result.try_recover(fn(e) { Error(LabelError(e)) }),
  )
  use name <- result.try(
    histogram.new_name(name_string)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  use histogram <- result.try(
    dict.get(store.histograms, name) |> result.replace_error(MetricNameNotFound),
  )
  let updated_histogram = histogram.observe(histogram, labels, value)
  Ok(
    Store(
      ..store,
      histograms: dict.insert(store.histograms, name, updated_histogram),
    ),
  )
}

/// Unregisters a new histogram metric to the store.
///
/// ## Arguments
///
/// - `store`: The metrics store to add the histogram to
/// - `name`: The name of the new histogram metric (must be a valid Prometheus metric name)
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(store) = unregister(
///   store,
///   "app_request_processing_seconds",
/// )
/// ```
pub fn unregister(
  store store: Store,
  histogram_name name_string: String,
) -> Result(Store, StoreError) {
  use name <- result.try(
    histogram.new_name(name_string)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  use <- bool.guard(
    !dict.has_key(store.histograms, name),
    Error(MetricNameNotFound),
  )
  let new_histograms = dict.delete(store.histograms, name)
  Ok(Store(..store, histograms: new_histograms))
}
