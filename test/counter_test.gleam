import gleam/dict
import gleam/io
import gleeunit/should
import internal/label
import internal/metric
import internal/metric/counter
import internal/prometheus

pub fn create_test() {
  let expected = make_test_counter(with_record: False, dec: False)
  let #(name, metric) =
    counter.new("my_metric", "A simple counter for testing") |> should.be_ok
  metric
  |> should.equal(expected)

  name
  |> should.equal("my_metric_total" |> metric.new_name([]) |> should.be_ok)
}

pub fn increment_test() {
  let expected = make_test_counter(with_record: True, dec: False)
  let labels = label.new() |> label.add_label("foo", "bar") |> should.be_ok
  let base_name = "my_metric"

  let #(name, metric) =
    counter.new(base_name, "A simple counter for testing") |> should.be_ok

  metric
  |> counter.create_record(labels)
  |> should.be_ok
  |> counter.increment(labels)
  |> should.be_ok
  |> should.equal(expected)

  name
  |> should.equal("my_metric_total" |> metric.new_name([]) |> should.be_ok)

  let expected = make_test_counter(with_record: True, dec: True)
  let #(name, metric) =
    counter.new(base_name, "A simple counter for testing") |> should.be_ok

  metric
  |> counter.create_record(labels)
  |> should.be_ok
  |> counter.increment_by(labels, prometheus.Dec(1.0))
  |> should.be_ok
  |> should.equal(expected)

  name
  |> should.equal("my_metric_total" |> metric.new_name([]) |> should.be_ok)
}

pub fn delete_test() {
  let expected = make_test_counter(with_record: False, dec: False)
  let from = make_test_counter(with_record: True, dec: False)

  let labels = label.new() |> label.add_label("foo", "bar") |> should.be_ok

  from
  |> counter.delete_record(labels)
  |> should.equal(expected)
}

pub fn to_string_test() {
  make_test_counter(with_record: False, dec: False)
  |> counter.print("my_metric" |> metric.new_name([]) |> should.be_ok)
  |> should.equal(
    "# HELP my_metric A simple counter for testing\n# TYPE my_metric counter\n",
  )

  make_test_counter(with_record: True, dec: False)
  |> counter.print("my_metric" |> metric.new_name([]) |> should.be_ok)
  |> should.equal(
    "# HELP my_metric A simple counter for testing\n# TYPE my_metric counter\nmy_metric{foo=\"bar\"} 1\n",
  )

  let new_record_labels =
    label.new()
    |> label.add_label("foo", "bar")
    |> should.be_ok
    |> label.add_label("toto", "tata")
    |> should.be_ok
    |> label.add_label("wibble", "wobble")
    |> should.be_ok

  make_test_counter(with_record: True, dec: False)
  |> counter.create_record(new_record_labels)
  |> should.be_ok
  |> counter.print("my_metric" |> metric.new_name([]) |> should.be_ok)
  // |> io.println_error
  |> should.equal(
    "# HELP my_metric A simple counter for testing\n# TYPE my_metric counter\nmy_metric{foo=\"bar\"} 1\nmy_metric{foo=\"bar\",toto=\"tata\",wibble=\"wobble\"} 0\n",
  )
  // # HELP my_metric A simple counter for testing
  // # TYPE my_metric counter
  // my_metric{foo="bar"} 1
  // my_metric{foo="bar",toto="tata",wibble="wobble"} 0
}

fn make_test_counter(
  with_record with_record: Bool,
  dec dec: Bool,
) -> metric.Metric(counter.Counter, prometheus.Number) {
  let val = case dec {
    False -> prometheus.Int(1)
    True -> prometheus.Dec(1.0)
  }
  let records = case with_record {
    False -> dict.new()
    True -> {
      let labels = label.new() |> label.add_label("foo", "bar") |> should.be_ok
      dict.from_list([#(labels, val)])
    }
  }
  metric.Metric("A simple counter for testing", records)
}
