import gleeunit/should
import themis/label

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
