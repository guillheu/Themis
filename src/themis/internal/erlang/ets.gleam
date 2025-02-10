import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}

// import gleam/dynamic/decode
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/option.{type Option}
import gleam/result
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

pub type TableError {
  AtomFromStringError(atom.FromStringError)
  DecodeError(List(dynamic.DecodeError))
  InsertFailed
}

pub fn new(builder: TableBuilder, name: String) -> Atom {
  atom.create_from_string(name)
  |> do_new(builder.table_type, builder.table_access)
}

pub fn info(table_name: Atom) -> TableInfo {
  let r = do_info(table_name)
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

pub fn insert(
  table_name: String,
  key: key,
  value: value,
) -> Result(Bool, TableError) {
  use table_name_atom <- guard_atom_from_string(table_name)
  Ok(do_insert(table_name_atom, #(key, value) |> dynamic.from))
}

pub fn insert_new_raw(
  table_name: String,
  object: Dynamic,
) -> Result(Nil, TableError) {
  use table_name_atom <- guard_atom_from_string(table_name)
  let r = do_insert_new(table_name_atom, object)
  case r |> dynamic.bool {
    Error(e) -> Error(DecodeError(e))
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(InsertFailed)
  }
}

pub fn insert_many(
  table_name: String,
  to_insert: Dict(key, value),
) -> Result(Bool, TableError) {
  let objects =
    dict.to_list(to_insert)
    |> dynamic.from

  use table_name_atom <- guard_atom_from_string(table_name)
  do_insert(table_name_atom, objects) |> Ok
}

pub fn insert_raw(table_name: String, object: any) -> Result(Bool, TableError) {
  use table_name_atom <- guard_atom_from_string(table_name)
  do_insert(table_name_atom, object) |> Ok
}

pub fn lookup(table_name: String, key: key) -> Result(List(Dynamic), TableError) {
  use table_name_atom <- guard_atom_from_string(table_name)
  do_lookup(table_name_atom, key) |> Ok
}

pub fn counter_increment_by(
  table_name: String,
  key: any,
  by: number.Number,
) -> Result(Nil, TableError) {
  use table_name_atom <- guard_atom_from_string(table_name)
  case by {
    number.Dec(val) ->
      do_counter_increment_by_decimal(table_name_atom, key, val)
    number.Int(val) -> do_counter_increment_by(table_name_atom, key, val)
    number.NaN -> panic as "can not increment a counter by NaN"
    number.NegInf -> panic as "can not increment a counter by -Inf"
    number.PosInf -> panic as "can not increment a counter by +Inf"
  }
  Nil |> Ok
}

pub fn counter_increment(
  table_name: String,
  key: any,
) -> Result(Nil, TableError) {
  use table_name_atom <- guard_atom_from_string(table_name)
  do_counter_increment_by(table_name_atom, key, 1)
  Nil |> Ok
}

pub fn match_metric(
  table_name: String,
  kind: kind,
) -> Result(List(Dynamic), TableError) {
  use table_name_atom <- guard_atom_from_string(table_name)
  do_match_metric(table_name_atom, kind) |> Ok
}

pub fn match_record(
  table_name: String,
  name: String,
) -> Result(List(Dynamic), TableError) {
  use table_name_atom <- guard_atom_from_string(table_name)
  do_match_record(table_name_atom, name) |> Ok
}

pub fn delete_table(table_name: String) -> Result(Bool, TableError) {
  use table_name_atom <- guard_atom_from_string(table_name)
  do_delete(table_name_atom) |> Ok
}

fn guard_atom_from_string(
  table_name: String,
  fun: fn(Atom) -> Result(a, TableError),
) -> Result(a, TableError) {
  let r =
    atom.from_string(table_name)
    |> result.map_error(fn(e) { AtomFromStringError(e) })
  result.try(r, fun)
}

@external(erlang, "themis_external", "new")
fn do_new(name: Atom, table_type: TableType, table_access: TableAccess) -> Atom

@external(erlang, "themis_external", "info")
fn do_info(
  table: Atom,
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
fn do_insert(table: Atom, object_or_objects: any) -> Bool

@external(erlang, "ets", "insert_new")
fn do_insert_new(table: Atom, object_or_objects: any) -> Dynamic

@external(erlang, "ets", "lookup")
fn do_lookup(table: Atom, key: id) -> List(Dynamic)

@external(erlang, "themis_external", "counter_increment_by")
fn do_counter_increment_by(table: Atom, key: any, increment: Int) -> Nil

@external(erlang, "themis_external", "match_metric")
fn do_match_metric(table: Atom, kind: kind) -> List(Dynamic)

@external(erlang, "themis_external", "match_record")
fn do_match_record(table: Atom, name: String) -> List(Dynamic)

@external(erlang, "themis_external", "counter_increment_by_decimal")
fn do_counter_increment_by_decimal(
  table: Atom,
  key: any,
  increment: Float,
) -> Nil

@external(erlang, "ets", "delete")
fn do_delete(table: Atom) -> Bool
