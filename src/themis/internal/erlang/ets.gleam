import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/io
import gleam/option.{type Option}
import themis/number

pub type TableBuilder {
  TableBuilder(table_type: TableType, table_access: TableAccess)
}

pub type Table

pub type TableType {
  Set
  OrderedSet
  Bag
  DuplicateBag
}

pub type TableInfo {
  TableInfo(
    id: Tid,
    decentralized_counters: Bool,
    read_concurrency: Bool,
    write_concurrency: Bool,
    compressed: Bool,
    memory: Int,
    owner: Pid,
    heir: Option(Pid),
    name: Atom,
    size: Int,
    node: Atom,
    named_table: Bool,
    table_type: TableType,
    keypos: Int,
    protection: TableAccess,
  )
}

pub type TableAccess {
  Public
  Protected
  Private
}

pub type Tid

pub fn new(builder: TableBuilder, name: String) -> Table {
  atom.create_from_string(name)
  |> do_new(builder.table_type, builder.table_access)
}

pub fn info(table: Table) -> TableInfo {
  let r = do_info(table)
  TableInfo(
    r.0.1,
    r.1.1,
    r.2.1,
    r.3.1,
    r.4.1,
    r.5.1,
    r.6.1,
    r.7.1,
    r.8.1,
    r.9.1,
    r.10.1,
    r.11.1,
    r.12.1,
    r.13.1,
    r.14.1,
  )
}

pub fn insert(table: Table, key: key, value: value) -> Bool {
  do_insert(table, #(key, value) |> dynamic.from)
}

pub fn insert_new_raw(table: Table, object: Dynamic) -> Result(Nil, Nil) {
  let r = do_insert_new(table, object)
  case r |> dynamic.bool {
    Error(_) -> Error(Nil)
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(Nil)
  }
}

pub fn insert_many(table: Table, to_insert: Dict(key, value)) -> Bool {
  let objects =
    dict.to_list(to_insert)
    |> dynamic.from
  do_insert(table, objects)
}

pub fn insert_raw(table: Table, object: any) -> Bool {
  do_insert(table, object)
}

pub fn lookup(table: Table, key: key) -> List(Dynamic) {
  do_lookup(table, key)
}

@external(erlang, "themis_external", "new")
fn do_new(name: Atom, table_type: TableType, table_access: TableAccess) -> Table

pub fn counter_increment_by(table: Table, key: any, by: number.Number) -> Nil {
  case by {
    number.Dec(val) -> do_counter_increment_by_decimal(table, key, val)
    number.Int(val) -> do_counter_increment_by(table, key, val)
    number.NaN -> panic as "can not increment a counter by NaN"
    number.NegInf -> panic as "can not increment a counter by -Inf"
    number.PosInf -> panic as "can not increment a counter by +Inf"
  }
  Nil
}

pub fn counter_increment(table: Table, key: any) -> Nil {
  do_counter_increment_by(table, key, 1)
  Nil
}

pub fn match_metric(table: Table, kind: kind) -> List(Dynamic) {
  do_match_metric(table, kind)
}

pub fn match_record(table: Table, name: String) -> List(Dynamic) {
  do_match_record(table, name)
}

@external(erlang, "themis_external", "info")
fn do_info(
  table: Table,
) -> #(
  #(Atom, Tid),
  #(Atom, Bool),
  #(Atom, Bool),
  #(Atom, Bool),
  #(Atom, Bool),
  #(Atom, Int),
  #(Atom, Pid),
  #(Atom, Option(Pid)),
  #(Atom, Atom),
  #(Atom, Int),
  #(Atom, Atom),
  #(Atom, Bool),
  #(Atom, TableType),
  #(Atom, Int),
  #(Atom, TableAccess),
)

@external(erlang, "ets", "insert")
fn do_insert(table: Table, object_or_objects: any) -> Bool

@external(erlang, "ets", "insert_new")
fn do_insert_new(table: Table, object_or_objects: any) -> Dynamic

@external(erlang, "ets", "lookup")
fn do_lookup(table: Table, key: id) -> List(Dynamic)

@external(erlang, "themis_external", "counter_increment_by")
fn do_counter_increment_by(table: Table, key: any, increment: Int) -> Nil

@external(erlang, "themis_external", "match_metric")
fn do_match_metric(table: Table, kind: kind) -> List(Dynamic)

@external(erlang, "themis_external", "match_record")
fn do_match_record(table: Table, name: String) -> List(Dynamic)

@external(erlang, "themis_external", "counter_increment_by_decimal")
fn do_counter_increment_by_decimal(
  table: Table,
  key: any,
  increment: Float,
) -> Nil
