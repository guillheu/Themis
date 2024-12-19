import gleam/io
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import internal/prometheus
import simplifile

pub fn main() {
  gleeunit.main()
}

pub fn regex_names_test() {
  let assert Ok(valid_cases_content) =
    simplifile.read("test/test_cases/names/valid.txt")
  let assert Ok(invalid_cases_content) =
    simplifile.read("test/test_cases/names/invalid.txt")

  {
    use valid <- list.each(string.split(valid_cases_content, "\n"))
    prometheus.is_valid_name(valid) |> should.be_true
  }
  {
    use invalid <- list.each(string.split(invalid_cases_content, "\n"))
    prometheus.is_valid_name(invalid) |> should.be_false
  }
}

pub fn regex_labels_test() {
  let assert Ok(valid_cases_content) =
    simplifile.read("test/test_cases/labels/valid.txt")
  let assert Ok(invalid_cases_content) =
    simplifile.read("test/test_cases/labels/invalid.txt")

  {
    use valid <- list.each(string.split(valid_cases_content, "\n"))
    prometheus.is_valid_label(valid) |> should.be_true
  }
  {
    use invalid <- list.each(string.split(invalid_cases_content, "\n"))
    prometheus.is_valid_label(invalid) |> should.be_false
  }
}
