import gleam/dict
import gleam/set
import gleeunit/should
import simplifile
import themis/histogram
import themis/internal/label
import themis/internal/metric
import themis/internal/store
import themis/number

pub fn new_test() {
  store.init()
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
  histogram.new("a_metric", "My first metric!", buckets)
  |> should.be_ok
  histogram.new("a_metric", "My first metric!", buckets)
  |> should.be_error
  |> should.equal(histogram.StoreError(store.MetricNameAlreadyExists))

  histogram.new(
    "another_metric",
    "My first metric!",
    buckets |> set.union([number.positive_infinity()] |> set.from_list),
  )
  |> should.be_error
  |> should.equal(histogram.InvalidBucketValue)
  store.clear()
}

pub fn observe_test() {
  let store = store.init()
  let name = "a_metric"
  let #(bucket_name, count_name, sum_name) =
    metric.make_histogram_metric_names(
      name |> metric.new_name([]) |> should.be_ok,
    )
  let labels =
    [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok

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
  histogram.new(name, "My first metric!", buckets)
  |> should.be_ok
  histogram.observe(name, labels |> label.to_dict, value1)
  |> should.be_ok
  store.match_records(bucket_name)
  |> should.be_ok
  |> should.equal(
    [
      #(
        [#("foo", "bar"), #("le", "0.01")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(0),
      ),
      #(
        [#("foo", "bar"), #("le", "0.025")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(0),
      ),
      #(
        [#("foo", "bar"), #("le", "0.05")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(0),
      ),
      #(
        [#("foo", "bar"), #("le", "0.1")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(0),
      ),
      #(
        [#("foo", "bar"), #("le", "0.5")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
      #(
        [#("foo", "bar"), #("le", "0.25")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
      #(
        [#("foo", "bar"), #("le", "0.5")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
      #(
        [#("foo", "bar"), #("le", "1")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
      #(
        [#("foo", "bar"), #("le", "+Inf")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
    ]
    |> dict.from_list,
  )

  store.match_records(count_name)
  |> should.be_ok
  |> should.equal(
    [
      #(
        [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok,
        number.integer(1),
      ),
    ]
    |> dict.from_list,
  )

  store.match_records(sum_name)
  |> should.be_ok
  |> should.equal(
    [
      #(
        [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok,
        number.decimal(0.11),
      ),
    ]
    |> dict.from_list,
  )

  histogram.observe(name, labels |> label.to_dict, value2)
  |> should.be_ok
  store.match_records(bucket_name)
  |> should.be_ok
  |> should.equal(
    [
      #(
        [#("foo", "bar"), #("le", "0.01")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(0),
      ),
      #(
        [#("foo", "bar"), #("le", "0.025")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(0),
      ),
      #(
        [#("foo", "bar"), #("le", "0.05")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(0),
      ),
      #(
        [#("foo", "bar"), #("le", "0.1")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(0),
      ),
      #(
        [#("foo", "bar"), #("le", "0.5")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
      #(
        [#("foo", "bar"), #("le", "0.25")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
      #(
        [#("foo", "bar"), #("le", "0.5")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
      #(
        [#("foo", "bar"), #("le", "1")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
      #(
        [#("foo", "bar"), #("le", "+Inf")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(2),
      ),
    ]
    |> dict.from_list,
  )

  store.match_records(count_name)
  |> should.be_ok
  |> should.equal(
    [
      #(
        [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok,
        number.integer(2),
      ),
    ]
    |> dict.from_list,
  )

  store.match_records(sum_name)
  |> should.be_ok
  |> should.equal(
    [
      #(
        [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok,
        number.decimal(10.11),
      ),
    ]
    |> dict.from_list,
  )

  histogram.observe(name, labels |> label.to_dict, value3)
  |> should.be_ok
  store.match_records(bucket_name)
  |> should.be_ok
  |> should.equal(
    [
      #(
        [#("foo", "bar"), #("le", "0.01")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
      #(
        [#("foo", "bar"), #("le", "0.025")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
      #(
        [#("foo", "bar"), #("le", "0.05")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
      #(
        [#("foo", "bar"), #("le", "0.1")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(1),
      ),
      #(
        [#("foo", "bar"), #("le", "0.5")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(2),
      ),
      #(
        [#("foo", "bar"), #("le", "0.25")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(2),
      ),
      #(
        [#("foo", "bar"), #("le", "0.5")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(2),
      ),
      #(
        [#("foo", "bar"), #("le", "1")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(2),
      ),
      #(
        [#("foo", "bar"), #("le", "+Inf")]
          |> dict.from_list
          |> label.from_dict
          |> should.be_ok,
        number.integer(3),
      ),
    ]
    |> dict.from_list,
  )

  store.match_records(count_name)
  |> should.be_ok
  |> should.equal(
    [
      #(
        [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok,
        number.integer(3),
      ),
    ]
    |> dict.from_list,
  )

  store.match_records(sum_name)
  |> should.be_ok
  |> should.equal(
    [
      #(
        [#("foo", "bar")] |> dict.from_list |> label.from_dict |> should.be_ok,
        number.decimal(10.111),
      ),
    ]
    |> dict.from_list,
  )
  store.clear()
}

pub fn print_test() {
  let assert Ok(expected) =
    simplifile.read("test/test_cases/histogram_print/expected.txt")
  store.init()
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
  histogram.new("a_metric", "My first metric!", buckets)
  |> should.be_ok
  histogram.new("another_metric", "My second metric!", buckets)
  |> should.be_ok
  histogram.new("yet_another_metric", "My third metric!", buckets)
  |> should.be_ok
  histogram.observe("a_metric", labels |> label.to_dict, value1)
  |> should.be_ok
  histogram.observe("a_metric", labels |> label.to_dict, value2)
  |> should.be_ok
  histogram.observe("a_metric", labels2 |> label.to_dict, value2)
  |> should.be_ok
  histogram.observe("another_metric", labels |> label.to_dict, value2)
  |> should.be_ok
  histogram.observe("yet_another_metric", labels |> label.to_dict, value3)
  |> should.be_ok

  histogram.print() |> should.be_ok |> should.equal(expected)
  store.clear()
}
