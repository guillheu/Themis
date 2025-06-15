import gleam/dict
import gleeunit/should
import simplifile
import themis/counter
import themis/internal/label
import themis/internal/metric
import themis/internal/store
import themis/number

pub fn new_test() {
  store.init()
  counter.new("a_metric_total", "My first metric!")
  |> should.be_ok
  counter.new("a_metric_total", "My second metric!")
  |> should.be_error
  |> should.equal(counter.StoreError(store.MetricNameAlreadyExists))
  counter.new("a_metric", "My third metric!")
  |> should.be_error
  |> should.equal(counter.CounterNameShouldEndWithTotal)
  store.clear()
}

pub fn increment_by_test() {
  store.init()
  counter.new("a_metric_total", "My first metric!")
  |> should.be_ok

  let labels =
    [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok

  let value1 = number.decimal(0.11)
  let value2 = number.integer(10)
  let value3 = number.decimal(0.001)

  counter.increment_by("a_metric_total", labels |> label.to_dict, value1)
  |> should.be_ok
  counter.increment_by("a_metric_total", labels |> label.to_dict, value2)
  |> should.be_ok
  counter.increment_by("a_metric_total", labels |> label.to_dict, value3)
  |> should.be_ok

  counter.increment_by(
    "a_metric_total",
    labels |> label.to_dict,
    number.not_a_number(),
  )
  |> should.be_error
  |> should.equal(counter.InvalidIncrement(number.NaN))
  counter.increment_by(
    "a_metric_total",
    labels |> label.to_dict,
    number.positive_infinity(),
  )
  |> should.be_error
  |> should.equal(counter.InvalidIncrement(number.PosInf))
  counter.increment_by(
    "a_metric_total",
    labels |> label.to_dict,
    number.negative_infinity(),
  )
  |> should.be_error
  |> should.equal(counter.InvalidIncrement(number.NegInf))

  store.match_records("a_metric_total" |> metric.new_name([]) |> should.be_ok)
  |> should.be_ok
  |> should.equal([#(labels, number.decimal(10.111))] |> dict.from_list)
  store.clear()
}

pub fn print_test() {
  let assert Ok(expected) =
    simplifile.read("test/test_cases/counter_print/expected.txt")
  store.init()
  let labels =
    [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok
  let labels2 = dict.new() |> label.from_dict |> should.be_ok

  let value1 = number.decimal(0.11)
  let value2 = number.integer(10)
  let value3 = number.decimal(0.001)
  counter.new("a_metric_total", "My first metric!")
  |> should.be_ok
  counter.new("another_metric_total", "My second metric!")
  |> should.be_ok
  counter.new("yet_another_metric_total", "My third metric!")
  |> should.be_ok

  counter.increment_by("a_metric_total", labels |> label.to_dict, value1)
  |> should.be_ok
  counter.increment_by("a_metric_total", labels2 |> label.to_dict, value1)
  |> should.be_ok
  counter.increment_by("a_metric_total", labels |> label.to_dict, value2)
  |> should.be_ok
  counter.increment_by("another_metric_total", labels |> label.to_dict, value2)
  |> should.be_ok
  counter.increment_by(
    "yet_another_metric_total",
    labels |> label.to_dict,
    value3,
  )
  |> should.be_ok

  assert counter.print() |> should.be_ok == expected
  store.clear()
}
