import gleam/dict
import gleam/io
import gleam/set
import gleeunit/should
import simplifile
import themis/counter
import themis/internal/label
import themis/internal/metric
import themis/internal/store
import themis/number

pub fn new_test() {
  let store = store.init()
  counter.new(store, "a_metric_total", "My first metric!")
  |> should.be_ok
  counter.new(store, "a_metric_total", "My second metric!")
  |> should.be_error
  |> should.equal(counter.StoreError(store.MetricNameAlreadyExists))
  counter.new(store, "a_metric", "My third metric!")
  |> should.be_error
  |> should.equal(counter.CounterNameShouldEndWithTotal)
}

pub fn increment_by_test() {
  let store = store.init()
  counter.new(store, "a_metric_total", "My first metric!")
  |> should.be_ok

  let labels =
    [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok

  let value1 = number.decimal(0.11)
  let value2 = number.integer(10)
  let value3 = number.decimal(0.001)

  counter.increment_by(store, "a_metric_total", labels, value1) |> should.be_ok
  counter.increment_by(store, "a_metric_total", labels, value2) |> should.be_ok
  counter.increment_by(store, "a_metric_total", labels, value3) |> should.be_ok

  counter.increment_by(store, "a_metric_total", labels, number.not_a_number())
  |> should.be_error
  |> should.equal(counter.InvalidIncrement(number.NaN))
  counter.increment_by(
    store,
    "a_metric_total",
    labels,
    number.positive_infinity(),
  )
  |> should.be_error
  |> should.equal(counter.InvalidIncrement(number.PosInf))
  counter.increment_by(
    store,
    "a_metric_total",
    labels,
    number.negative_infinity(),
  )
  |> should.be_error
  |> should.equal(counter.InvalidIncrement(number.NegInf))

  store.match_records(
    store,
    "a_metric_total" |> metric.new_name([]) |> should.be_ok,
  )
  |> should.be_ok
  |> should.equal([#(labels, number.decimal(10.111))] |> dict.from_list)
}

pub fn print_all_test() {
  let assert Ok(expected) =
    simplifile.read("test/test_cases/counter_print/expected.txt")
  let store = store.init()
  let labels =
    [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok
  let labels2 =
    [#("wibble", "wobble")] |> dict.from_list |> label.from_dict |> should.be_ok

  let value1 = number.decimal(0.11)
  let value2 = number.integer(10)
  let value3 = number.decimal(0.001)
  counter.new(store, "a_metric_total", "My first metric!")
  |> should.be_ok
  counter.new(store, "another_metric_total", "My second metric!")
  |> should.be_ok
  counter.new(store, "yet_another_metric_total", "My third metric!")
  |> should.be_ok

  counter.increment_by(store, "a_metric_total", labels, value1) |> should.be_ok
  counter.increment_by(store, "a_metric_total", labels2, value1) |> should.be_ok
  counter.increment_by(store, "a_metric_total", labels, value2) |> should.be_ok
  counter.increment_by(store, "another_metric_total", labels, value2)
  |> should.be_ok
  counter.increment_by(store, "yet_another_metric_total", labels, value3)
  |> should.be_ok

  counter.print_all(store) |> should.be_ok |> should.equal(expected)
}
