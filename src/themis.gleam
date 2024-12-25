import themis/internal/metric.{type MetricName}
import themis/internal/store.{type Store}

pub fn init() -> Store {
  store.init()
}

pub fn print(store store: Store) -> String {
  todo
}

pub fn is_metric_inserted(
  store store: Store,
  name name: String,
) -> Result(MetricName, Nil) {
  // Will first validate that the given string is a valid metric name
  // then will lookup that metric metadata
  // if found, return its metric name to then be used for gauge.observe etc
  // if not found, error
  todo
}
