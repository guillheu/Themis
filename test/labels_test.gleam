import gleam/dict
import gleeunit/should
import themis/internal/label

pub fn print_test() {
  label.new()
  |> label.add_label("foo", "bar")
  |> should.be_ok
  |> label.add_label("toto", "tata")
  |> should.be_ok
  |> label.add_label("wibble", "wobble")
  |> should.be_ok
  |> label.print
  |> should.equal("{foo=\"bar\",toto=\"tata\",wibble=\"wobble\"}")
}

pub fn from_dict_test() {
  let from =
    [#("foo", "bar"), #("toto", "tata"), #("wibble", "wobble")]
    |> dict.from_list

  label.from_dict(from)
  |> should.be_ok

  // Should fail
  let from =
    [#("invalid name", "irrelevant value")]
    |> dict.from_list

  label.from_dict(from)
  |> should.be_error
  |> should.equal(label.InvalidLabelName)
}
