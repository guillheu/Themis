import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string_tree
import internal/label.{type LabelSet}
import internal/metric.{type Metric, Metric}
import internal/prometheus.{type Number, Dec, Int, NaN, NegInf, PosInf}

pub type Counter

pub type CounterError {
  RecordAlreadyExists
  RecordNotFound
}

pub fn new(description description: String) -> Metric(Counter, Number) {
  Metric(description, dict.new())
}

pub fn create_record(
  from from: Metric(Counter, Number),
  with_labels labels: LabelSet,
) -> Result(Metric(Counter, Number), CounterError) {
  use <- bool.guard(
    dict.has_key(from.records, labels),
    Error(RecordAlreadyExists),
  )
  Ok(
    Metric(
      ..from,
      records: from.records |> dict.insert(labels, prometheus.Int(0)),
    ),
  )
}

pub fn increment(
  from from: Metric(Counter, Number),
  labels labels: LabelSet,
) -> Result(Metric(Counter, Number), CounterError) {
  increment_by(from, labels, Int(1))
}

pub fn increment_by(
  from from: Metric(Counter, Number),
  labels labels: LabelSet,
  by by: Number,
) -> Result(Metric(Counter, Number), CounterError) {
  let new_val_result = case dict.get(from.records, labels) {
    Error(_) -> Error(RecordNotFound)
    Ok(number) ->
      case number, by {
        Int(first), Int(second) -> Ok(Int(first + second))
        Dec(first), Dec(second) -> Ok(Dec(float.add(first, second)))
        Dec(dec), Int(int) | Int(int), Dec(dec) ->
          Ok(Dec(float.add(int.to_float(int), dec)))
        PosInf, NegInf | NegInf, PosInf -> Ok(NaN)
        PosInf, _ | _, PosInf -> Ok(PosInf)
        NegInf, _ | _, NegInf -> Ok(NegInf)
        _, _ -> Ok(NaN)
      }
  }
  use new_val <- result.map(new_val_result)
  Metric(..from, records: from.records |> dict.insert(labels, new_val))
}

pub fn delete_record(
  from from: Metric(Counter, Number),
  labels labels: LabelSet,
) -> Metric(Counter, Number) {
  Metric(..from, records: dict.delete(from.records, labels))
}

pub fn print(
  metric metric: Metric(Counter, Number),
  name name: metric.MetricName,
) -> String {
  let name = metric.name_to_string(name)
  let help = "HELP " <> name <> " " <> metric.description
  let type_ = "TYPE " <> name <> " counter"
  {
    use current, labels, value <- dict.fold(metric.records, [
      help <> "\n" <> type_ <> "\n",
    ])
    [
      name <> label.print(labels) <> " " <> prometheus.print(value) <> "\n",
      ..current
    ]
  }
  |> list.reverse
  |> string_tree.from_strings
  |> string_tree.to_string
}
