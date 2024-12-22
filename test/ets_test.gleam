import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process
import gleam/io
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
  ets.lookup(table, "foo")
  |> should.equal([])
  ets.counter_increment(table, "foo")

  check_entry_int(table, "foo", 1)
  ets.counter_increment_by(table, "foo", number.integer(2))
  check_entry_int(table, "foo", 3)
  ets.counter_increment_by(table, "foo", number.decimal(1.0))
  check_entry_float(table, "foo", 4.0)
  ets.counter_increment_by(table, "bar", number.decimal(0.5))
  check_entry_float(table, "bar", 0.5)
}

fn check_entry_int(table: ets.Table, key: String, val: Int) {
  let assert [#(k, value)] = ets.lookup(table, key)
  k
  |> decode.run(decode.string)
  |> should.be_ok
  |> should.equal(key)
  value
  |> decode.run(decode.int)
  |> should.be_ok
  |> should.equal(val)
}

fn check_entry_float(table: ets.Table, key: String, val: Float) {
  let assert [#(k, value)] = ets.lookup(table, key)
  k
  |> decode.run(decode.string)
  |> should.be_ok
  |> should.equal(key)
  value
  |> decode.run(decode.float)
  |> should.be_ok
  |> should.equal(val)
}
