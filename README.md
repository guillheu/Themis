# Themis

Prometheus client in pure Gleam!

[![Package Version](https://img.shields.io/hexpm/v/themis)](https://hex.pm/packages/themis)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/themis/)

```sh
gleam add themis
```

## Quick Start

```gleam
import gleam/dict
import gleam/io
import gleam/set
import themis
import themis/counter
import themis/gauge
import themis/histogram
import themis/number

pub fn main() {
  // Create the new metrics store
  let metrics_store = themis.new()

  // Gauge

  // This can fail if the metric name is invalid
  let assert Ok(metrics_store) =
    gauge.register(
      metrics_store,
      "my_first_metric",
      "A gauge Prometheus metric",
    )

  let labels = dict.from_list([#("foo", "bar")])
  let value = number.int(10)
  let assert Ok(metrics_store) =
    gauge.observe(metrics_store, "my_first_metric", labels, value)

  // Counter

  let assert Ok(metrics_store) =
    counter.register(
      metrics_store,
      "my_second_metric",
      "A counter Prometheus metric",
    )

  let labels = dict.from_list([#("wibble", "wobble")])
  let other_labels = dict.from_list([#("wii", "woo")])
  // Counters can optionally be initialized manually
  let assert Ok(metrics_store) =
    counter.init_record(metrics_store, "my_second_metric", labels)
  let assert Ok(metrics_store) =
    counter.increment(metrics_store, "my_second_metric", labels)
  // When incrementing a counter with new labels, a new counter will automatically be initialized then incremented
  let assert Ok(metrics_store) =
    counter.increment_by(
      metrics_store,
      "my_second_metric",
      other_labels,
      number.dec(1.2),
    )

  // Histogram

  // Histograms work with buckets. Each bucket needs an upper boundary.
  let buckets =
    set.from_list([
      number.dec(0.05),
      number.dec(0.1),
      number.dec(0.25),
      number.dec(0.5),
      number.int(1),
    ])
  let assert Ok(metrics_store) =
    histogram.register(
      metrics_store,
      "my_third_metric",
      "A histogram Prometheus metric",
      buckets,
    )

  let value = number.int(20)
  let other_value = number.dec(1.5)
  let labels = dict.from_list([#("toto", "tata")])
  let other_labels = dict.from_list([#("toto", "titi")])
  // Histograms can optionally be initialized manually
  let assert Ok(metrics_store) =
    histogram.observe(metrics_store, "my_third_metric", labels, value)
  // When incrementing a histogram with new labels, a new histogram will automatically be initialized
  let assert Ok(metrics_store) =
    histogram.observe(
      metrics_store,
      "my_third_metric",
      other_labels,
      other_value,
    )

  // Printing all the metrics as a Prometheus-scrapable String
  themis.print(metrics_store)
  |> io.println
}

```

This code will print the following prometheus-compatible metrics:

```
# HELP my_first_metric A gauge Prometheus metric
# TYPE my_first_metric gauge
my_first_metric{foo="bar"} 10

# HELP my_second_metric_total A counter Prometheus metric
# TYPE my_second_metric_total counter
my_second_metric_total{wibble="wobble"} 1
my_second_metric_total{wii="woo"} 1.2

# HELP my_third_metric A histogram Prometheus metric
# TYPE my_third_metric histogram
my_third_metric_bucket{le="0.05",toto="tata"} 0
my_third_metric_bucket{le="0.1",toto="tata"} 0
my_third_metric_bucket{le="0.25",toto="tata"} 0
my_third_metric_bucket{le="0.5",toto="tata"} 0
my_third_metric_bucket{le="1",toto="tata"} 0
my_third_metric_bucket{le="+Inf",toto="tata"} 1
my_third_metric_sum{toto="tata"} 1
my_third_metric_count{toto="tata"} 1

my_third_metric_bucket{le="0.05",toto="titi"} 0
my_third_metric_bucket{le="0.1",toto="titi"} 0
my_third_metric_bucket{le="0.25",toto="titi"} 0
my_third_metric_bucket{le="0.5",toto="titi"} 0
my_third_metric_bucket{le="1",toto="titi"} 0
my_third_metric_bucket{le="+Inf",toto="titi"} 1
my_third_metric_sum{toto="titi"} 1
my_third_metric_count{toto="titi"} 1

```

Further documentation can be found at <https://hexdocs.pm/themis>.

## Usage

### Working with Different Numeric Types

Themis metric values are set using the dedicated `Number` type. There are 5 number types available:

```gleam
import themis/number

// Integer values
let integer = number.int(1_234_567)

// Decimal (float) values
let decimal = number.dec(23.5)

// Special values
let positive_infinity = number.pos_inf()
let negative_infinity = themis.neg_inf()
let not_a_number = themis.nan()
```
### Metric Types

#### Gauges

Gauges are metrics that represent a single numerical value that can arbitrarily go up and down. They are typically used for measured values like temperatures, current memory usage, or number of active connections.

```gleam
import themis/gauge

// Register a new gauge metric
let assert Ok(metrics_store) = 
  gauge.register(
    metrics_store,
    "process_memory_bytes",
    "Current memory usage in bytes",
  )

// Set a gauge value with labels
let labels = dict.from_list([#("process", "web_server")])
let value = number.int(52_428_800)  // 50MB in bytes
let assert Ok(metrics_store) =
  gauge.observe(metrics_store, "process_memory_bytes", labels, value)
```

#### Counters

Counters are cumulative metrics that can only increase or be reset to zero. They are typically used to count requests served, tasks completed, errors occurred, or other countable occurrences.

```gleam
import themis/counter

// Register a new counter metric
let assert Ok(metrics_store) =
  counter.register(
    metrics_store,
    "http_requests_total",
    "Total number of HTTP requests made",
  )

// Initialize a counter with specific labels (optional)
let labels = dict.from_list([#("method", "GET"), #("path", "/api/users")])
let assert Ok(metrics_store) =
  counter.init_record(metrics_store, "http_requests_total", labels)

// Increment counter by 1
let assert Ok(metrics_store) =
  counter.increment(metrics_store, "http_requests_total", labels)

// Increment counter by specific amount
let assert Ok(metrics_store) =
  counter.increment_by(
    metrics_store,
    "http_requests_total",
    labels,
    number.dec(5.0),
  )
```

#### Histograms

Histograms sample observations (usually duration or response size) and count them in configurable buckets. They also provide a sum of all observed values and a count of observations.

```gleam
import themis/histogram

// Define histogram buckets (upper bounds of observation buckets in seconds)
let buckets =
  set.from_list([
    number.dec(0.005),  // 5ms
    number.dec(0.01),   // 10ms
    number.dec(0.025),  // 25ms
    number.dec(0.05),   // 50ms
    number.dec(0.1),    // 100ms
    number.dec(0.25),   // 250ms
    number.dec(0.5),    // 500ms
    number.dec(1.0),    // 1s
  ])

// Register a new histogram metric
let assert Ok(metrics_store) =
  histogram.register(
    metrics_store,
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    buckets,
  )

// Record an observation
let labels = dict.from_list([#("method", "POST"), #("path", "/api/users")])
let duration = number.dec(0.157)  // 157ms
let assert Ok(metrics_store) =
  histogram.observe(
    metrics_store,
    "http_request_duration_seconds",
    labels,
    duration,
  )
```

Each histogram observation is counted in all buckets with upper bounds greater than the observation value. The `+Inf` bucket is automatically added and counts all observations. Additionally, histograms track the sum of all observed values and the total count of observations.

#### Summaries

Summaries have not yet been implemented, because at first glance it seems an accurate summary must keep a complete history of all the observed values, which will be a huge memory hog. This means I would have to implement some algorithm that goes way above my head to instead derive an approximation. I ain't doin' that (maybe one day if I need summaries but don't hold your breath).<br>
If you're feeling adventurous, feel free to open a PR.

## License

MIT