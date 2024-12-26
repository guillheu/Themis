import gleam/dict
import gleeunit/should
import simplifile
import themis/gauge
import themis/internal/label
import themis/internal/metric
import themis/internal/store
import themis/number

pub fn new_test() {
  let store = store.init()
  gauge.new(store, "a_metric", "My first metric!")
  |> should.be_ok
  gauge.new(store, "a_metric", "My second metric!")
  |> should.be_error
  |> should.equal(gauge.StoreError(store.MetricNameAlreadyExists))
}

pub fn observe_test() {
  let store = store.init()
  gauge.new(store, "a_metric", "My first metric!")
  |> should.be_ok

  let labels =
    [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok

  let value1 = number.decimal(0.11)
  let value2 = number.integer(10)
  let value3 = number.not_a_number()
  let value4 = number.positive_infinity()
  let value5 = number.negative_infinity()

  gauge.observe(store, "a_metric", labels, value1) |> should.be_ok
  store.match_records(store, "a_metric" |> metric.new_name([]) |> should.be_ok)
  |> should.be_ok
  |> should.equal([#(labels, value1)] |> dict.from_list)

  gauge.observe(store, "a_metric", labels, value2) |> should.be_ok
  store.match_records(store, "a_metric" |> metric.new_name([]) |> should.be_ok)
  |> should.be_ok
  |> should.equal([#(labels, value2)] |> dict.from_list)

  gauge.observe(store, "a_metric", labels, value3) |> should.be_ok
  store.match_records(store, "a_metric" |> metric.new_name([]) |> should.be_ok)
  |> should.be_ok
  |> should.equal([#(labels, value3)] |> dict.from_list)

  gauge.observe(store, "a_metric", labels, value4) |> should.be_ok
  store.match_records(store, "a_metric" |> metric.new_name([]) |> should.be_ok)
  |> should.be_ok
  |> should.equal([#(labels, value4)] |> dict.from_list)

  gauge.observe(store, "a_metric", labels, value5) |> should.be_ok
  store.match_records(store, "a_metric" |> metric.new_name([]) |> should.be_ok)
  |> should.be_ok
  |> should.equal([#(labels, value5)] |> dict.from_list)
}

pub fn print_all_test() {
  let assert Ok(expected) =
    simplifile.read("test/test_cases/gauge_print/expected.txt")
  let store = store.init()
  let labels =
    [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok
  let labels2 =
    [#("wibble", "wobble")] |> dict.from_list |> label.from_dict |> should.be_ok

  let value1 = number.decimal(0.11)
  let value2 = number.integer(10)
  let value3 = number.decimal(0.001)
  gauge.new(store, "a_metric", "My first metric!")
  |> should.be_ok
  gauge.new(store, "another_metric", "My second metric!")
  |> should.be_ok
  gauge.new(store, "yet_another_metric", "My third metric!")
  |> should.be_ok

  gauge.observe(store, "a_metric", labels, value1) |> should.be_ok
  gauge.observe(store, "a_metric", labels2, value1) |> should.be_ok
  gauge.observe(store, "another_metric", labels, value2)
  |> should.be_ok
  gauge.observe(store, "yet_another_metric", labels, value3)
  |> should.be_ok

  gauge.print_all(store) |> should.be_ok |> should.equal(expected)
}
