import gleam/dict
import gleeunit
import gleeunit/should
import themis

pub fn main() {
  gleeunit.main()
}

pub fn store_insert_gauge_record_test() {
  let labels = [#("foo", "bar")] |> dict.from_list
  let other_labels =
    [#("toto", "tata"), #("wibble", "wobble")] |> dict.from_list
  let value = themis.int(10)
  let new_value = themis.pos_inf()
  let store =
    themis.new()
    |> themis.add_gauge("my_gauge", "My first gauge")
    |> should.be_ok
    |> themis.insert_gauge_record("my_gauge", labels, value)
    |> should.be_ok
    |> themis.insert_gauge_record("my_gauge", other_labels, value)
    |> should.be_ok

  store
  |> themis.print
  |> should.equal(
    "HELP my_gauge My first gauge\nTYPE my_gauge gauge\nmy_gauge{foo=\"bar\"} 10\nmy_gauge{toto=\"tata\",wibble=\"wobble\"} 10\n\n",
  )
  // HELP my_gauge My first gauge
  // TYPE my_gauge gauge
  // my_gauge{foo="bar"} 10
  // my_gauge{toto="tata",wibble="wobble"} 10

  store
  |> themis.insert_gauge_record("my_gauge", other_labels, new_value)
  |> should.be_ok
  |> themis.print
  |> should.equal(
    "HELP my_gauge My first gauge\nTYPE my_gauge gauge\nmy_gauge{foo=\"bar\"} 10\nmy_gauge{toto=\"tata\",wibble=\"wobble\"} +Inf\n\n",
  )
  // HELP my_gauge My first gauge
  // TYPE my_gauge gauge
  // my_gauge{foo="bar"} 10
  // my_gauge{toto="tata",wibble="wobble"} +Inf
}
