import gleam/io
import gleeunit
import gleeunit/should
import internal/prometheus
import themis
import themis/label
import themis/metric/gauge

pub fn main() {
  gleeunit.main()
}

pub fn themis_test() {
  // Testing the following:
  // "my_gauge" metric with 2 records: 
  //   instance=foo ; value 69
  //   instance=bar ; value 4.20
  // "your_gauge" metric with 2 records:
  //   name=toto ; value +Inf
  //   surname=tata ; value -Inf

  // HELP your_gauge Your first gauge
  // TYPE your_gauge gauge
  // your_gauge{name="toto"} +Inf
  // your_gauge{surname="tata"} -Inf
  //
  // HELP my_gauge My first gauge
  // TYPE my_gauge gauge
  // my_gauge{instance="bar"} 4.2
  // my_gauge{instance="foo"} 69
  //
  //
  let instance_foo =
    label.new() |> label.add_label("instance", "foo") |> should.be_ok
  let value_foo = 69 |> prometheus.Int
  let instance_bar =
    label.new() |> label.add_label("instance", "bar") |> should.be_ok
  let value_bar = 4.2 |> prometheus.Dec

  let my_gauge =
    gauge.new("my_gauge", "My first gauge")
    |> should.be_ok
    |> gauge.add_record(instance_foo, value_foo)
    |> gauge.add_record(instance_bar, value_bar)

  let name_toto = label.new() |> label.add_label("name", "toto") |> should.be_ok
  let value_toto = prometheus.PosInf
  let surname_tata =
    label.new() |> label.add_label("surname", "tata") |> should.be_ok
  let value_tata = prometheus.NegInf

  let your_gauge =
    gauge.new("your_gauge", "Your first gauge")
    |> should.be_ok
    |> gauge.add_record(name_toto, value_toto)
    |> gauge.add_record(surname_tata, value_tata)

  let store =
    themis.new()
    |> themis.add_gauge(my_gauge)
    |> should.be_ok
    |> themis.add_gauge(your_gauge)
    |> should.be_ok
    |> themis.print
    |> should.equal(
      "HELP your_gauge Your first gauge\nTYPE your_gauge gauge\nyour_gauge{name=\"toto\"} +Inf\nyour_gauge{surname=\"tata\"} -Inf\n\nHELP my_gauge My first gauge\nTYPE my_gauge gauge\nmy_gauge{instance=\"bar\"} 4.2\nmy_gauge{instance=\"foo\"} 69\n\n",
    )
}
