import gleam/dict
import gleeunit/should
import themis/internal/label
import themis/internal/metric
import themis/internal/metric/gauge
import themis/number

pub fn create_test() {
  let expected = make_test_gauge(with_record: False)

  let #(_name, metric) =
    gauge.new("my_metric", "A simple gauge for testing") |> should.be_ok

  metric
  |> should.equal(expected)
}

pub fn update_test() {
  let expected = make_test_gauge(with_record: True)

  let #(_name, metric) =
    gauge.new("my_metric", "A simple gauge for testing")
    |> should.be_ok
  metric
  |> gauge.observe(
    label.new() |> label.add_label("foo", "bar") |> should.be_ok,
    number.Int(10),
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
  |> gauge.print("my_metric" |> metric.new_name([]) |> should.be_ok)
  |> should.equal(
    "# HELP my_metric A simple gauge for testing\n# TYPE my_metric gauge\n",
  )

  make_test_gauge(with_record: True)
  |> gauge.print("my_metric" |> metric.new_name([]) |> should.be_ok)
  |> should.equal(
    "# HELP my_metric A simple gauge for testing\n# TYPE my_metric gauge\nmy_metric{foo=\"bar\"} 10\n",
  )

  let init_record_labels =
    label.new()
    |> label.add_label("foo", "bar")
    |> should.be_ok
    |> label.add_label("toto", "tata")
    |> should.be_ok
    |> label.add_label("wibble", "wobble")
    |> should.be_ok

  make_test_gauge(with_record: True)
  |> gauge.observe(init_record_labels, number.Int(69))
  |> gauge.print("my_metric" |> metric.new_name([]) |> should.be_ok)
  |> should.equal(
    "# HELP my_metric A simple gauge for testing\n# TYPE my_metric gauge\nmy_metric{foo=\"bar\"} 10\nmy_metric{foo=\"bar\",toto=\"tata\",wibble=\"wobble\"} 69\n",
  )
}

fn make_test_gauge(
  with_record with_record: Bool,
) -> metric.Metric(gauge.Gauge, number.Number, Nil) {
  let records = case with_record {
    False -> dict.new()
    True -> {
      let labels = label.new() |> label.add_label("foo", "bar") |> should.be_ok
      dict.from_list([#(labels, number.Int(10))])
    }
  }
  metric.Metric("A simple gauge for testing", records, Nil)
}
