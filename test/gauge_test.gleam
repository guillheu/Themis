import gleam/dict
import gleeunit/should
import internal/label
import internal/metric
import internal/metric/gauge
import internal/prometheus

pub fn create_test() {
  let expected = make_test_gauge(with_record: False)

  gauge.new("A simple gauge for testing")
  |> should.equal(expected)
}

pub fn update_test() {
  let expected = make_test_gauge(with_record: True)

  gauge.new("A simple gauge for testing")
  |> gauge.insert_record(
    label.new() |> label.add_label("foo", "bar") |> should.be_ok,
    prometheus.Int(10),
  )
  |> should.equal(expected)
}

pub fn delete_test() {
  let expected = make_test_gauge(with_record: False)
  let from = make_test_gauge(with_record: True)

  let labels = label.new() |> label.add_label("foo", "bar") |> should.be_ok

  from
  |> gauge.delete_record(labels)
  |> should.equal(expected)
}

pub fn to_string_test() {
  make_test_gauge(with_record: False)
  |> gauge.print("my_gauge" |> metric.new_name |> should.be_ok)
  |> should.equal(
    "HELP my_gauge A simple gauge for testing\nTYPE my_gauge gauge\n",
  )

  make_test_gauge(with_record: True)
  |> gauge.print("my_gauge" |> metric.new_name |> should.be_ok)
  |> should.equal(
    "HELP my_gauge A simple gauge for testing\nTYPE my_gauge gauge\nmy_gauge{foo=\"bar\"} 10\n",
  )

  let new_record_labels =
    label.new()
    |> label.add_label("foo", "bar")
    |> should.be_ok
    |> label.add_label("toto", "tata")
    |> should.be_ok
    |> label.add_label("wibble", "wobble")
    |> should.be_ok

  make_test_gauge(with_record: True)
  |> gauge.insert_record(new_record_labels, prometheus.Int(69))
  |> gauge.print("my_gauge" |> metric.new_name |> should.be_ok)
  |> should.equal(
    "HELP my_gauge A simple gauge for testing\nTYPE my_gauge gauge\nmy_gauge{foo=\"bar\"} 10\nmy_gauge{foo=\"bar\",toto=\"tata\",wibble=\"wobble\"} 69\n",
  )
}

fn make_test_gauge(
  with_record with_record: Bool,
) -> metric.Metric(gauge.Gauge, prometheus.Number) {
  let records = case with_record {
    False -> dict.new()
    True -> {
      let labels = label.new() |> label.add_label("foo", "bar") |> should.be_ok
      dict.from_list([#(labels, prometheus.Int(10))])
    }
  }
  metric.Metric("A simple gauge for testing", records)
}
