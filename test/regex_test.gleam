import gleam/list
import gleam/string
import gleeunit/should
import internal/label
import internal/metric
import simplifile

pub fn names_test() {
  let assert Ok(valid_cases_content) =
    simplifile.read("test/test_cases/names/valid.txt")
  let assert Ok(invalid_cases_content) =
    simplifile.read("test/test_cases/names/invalid.txt")

  {
    use valid <- list.each(string.split(valid_cases_content, "\n"))
    metric.is_valid_name(valid) |> should.be_true
  }
  {
    use invalid <- list.each(string.split(invalid_cases_content, "\n"))
    metric.is_valid_name(invalid) |> should.be_false
  }
}

pub fn labels_test() {
  let assert Ok(valid_cases_content) =
    simplifile.read("test/test_cases/labels/valid.txt")
  let assert Ok(invalid_cases_content) =
    simplifile.read("test/test_cases/labels/invalid.txt")

  {
    use valid <- list.each(string.split(valid_cases_content, "\n"))
    label.is_valid_label(valid) |> should.be_true
  }
  {
    use invalid <- list.each(string.split(invalid_cases_content, "\n"))
    label.is_valid_label(invalid) |> should.be_false
  }
}
