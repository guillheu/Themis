import gleam/dict
import gleam/set
import gleeunit
import gleeunit/should
import simplifile
import themis
import themis/counter
import themis/gauge
import themis/histogram
import themis/internal/label
import themis/internal/store
import themis/number

pub fn main() {
  gleeunit.main()
}

pub fn print_test() {
  let assert Ok(expected) =
    simplifile.read("test/test_cases/all_print/expected.txt")
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

  gauge.observe(store, "a_metric", labels |> label.to_dict, value1)
  |> should.be_ok
  gauge.observe(store, "a_metric", labels |> label.to_dict, value2)
  |> should.be_ok
  gauge.observe(store, "a_metric", labels |> label.to_dict, value3)
  |> should.be_ok
  gauge.observe(store, "a_metric", labels |> label.to_dict, value4)
  |> should.be_ok
  gauge.observe(store, "a_metric", labels |> label.to_dict, value5)
  |> should.be_ok

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

  counter.increment_by(store, "a_metric_total", labels |> label.to_dict, value1)
  |> should.be_ok
  counter.increment_by(
    store,
    "a_metric_total",
    labels2 |> label.to_dict,
    value1,
  )
  |> should.be_ok
  counter.increment_by(store, "a_metric_total", labels |> label.to_dict, value2)
  |> should.be_ok
  counter.increment_by(
    store,
    "another_metric_total",
    labels |> label.to_dict,
    value2,
  )
  |> should.be_ok
  counter.increment_by(
    store,
    "yet_another_metric_total",
    labels |> label.to_dict,
    value3,
  )
  |> should.be_ok

  let labels =
    [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok
  let labels2 =
    [#("wibble", "wobble")] |> dict.from_list |> label.from_dict |> should.be_ok

  let value1 = number.decimal(0.11)
  let value2 = number.integer(10)
  let value3 = number.decimal(0.001)

  let buckets =
    [
      number.decimal(0.01),
      number.decimal(0.025),
      number.decimal(0.05),
      number.decimal(0.1),
      number.decimal(0.25),
      number.decimal(0.5),
      number.decimal(1.0),
    ]
    |> set.from_list
  histogram.new(store, "a_history_metric", "My first metric!", buckets)
  |> should.be_ok
  histogram.new(store, "another_history_metric", "My second metric!", buckets)
  |> should.be_ok
  histogram.new(
    store,
    "yet_another_history_metric",
    "My third metric!",
    buckets,
  )
  |> should.be_ok
  histogram.observe(store, "a_history_metric", labels |> label.to_dict, value1)
  |> should.be_ok
  histogram.observe(store, "a_history_metric", labels |> label.to_dict, value2)
  |> should.be_ok
  histogram.observe(store, "a_history_metric", labels2 |> label.to_dict, value2)
  |> should.be_ok
  histogram.observe(
    store,
    "another_history_metric",
    labels |> label.to_dict,
    value2,
  )
  |> should.be_ok
  histogram.observe(
    store,
    "yet_another_history_metric",
    labels |> label.to_dict,
    value3,
  )
  |> should.be_ok

  themis.print(store) |> should.be_ok |> should.equal(expected)
}
