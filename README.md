# Themis

Prometheus client in pure Gleam!

[![Package Version](https://img.shields.io/hexpm/v/themis)](https://hex.pm/packages/themis)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/themis/)

```sh
gleam add themis
```

## Quick Start

```gleam
import themis
import gleam/dict
import gleam/io

pub fn main() {
  // Create a new themis store
  let store = themis.new()

  // Add a gauge metric
  let assert Ok(store) = themis.add_gauge(
    store,
    "process_memory_bytes",
    "Current memory usage in bytes",
  )

  // Record some values with labels
  let labels = dict.from_list([
    #("process", "web_server"),
    #("instance", "prod-1"),
  ])
  
  let assert Ok(store) = themis.insert_gauge_record(
    store,
    "process_memory_bytes",
    labels,
    metrics.int(1_234_567),
  )

  // Export metrics in Prometheus format
  io.println(metrics.print(store))
}
```

Further documentation can be found at <https://hexdocs.pm/themis>.

## Usage

### Working with Different Numeric Types

Themis metric values are set using the dedicated `Number` type. There are 5 number types available:

```gleam
import themis

// Integer values
let memory = themis.int(1_234_567)

// Decimal (float) values
let temperature = themis.dec(23.5)

// Special values
let and_beyond = themis.pos_inf()
let lower_bound = themis.neg_inf()
let unknown = themis.nan()
```

## Output Format

The metrics are exported in the standard Prometheus text format:

```
# # HELP process_memory_bytes Current memory usage in bytes
# # TYPE process_memory_bytes gauge
process_memory_bytes{process="web_server",instance="prod-1"} 1234567
```

## License

MIT