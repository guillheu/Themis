import gleam/dict
import gleam/dynamic
import gleam/erlang/atom
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{None}
import gleeunit/should
import themis/internal/erlang/ets
import themis/number

pub fn counter_test() {
  let table = ets.new(ets.TableBuilder(ets.Set, ets.Private), "test_table")
  let table_info = ets.info(table)

  table_info
  |> should.equal(
    ets.TableInfo(
      ..table_info,
      decentralized_counters: False,
      read_concurrency: False,
      write_concurrency: False,
      compressed: False,
      memory: 305,
      owner: process.self(),
      heir: None,
      name: "test_table" |> atom.create_from_string,
      size: 0,
      node: "nonode@nohost" |> atom.create_from_string,
      named_table: False,
      table_type: ets.Set,
      keypos: 1,
      protection: ets.Private,
    ),
  )
  let labels = ["wibble:wobble"]
  ets.lookup(table, #("foo"))
  |> should.equal([])
  ets.counter_increment(table, #("foo"))
  check_entry(table, #("foo"), 1, 0.0, "")
  ets.counter_increment_by(table, #("foo"), number.integer(2))
  check_entry(table, #("foo"), 3, 0.0, "")
  ets.counter_increment_by(table, #("foo"), number.decimal(1.0))
  check_entry(table, #("foo"), 3, 1.0, "")
  ets.counter_increment_by(table, #("a_metric", labels), number.integer(1))
  check_entry(table, #("a_metric", labels), 1, 0.0, "")
  ets.insert_raw(
    table,
    #(#("a_metric", labels), 0, 0.0, "toto") |> dynamic.from,
  )
  ets.counter_increment_by(table, #("a_metric", labels), number.decimal(1.0))
  check_entry(table, #("a_metric", labels), 0, 1.0, "toto")
  ets.counter_increment_by(table, #("a_metric", labels), number.integer(10))
  check_entry(table, #("a_metric", labels), 10, 1.0, "toto")
}

pub type Something {
  Somewhere
  Somewhat
  Someone
}

pub fn match_metric_test() {
  let table = ets.new(ets.TableBuilder(ets.Set, ets.Private), "test_table")
  ets.insert_raw(table, #("foo", "lol", Somewhere, Nil) |> dynamic.from)
  ets.match_metric(table, Somewhere)
  |> should.equal(ets.lookup(table, "foo"))
  ets.insert_raw(table, #("bar", "xd", Somewhere, Somewhat) |> dynamic.from)
  ets.match_metric(table, Somewhere)
  |> should.equal(
    ets.lookup(table, "foo") |> list.append(ets.lookup(table, "bar")),
  )
  ets.insert_raw(table, #("baz", "mdr", Someone, Somewhat) |> dynamic.from)
  ets.match_metric(table, Somewhere)
  |> should.equal(
    ets.lookup(table, "foo") |> list.append(ets.lookup(table, "bar")),
  )
  ets.match_metric(table, Someone)
  |> should.equal(ets.lookup(table, "baz"))
}

pub fn match_record_test() {
  let table = ets.new(ets.TableBuilder(ets.Set, ets.Private), "test_table")
  let labels1 = dict.from_list([#("foo", "bar")])
  let labels2 = dict.from_list([#("wibble", "wobble")])
  let labels3 = dict.from_list([#("toto", "tata")])
  ets.insert_raw(
    table,
    #(#("a_metric_name", labels1), 10, 0.5, Nil) |> dynamic.from,
  )
  ets.match_record(table, "a_metric_name")
  |> should.equal(ets.lookup(table, #("a_metric_name", labels1)))

  ets.insert_raw(
    table,
    #(#("a_metric_name", labels2), 5, 10.6, Nil) |> dynamic.from,
  )
  ets.insert_raw(
    table,
    #(#("a_different_metric_name", labels3), 69, 4.2, Nil) |> dynamic.from,
  )

  ets.match_record(table, "a_metric_name")
  |> should.equal(
    ets.lookup(table, #("a_metric_name", labels1))
    |> list.append(ets.lookup(table, #("a_metric_name", labels2))),
  )
}

// pub fn gauge_test() {
//   let table = ets.new(ets.TableBuilder(ets.Set, ets.Private), "test_table")
//   let key = "foo"
//   let value1 = number.integer(2)
//   let value2 = number.decimal(0.5)
//   let value3 = number.decimal(10.0)
//   let value4 = number.positive_infinity()
//   let value5 = number.negative_infinity()
//   let value6 = number.not_a_number()
//   let value7 = number.integer(1)
//   ets.insert(table, key, value1)
//   ets.lookup(table, key)
//   |> should.equal([#("foo" |> dynamic.from, value1 |> dynamic.from)])
//   ets.insert(table, key, value2)
//   ets.lookup(table, key)
//   |> should.equal([#("foo" |> dynamic.from, value2 |> dynamic.from)])
//   ets.insert(table, key, value3)
//   ets.lookup(table, key)
//   |> should.equal([#("foo" |> dynamic.from, value3 |> dynamic.from)])
//   ets.insert(table, key, value4)
//   ets.lookup(table, key)
//   |> should.equal([#("foo" |> dynamic.from, value4 |> dynamic.from)])
//   ets.insert(table, key, value5)
//   ets.lookup(table, key)
//   |> should.equal([#("foo" |> dynamic.from, value5 |> dynamic.from)])
//   ets.insert(table, key, value6)
//   ets.lookup(table, key)
//   |> should.equal([#("foo" |> dynamic.from, value6 |> dynamic.from)])
//   ets.insert(table, key, value7)
//   ets.lookup(table, key)
//   |> should.equal([#("foo" |> dynamic.from, value7 |> dynamic.from)])
// }

fn check_entry(
  table: ets.Table,
  key: any,
  val_int: Int,
  val_float: Float,
  val_flag: String,
) {
  let assert [dyn] = ets.lookup(table, key)
  let #(k, value_int, value_float, flag) =
    dyn
    |> dynamic.tuple4(
      dynamic.dynamic,
      dynamic.int,
      dynamic.float,
      dynamic.string,
    )
    |> should.be_ok
  k
  |> should.equal(key |> dynamic.from)
  value_int
  |> should.equal(val_int)
  value_float
  |> should.equal(val_float)
  flag
  |> should.equal(val_flag)
}
