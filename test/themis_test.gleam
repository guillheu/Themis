import gleam/dict
import gleam/set
import gleeunit
import gleeunit/should
import themis
import themis/counter
import themis/gauge
import themis/histogram
import themis/number

pub fn main() {
  gleeunit.main()
}

pub fn store_gauge_record_test() {
  let labels = [#("foo", "bar")] |> dict.from_list
  let other_labels =
    [#("toto", "tata"), #("wibble", "wobble")] |> dict.from_list
  let value = number.integer(10)
  let new_value = number.positive_infinity()
  let store =
    themis.new()
    |> gauge.register("my_metric", "My first gauge")
    |> should.be_ok
    |> gauge.observe("my_metric", labels, value)
    |> should.be_ok
    |> gauge.observe("my_metric", other_labels, value)
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
  |> gauge.observe("my_metric", other_labels, new_value)
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
  let increment_by = number.integer(10)
  // let new_value = number.positive_infinity()
  let store =
    themis.new()
    |> counter.register("my_metric", "My first counter")
    |> should.be_ok
    |> counter.increment("my_metric", labels)
    |> should.be_ok
    |> counter.init_record("my_metric", other_labels)
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
  |> counter.increment_by("my_metric", other_labels, increment_by)
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

pub fn store_histogram_record_test() {
  let labels = [#("foo", "bar")] |> dict.from_list
  let other_labels =
    [#("toto", "tata"), #("wibble", "wobble")] |> dict.from_list
  let value1 = number.integer(1)
  let value2 = number.decimal(1.5)
  let value3 = number.integer(100)

  let buckets = set.from_list([number.integer(1), number.integer(2)])

  let store =
    themis.new()
    |> histogram.register("my_metric", "My first histogram", buckets)
    |> should.be_ok
    |> histogram.observe("my_metric", labels, value1)
    |> should.be_ok
    |> histogram.observe("my_metric", labels, value2)
    |> should.be_ok
    |> histogram.init_record("my_metric", other_labels)
    |> should.be_ok

  store
  |> themis.print
  |> should.equal(
    "# HELP my_metric My first histogram\n# TYPE my_metric histogram\nmy_metric_bucket{foo=\"bar\",le=\"1\"} 1\nmy_metric_bucket{foo=\"bar\",le=\"2\"} 2\nmy_metric_bucket{foo=\"bar\",le=\"+Inf\"} 2\nmy_metric_sum{foo=\"bar\"} 2\nmy_metric_count{foo=\"bar\"} 2\n\nmy_metric_bucket{le=\"1\",toto=\"tata\",wibble=\"wobble\"} 0\nmy_metric_bucket{le=\"2\",toto=\"tata\",wibble=\"wobble\"} 0\nmy_metric_bucket{le=\"+Inf\",toto=\"tata\",wibble=\"wobble\"} 0\nmy_metric_sum{toto=\"tata\",wibble=\"wobble\"} 0\nmy_metric_count{toto=\"tata\",wibble=\"wobble\"} 0\n\n\n",
  )

  // # HELP my_metric My first histogram
  // # TYPE my_metric histogram
  // my_metric_bucket{foo="bar",le="1"} 1
  // my_metric_bucket{foo="bar",le="2"} 2
  // my_metric_bucket{foo="bar",le="+Inf"} 2
  // my_metric_sum{foo="bar"} 2
  // my_metric_count{foo="bar"} 2

  // my_metric_bucket{le="1",toto="tata",wibble="wobble"} 0
  // my_metric_bucket{le="2",toto="tata",wibble="wobble"} 0
  // my_metric_bucket{le="+Inf",toto="tata",wibble="wobble"} 0
  // my_metric_sum{toto="tata",wibble="wobble"} 0
  // my_metric_count{toto="tata",wibble="wobble"} 0

  store
  |> histogram.observe("my_metric", other_labels, value1)
  |> should.be_ok
  |> themis.print
  |> should.equal(
    "# HELP my_metric My first histogram\n# TYPE my_metric histogram\nmy_metric_bucket{foo=\"bar\",le=\"1\"} 1\nmy_metric_bucket{foo=\"bar\",le=\"2\"} 2\nmy_metric_bucket{foo=\"bar\",le=\"+Inf\"} 2\nmy_metric_sum{foo=\"bar\"} 2\nmy_metric_count{foo=\"bar\"} 2\n\nmy_metric_bucket{le=\"1\",toto=\"tata\",wibble=\"wobble\"} 1\nmy_metric_bucket{le=\"2\",toto=\"tata\",wibble=\"wobble\"} 1\nmy_metric_bucket{le=\"+Inf\",toto=\"tata\",wibble=\"wobble\"} 1\nmy_metric_sum{toto=\"tata\",wibble=\"wobble\"} 1\nmy_metric_count{toto=\"tata\",wibble=\"wobble\"} 1\n\n\n",
  )
  // # HELP my_metric My first histogram
  // # TYPE my_metric histogram
  // my_metric_bucket{foo="bar",le="1"} 1
  // my_metric_bucket{foo="bar",le="2"} 2
  // my_metric_bucket{foo="bar",le="+Inf"} 2
  // my_metric_sum{foo="bar"} 2
  // my_metric_count{foo="bar"} 2

  // my_metric_bucket{le="1",toto="tata",wibble="wobble"} 1
  // my_metric_bucket{le="2",toto="tata",wibble="wobble"} 1
  // my_metric_bucket{le="+Inf",toto="tata",wibble="wobble"} 1
  // my_metric_sum{toto="tata",wibble="wobble"} 1
  // my_metric_count{toto="tata",wibble="wobble"} 1
}

pub fn store_full_test() {
  let labels = [#("foo", "bar")] |> dict.from_list
  let other_labels =
    [#("toto", "tata"), #("wibble", "wobble")] |> dict.from_list

  // Creating Counter
  let store =
    themis.new()
    |> counter.register("my_cou_metric", "My first counter")
    |> should.be_ok
    |> counter.increment("my_cou_metric", labels)
    |> should.be_ok
    |> counter.init_record("my_cou_metric", other_labels)
    |> should.be_ok

  let value1 = number.integer(1)
  let value2 = number.decimal(1.5)
  let value3 = number.integer(100)

  let buckets = set.from_list([number.integer(1), number.integer(2)])

  // Creating histogram
  let store =
    store
    |> histogram.register("my_his_metric", "My first histogram", buckets)
    |> should.be_ok
    |> histogram.observe("my_his_metric", labels, value1)
    |> should.be_ok
    |> histogram.observe("my_his_metric", labels, value2)
    |> should.be_ok
    |> histogram.observe("my_his_metric", other_labels, value3)
    |> should.be_ok

  // Creating gauge

  let value = number.integer(10)
  let new_value = number.positive_infinity()
  let store =
    store
    |> gauge.register("my_gau_metric", "My first gauge")
    |> should.be_ok
    |> gauge.observe("my_gau_metric", labels, value)
    |> should.be_ok
    |> gauge.observe("my_gau_metric", other_labels, new_value)
    |> should.be_ok

  // printing result
  store
  |> themis.print
  |> should.equal(
    "# HELP my_gau_metric My first gauge\n# TYPE my_gau_metric gauge\nmy_gau_metric{foo=\"bar\"} 10\nmy_gau_metric{toto=\"tata\",wibble=\"wobble\"} +Inf\n\n# HELP my_cou_metric_total My first counter\n# TYPE my_cou_metric_total counter\nmy_cou_metric_total{foo=\"bar\"} 1\nmy_cou_metric_total{toto=\"tata\",wibble=\"wobble\"} 0\n\n# HELP my_his_metric My first histogram\n# TYPE my_his_metric histogram\nmy_his_metric_bucket{foo=\"bar\",le=\"1\"} 1\nmy_his_metric_bucket{foo=\"bar\",le=\"2\"} 2\nmy_his_metric_bucket{foo=\"bar\",le=\"+Inf\"} 2\nmy_his_metric_sum{foo=\"bar\"} 2\nmy_his_metric_count{foo=\"bar\"} 2\n\nmy_his_metric_bucket{le=\"1\",toto=\"tata\",wibble=\"wobble\"} 0\nmy_his_metric_bucket{le=\"2\",toto=\"tata\",wibble=\"wobble\"} 0\nmy_his_metric_bucket{le=\"+Inf\",toto=\"tata\",wibble=\"wobble\"} 1\nmy_his_metric_sum{toto=\"tata\",wibble=\"wobble\"} 1\nmy_his_metric_count{toto=\"tata\",wibble=\"wobble\"} 1\n\n\n",
  )
  // # HELP my_gau_metric My first gauge
  // # TYPE my_gau_metric gauge
  // my_gau_metric{foo="bar"} 10
  // my_gau_metric{toto="tata",wibble="wobble"} +Inf

  // # HELP my_cou_metric_total My first counter
  // # TYPE my_cou_metric_total counter
  // my_cou_metric_total{foo="bar"} 1
  // my_cou_metric_total{toto="tata",wibble="wobble"} 0

  // # HELP my_his_metric My first histogram
  // # TYPE my_his_metric histogram
  // my_his_metric_bucket{foo="bar",le="1"} 1
  // my_his_metric_bucket{foo="bar",le="2"} 2
  // my_his_metric_bucket{foo="bar",le="+Inf"} 2
  // my_his_metric_sum{foo="bar"} 2
  // my_his_metric_count{foo="bar"} 2

  // my_his_metric_bucket{le="1",toto="tata",wibble="wobble"} 0
  // my_his_metric_bucket{le="2",toto="tata",wibble="wobble"} 0
  // my_his_metric_bucket{le="+Inf",toto="tata",wibble="wobble"} 1
  // my_his_metric_sum{toto="tata",wibble="wobble"} 1
  // my_his_metric_count{toto="tata",wibble="wobble"} 1
}
