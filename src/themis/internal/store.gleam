import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import themis/internal/erlang/ets
import themis/internal/label.{type LabelSet}
import themis/internal/metric.{type MetricName}
import themis/number.{type Number}

pub type StoreError {
  MetricNameAlreadyExists
  InsertError
  DecodeErrors(List(decode.DecodeError))
  TableError
  InvalidIncrement
  SingleResultExpected
  InvalidType
  MetricNotFound
}

pub type Store {
  Store(metrics: ets.Table, records: ets.Table)
  //TODO: split the `records` table into 5 sub-tables:
  // - gauge_records
  // - counter_records
  // - histogram_bucket_records
  // - histogram_sum_records
  // - histogram_count_records
}

const metrics_table_name = "themis_metrics"

const records_table_name = "themis_records"

pub fn init() {
  let _metrics_table =
    ets.new(ets.TableBuilder(ets.Set, ets.Public), metrics_table_name)
  let _records_table =
    ets.new(ets.TableBuilder(ets.Set, ets.Public), records_table_name)
  // Store(metrics_table, records_table)
}

pub fn clear() {
  let _true = ets.delete_table(metrics_table_name)
  let _true = ets.delete_table(records_table_name)
}

pub fn new_metric(
  // store store: Store,
  name name: MetricName,
  description description: String,
  kind kind: String,
  buckets buckets: List(Float),
) -> Result(Nil, StoreError) {
  // let table = store.metrics
  ets.insert_new_raw(
    metrics_table_name,
    #(name |> metric.name_to_string, description, kind, buckets)
      |> dynamic.from,
  )
  |> result.replace_error(MetricNameAlreadyExists)
}

pub fn find_metric(
  // store store: Store,
  name name: MetricName,
  kind given_kind: String,
) -> Result(#(String, String, List(Float)), StoreError) {
  // let table = store.metrics
  let name_string = metric.name_to_string(name)
  let assert Ok(metrics) = ets.lookup(metrics_table_name, name_string)
    as {
    "could not find metric \""
    <> name_string
    <> "\". should only return an error if the given table name string is not found as an atom. Are you sure you initialized the Themis store ?"
  }
  use #(description, kind, buckets) <- result.try(
    case
      metrics
      |> list.map(fn(found) { decode_metric(found) })
    {
      [Ok(#(_name, description, kind, buckets))] ->
        Ok(#(description, kind, buckets))
      [] -> Error(MetricNotFound)
      _ -> Error(TableError)
    },
  )
  case kind == given_kind {
    False -> Error(InvalidType)
    True -> Ok(#(description, kind, buckets))
  }
}

pub fn match_metrics(
  // store store: Store,
  kind kind: String,
) -> Result(List(#(String, String, List(Float))), StoreError) {
  // let table = store.metrics
  let assert Ok(metrics) = ets.match_metric(metrics_table_name, kind)
    as "should only return an error if the given table name string is not found as an atom. Are you sure you initialized the Themis store ?"

  // A "metric" is a 4-tuple #(name, description, type, buckets (buckets only for histograms))
  list.map(metrics, fn(found) {
    let r =
      decode_metric(found)
      |> result.try_recover(fn(e) { Error(DecodeErrors(e)) })
    use #(name, description, _type, buckets) <- result.try(r)
    #(name, description, buckets)
    |> Ok
  })
  |> result.all
}

pub fn increment_record_by(
  // store store: Store,
  name name: MetricName,
  labels labels: LabelSet,
  by value: Number,
) -> Result(Nil, StoreError) {
  case value {
    number.Dec(_) | number.Int(_) ->
      {
        // let table = store.records
        let labels = label.to_strings(labels)
        let name = metric.name_to_string(name)
        let assert Ok(r) =
          ets.counter_increment_by(records_table_name, #(name, labels), value)
          as "should only return an error if the given table name string is not found as an atom. Are you sure you initialized the Themis store ?"
        r
      }
      |> Ok
    number.NaN | number.NegInf | number.PosInf -> Error(InvalidIncrement)
  }
}

pub fn increment_record(
  // store store: Store,
  name name: MetricName,
  labels labels: LabelSet,
) -> Result(Nil, StoreError) {
  increment_record_by(name, labels, number.integer(1))
}

pub fn insert_record(
  // store store: Store,
  name name: MetricName,
  labels labels: LabelSet,
  value value: Number,
) -> Result(Nil, StoreError) {
  // let table = store.records
  let labels = label.to_strings(labels)
  let #(int_value, float_value, flag_value) = case value {
    number.Dec(val) -> #(0, val, "")
    number.Int(val) -> #(val, 0.0, "")
    number.PosInf -> #(0, 0.0, "+Inf")
    number.NegInf -> #(0, 0.0, "-Inf")
    number.NaN -> #(0, 0.0, "NaN")
  }
  let assert Ok(r) =
    ets.insert_raw(records_table_name, #(
      #(name |> metric.name_to_string, labels),
      int_value,
      float_value,
      flag_value,
    ))
    as "should only return an error if the given table name string is not found as an atom. Are you sure you initialized the Themis store ?"

  case r {
    False -> Error(InsertError)
    True -> Ok(Nil)
  }
}

pub fn match_records(
  // store store: Store,
  metric_name name: metric.MetricName,
) -> Result(Dict(LabelSet, Number), StoreError) {
  // let table = store.records
  let assert Ok(records) =
    ets.match_record(records_table_name, name |> metric.name_to_string)
    as "should only return an error if the given table name string is not found as an atom. Are you sure you initialized the Themis store ?"

  records
  |> list.map(parse_record)
  |> result.all
  |> result.map(dict.from_list)
}

pub fn find_record(
  // store store: Store,
  metric_name name: metric.MetricName,
  labels labels: LabelSet,
) -> Result(#(LabelSet, number.Number), StoreError) {
  // let table = store.records

  let assert Ok(entries) =
    ets.lookup(records_table_name, #(
      name |> metric.name_to_string,
      labels |> label.to_strings,
    ))
    as "should only return an error if the given table name string is not found as an atom. Are you sure you initialized the Themis store ?"

  case entries {
    [entry] -> Ok(entry)
    _ -> Error(SingleResultExpected)
  }
  |> result.try(parse_record)
}

fn decode_metric(
  metric: dynamic.Dynamic,
) -> Result(#(String, String, String, List(Float)), List(decode.DecodeError)) {
  use field_1 <- result.try(decode.run(metric, decode.at([0], decode.string)))
  use field_2 <- result.try(decode.run(metric, decode.at([1], decode.string)))
  use field_3 <- result.try(decode.run(metric, decode.at([2], decode.string)))
  use field_4 <- result.try(decode.run(
    metric,
    decode.at([3], decode.list(decode.float)),
  ))
  Ok(#(field_1, field_2, field_3, field_4))
}

fn decode_record(
  record: dynamic.Dynamic,
) -> Result(
  #(#(String, List(String)), Int, Float, String),
  List(decode.DecodeError),
) {
  use field_1_1 <- result.try(decode.run(
    record,
    decode.at([0, 0], decode.string),
  ))
  use field_1_2 <- result.try(decode.run(
    record,
    decode.at([0, 1], decode.list(decode.string)),
  ))
  use field_2 <- result.try(decode.run(record, decode.at([1], decode.int)))
  use field_3 <- result.try(decode.run(record, decode.at([2], decode.float)))
  use field_4 <- result.try(decode.run(record, decode.at([3], decode.string)))
  Ok(#(#(field_1_1, field_1_2), field_2, field_3, field_4))
}

fn parse_record(
  record: dynamic.Dynamic,
) -> Result(#(LabelSet, Number), StoreError) {
  // A "record" is a 4-tuple #(#(name, labels), int_value, float_value, flag)
  // labels are a list of string. a key-value label is a single string: "key:value"
  let record_result =
    decode_record(record)
    // let record_result =
    //   dynamic.tuple4(
    //     dynamic.tuple2(dynamic.string, dynamic.list(dynamic.string)),
    //     dynamic.int,
    //     dynamic.float,
    //     dynamic.string,
    //   )(record)
    |> result.try_recover(fn(e) { Error(DecodeErrors(e)) })
  use record <- result.try(record_result)
  let #(#(_name, labels), int_value, float_value, flag) = record
  let assert Ok(float_decimal) = float.modulo(float_value, 1.0)
  let numeric_value = case float_decimal == 0.0 {
    False -> number.decimal(int_value |> int.to_float |> float.add(float_value))
    True -> number.integer(int_value)
  }
  let value = case flag {
    "-Inf" -> number.negative_infinity()
    "+Inf" -> number.positive_infinity()
    "NaN" -> number.not_a_number()
    _ -> numeric_value
  }
  let labels =
    labels
    |> list.map(fn(label_string) {
      let assert Ok(#(key, value)) = string.split_once(label_string, ":")
      #(key, value)
    })
    |> dict.from_list
  let assert Ok(labels) = label.from_dict(labels)
  #(labels, value)
  |> Ok
}
