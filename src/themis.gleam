import gleam/result
import themis/counter
import themis/gauge
import themis/histogram
import themis/internal/store.{type Store}

pub type ThemisError {
  GaugeError(gauge.GaugeError)
  HistogramError(histogram.HistogramError)
  CounterError(counter.CounterError)
}

/// Initializes a new empty metrics store.
pub fn init() -> Store {
  store.init()
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
pub fn print(store store: Store) -> Result(String, ThemisError) {
  use gauges_print <- result.try(
    gauge.print(store) |> result.map_error(fn(e) { GaugeError(e) }),
  )
  use counters_print <- result.try(
    counter.print(store) |> result.map_error(fn(e) { CounterError(e) }),
  )
  use histograms_print <- result.try(
    histogram.print(store) |> result.map_error(fn(e) { HistogramError(e) }),
  )
  { gauges_print <> "\n" <> counters_print <> "\n" <> histograms_print }
  |> Ok
}
