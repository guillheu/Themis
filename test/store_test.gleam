import gleam/dict
import gleam/dynamic
import gleeunit/should
import themis/internal/erlang/ets
import themis/internal/label
import themis/internal/metric
import themis/internal/store
import themis/number

pub fn new_metric_test() {
  let _store = store.init()
  let name = "a_name" |> metric.new_name([]) |> should.be_ok
  let name2 = "another_name" |> metric.new_name([]) |> should.be_ok
  store.new_metric(name, "a metric", "gauge", []) |> should.be_ok
  store.new_metric(name, "a metric", "gauge", []) |> should.be_error
  store.new_metric(name2, "a metric", "gauge", []) |> should.be_ok
  store.clear()
}

pub fn match_metrics_test() {
  let _store = store.init()
  store.new_metric(
    "a_name" |> metric.new_name([]) |> should.be_ok,
    "a new metric",
    "gauge",
    [],
  )
  |> should.be_ok
  store.new_metric(
    "another_name" |> metric.new_name([]) |> should.be_ok,
    "a new metric",
    "histogram",
    [0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0],
  )
  |> should.be_ok
  store.new_metric(
    "yet_another_name" |> metric.new_name([]) |> should.be_ok,
    "a new metric",
    "gauge",
    [],
  )
  |> should.be_ok

  store.match_metrics("gauge")
  |> should.be_ok
  |> should.equal([
    #("yet_another_name", "a new metric", []),
    #("a_name", "a new metric", []),
  ])
  store.match_metrics("histogram")
  |> should.be_ok
  |> should.equal([
    #("another_name", "a new metric", [0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0]),
  ])
  store.match_metrics("counter")
  |> should.be_ok
  |> should.equal([])
  store.clear()
}

pub fn match_records_test() {
  let _store = store.init()
  let labels1 =
    [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok
  let labels2 =
    [#("wibble", "wobble")] |> dict.from_list |> label.from_dict |> should.be_ok
  let labels3 =
    [#("toto", "tata")] |> dict.from_list |> label.from_dict |> should.be_ok

  let value1 = number.integer(10)
  let value2 = number.decimal(20.1)
  let value3 = number.positive_infinity()

  let name1 = "a_metric" |> metric.new_name([]) |> should.be_ok
  let name2 = "a_metric" |> metric.new_name([]) |> should.be_ok
  let name3 = "another_metric" |> metric.new_name([]) |> should.be_ok

  // insert 1st value

  store.insert_record(name1, labels1, value1) |> should.be_ok
  ets.lookup("themis_records", #(
    name1 |> metric.name_to_string,
    labels1 |> label.to_strings,
  ))
  |> should.be_ok
  |> should.equal([
    #(#("a_metric", ["foo:bar"]), 10, 0.0, "")
    |> dynamic.from,
  ])
  store.match_records(name1)
  |> should.be_ok
  |> should.equal(
    [
      #(
        dict.from_list([#("foo", "bar")]) |> label.from_dict |> should.be_ok,
        number.Int(10),
      ),
    ]
    |> dict.from_list,
  )

  // insert 2nd value

  store.insert_record(name2, labels2, value2) |> should.be_ok
  ets.lookup("themis_records", #(
    name2 |> metric.name_to_string,
    labels2 |> label.to_strings,
  ))
  |> should.be_ok
  |> should.equal([
    #(#("a_metric", ["wibble:wobble"]), 0, 20.1, "")
    |> dynamic.from,
  ])
  store.match_records(name2)
  |> should.be_ok
  |> should.equal(
    [
      #(
        dict.from_list([#("wibble", "wobble")])
          |> label.from_dict
          |> should.be_ok,
        number.Dec(20.1),
      ),
      #(
        dict.from_list([#("foo", "bar")]) |> label.from_dict |> should.be_ok,
        number.Int(10),
      ),
    ]
    |> dict.from_list,
  )
  // insert 3rd value

  store.insert_record(name3, labels3, value3) |> should.be_ok
  ets.lookup("themis_records", #(
    name3 |> metric.name_to_string,
    labels3 |> label.to_strings,
  ))
  |> should.be_ok
  |> should.equal([
    #(#("another_metric", ["toto:tata"]), 0, 0.0, "+Inf")
    |> dynamic.from,
  ])
  store.match_records(name3)
  |> should.be_ok
  |> should.equal(
    [
      #(
        dict.from_list([#("toto", "tata")]) |> label.from_dict |> should.be_ok,
        number.PosInf,
      ),
    ]
    |> dict.from_list,
  )
  store.clear()
}

pub fn increment_record_by_test() {
  let _store = store.init()
  let name = "a_name" |> metric.new_name([]) |> should.be_ok
  store.new_metric(name, "a metric", "gauge", []) |> should.be_ok

  let labels =
    [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok

  store.insert_record(name, labels, number.integer(10)) |> should.be_ok

  store.increment_record_by(name, labels, number.decimal(10.1))
  |> should.be_ok
  store.match_records(name)
  |> should.be_ok
  |> should.equal([#(labels, number.decimal(20.1))] |> dict.from_list)
  store.increment_record_by(name, labels, number.decimal(5.5))
  |> should.be_ok
  store.match_records(name)
  |> should.be_ok
  |> should.equal([#(labels, number.decimal(25.6))] |> dict.from_list)
  store.clear()
}
