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

pub fn init() -> Store {
  store.init()
}

pub fn print(store store: Store) -> Result(String, ThemisError) {
  use gauges_print <- result.try(
    gauge.print_all(store) |> result.map_error(fn(e) { GaugeError(e) }),
  )
  use counters_print <- result.try(
    counter.print_all(store) |> result.map_error(fn(e) { CounterError(e) }),
  )
  use histograms_print <- result.try(
    histogram.print_all(store) |> result.map_error(fn(e) { HistogramError(e) }),
  )
  { gauges_print <> "\n" <> counters_print <> "\n" <> histograms_print }
  |> Ok
}
