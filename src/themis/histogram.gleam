import gleam/bool
import gleam/dict.{type Dict}
import gleam/result
import gleam/set.{type Set}
import internal/label
import internal/metric/histogram
import internal/prometheus.{type Number}
import themis.{
  type Store, type StoreError, LabelError, MetricError, MetricNameNotFound,
  Store,
}

pub fn register(
  store store: Store,
  name name_string: String,
  description description: String,
) -> Result(Store, StoreError) {
  use #(name, histogram) <- result.map(
    histogram.new(name_string, description)
    |> result.try_recover(fn(e) { Error(MetricError(e)) }),
  )
  Store(..store, histograms: dict.insert(store.histograms, name, histogram))
}

pub fn create_record(
  store store: Store,
  histogram_name name_string: String,
  labels labels_dict: Dict(String, String),
  bucket_thresholds thresholds: Set(Number),
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
  let updated_histogram = histogram.create_record(histogram, labels, thresholds)
  Ok(
    Store(
      ..store,
      histograms: dict.insert(store.histograms, name, updated_histogram),
    ),
  )
}

pub fn measure(
  store store: Store,
  histogram_name name_string: String,
  labels labels_dict: Dict(String, String),
  measurement value: Number,
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
  use updated_histogram <- result.try(
    histogram.measure(histogram, labels, value)
    |> result.try_recover(fn(e) { Error(themis.HistogramError(e)) }),
  )
  Ok(
    Store(
      ..store,
      histograms: dict.insert(store.histograms, name, updated_histogram),
    ),
  )
}

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
