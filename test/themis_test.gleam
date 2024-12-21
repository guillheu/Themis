// import internal/metric/counter
import gleam/dict
import gleam/io
import gleeunit
import gleeunit/should
import themis
import themis/counter
import themis/gauge
import themis/number

pub fn main() {
  gleeunit.main()
}

pub fn store_gauge_record_test() {
  let labels = [#("foo", "bar")] |> dict.from_list
  let other_labels =
    [#("toto", "tata"), #("wibble", "wobble")] |> dict.from_list
  let value = number.int(10)
  let new_value = number.pos_inf()
  let store =
    themis.new()
    |> gauge.register("my_metric", "My first gauge")
    |> should.be_ok
    |> gauge.insert_record("my_metric", labels, value)
    |> should.be_ok
    |> gauge.insert_record("my_metric", other_labels, value)
    |> should.be_ok

  store
  |> themis.print
  |> should.equal(
    "# HELP my_metric My first gauge\n# TYPE my_metric gauge\nmy_metric{foo=\"bar\"} 10\nmy_metric{toto=\"tata\",wibble=\"wobble\"} 10\n\n",
  )
  // # HELP my_metric My first gauge
  // # TYPE my_metric gauge
  // my_metric{foo="bar"} 10
  // my_metric{toto="tata",wibble="wobble"} 10

  store
  |> gauge.insert_record("my_metric", other_labels, new_value)
  |> should.be_ok
  |> themis.print
  |> should.equal(
    "# HELP my_metric My first gauge\n# TYPE my_metric gauge\nmy_metric{foo=\"bar\"} 10\nmy_metric{toto=\"tata\",wibble=\"wobble\"} +Inf\n\n",
  )
  // # HELP my_metric My first gauge
  // # TYPE my_metric gauge
  // my_metric{foo="bar"} 10
  // my_metric{toto="tata",wibble="wobble"} +Inf
}

pub fn store_counter_record_test() {
  let labels = [#("foo", "bar")] |> dict.from_list
  let other_labels =
    [#("toto", "tata"), #("wibble", "wobble")] |> dict.from_list
  let increment_by = number.int(10)
  // let new_value = number.pos_inf()
  let store =
    themis.new()
    |> counter.register("my_metric", "My first counter")
    |> should.be_ok
    |> counter.create_record("my_metric", labels)
    |> should.be_ok
    |> counter.increment_record("my_metric", labels)
    |> should.be_ok
    |> counter.create_record("my_metric", other_labels)
    |> should.be_ok

  store
  |> themis.print
  // |> io.debug
  |> should.equal(
    "# HELP my_metric_total My first counter\n# TYPE my_metric_total counter\nmy_metric_total{foo=\"bar\"} 1\nmy_metric_total{toto=\"tata\",wibble=\"wobble\"} 0\n\n",
  )

  // # HELP my_metric_total My first counter
  // # TYPE my_metric_total counter
  // my_metric_total{foo="bar"} 1
  // my_metric_total{toto="tata",wibble="wobble"} 0

  store
  |> counter.increment_record_by("my_metric", other_labels, increment_by)
  |> should.be_ok
  |> themis.print
  |> should.equal(
    "# HELP my_metric_total My first counter\n# TYPE my_metric_total counter\nmy_metric_total{foo=\"bar\"} 1\nmy_metric_total{toto=\"tata\",wibble=\"wobble\"} 10\n\n",
  )
  // # HELP my_metric_total My first counter
  // # TYPE my_metric_total counter
  // my_metric_total{foo="bar"} 1
  // my_metric_total{toto="tata",wibble="wobble"} 10
}
