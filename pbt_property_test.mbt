///|
struct SumCase {
  data : Array[Int]
  start : Int
  length : Int
} derive(Show)

///|
fn gen_sum_case() -> Gen[SumCase] {
  let values = Gen::array_of(Gen::choose_int(-50, 50))
  Gen::bind(values, fn(data) {
    let len = data.length()
    if len == 0 {
      Gen::pure(SumCase::{ data, start: 0, length: 0 })
    } else {
      Gen::bind(Gen::choose_int(0, len - 1), fn(start) {
        Gen::bind(Gen::choose_int(0, len - start), fn(length) {
          Gen::pure(SumCase::{ data, start, length })
        })
      })
    }
  })
}

///|
fn prop_sum_case(case : SumCase) -> Result[Unit, String] {
  let end = case.start + case.length
  let expected = case.data[case.start:end].fold(init=0, (acc, v) => acc + v)
  let actual = sum(data=case.data, start=case.start, length=case.length)
  if actual == expected {
    Ok(())
  } else {
    Err("sum mismatch: expected \{expected}, got \{actual}")
  }
}

///|
fn prop_fib(n : Int) -> Result[Unit, String] {
  let a = fib(n)
  let b = fib(n + 1)
  let c = fib(n + 2)
  if c == a + b {
    Ok(())
  } else {
    Err("fib recurrence failed for n=\{n}")
  }
}

///|
fn prop_codec(values : Array[Int]) -> Result[Unit, String] {
  let encoded = encode_int_list(values)
  match decode_int_list(encoded) {
    Ok(decoded) =>
      if decoded == values {
        Ok(())
      } else {
        Err("roundtrip mismatch: \{decoded} != \{values}")
      }
    Err(err) => Err("decode failed: \{err}")
  }
}

///|
fn pbt_config(seed : UInt64) -> CheckConfig {
  CheckConfig::new(200, 25, seed, 50)
}

///|
fn[T : Show] assert_check(
  label : String,
  gen : Gen[T],
  prop : (T) -> Result[Unit, String],
  config? : CheckConfig = CheckConfig::default(),
  shrink? : (T) -> Iter[T],
) -> Unit raise {
  match check(gen, prop, config~, shrink?) {
    Ok(_) => ()
    Err(failure) => fail("\{label}: \{failure}")
  }
}

///|
test "pbt sum slice matches manual" {
  assert_check("sum", gen_sum_case(), prop_sum_case, config=pbt_config(1))
}

///|
test "pbt fib recurrence" {
  let gen = Gen::choose_int(0, 40)
  assert_check("fib", gen, prop_fib, config=pbt_config(2))
}

///|
test "pbt codec roundtrip" {
  let gen = Gen::array_of(Gen::choose_int(-1000, 1000))
  assert_check(
    "codec",
    gen,
    prop_codec,
    config=pbt_config(3),
    shrink=shrink_array,
  )
}

///|
enum Tree[T] {
  Leaf
  Node(Tree[T], T, Tree[T])
} derive(Show, Eq)

///|
fn[T] tree_mirror(tree : Tree[T]) -> Tree[T] {
  match tree {
    Leaf => Leaf
    Node(left, value, right) =>
      Node(tree_mirror(right), value, tree_mirror(left))
  }
}

///|
fn[T] tree_gen(value_gen : Gen[T]) -> Gen[Tree[T]] {
  Gen::sized(fn(size) {
    if size <= 0 {
      Gen::pure(Leaf)
    } else {
      let leaf = Gen::pure(Leaf)
      let node = Gen::bind(value_gen, fn(value) {
        let sub = size / 2
        let left_gen = tree_gen(value_gen).resize(sub)
        let right_gen = tree_gen(value_gen).resize(sub)
        Gen::bind(left_gen, fn(left) {
          Gen::bind(right_gen, fn(right) { Gen::pure(Node(left, value, right)) })
        })
      })
      Gen::frequency([(1, leaf), (3, node)])
    }
  })
}

///|
fn prop_tree_mirror(tree : Tree[Int]) -> Result[Unit, String] {
  let mirrored = tree_mirror(tree_mirror(tree))
  if mirrored == tree {
    Ok(())
  } else {
    Err("tree mirror failed")
  }
}

///|
test "pbt tree mirror" {
  let gen = tree_gen(Gen::choose_int(-10, 10))
  assert_check("tree", gen, prop_tree_mirror, config=pbt_config(4))
}

///|
enum Command {
  Push(Int)
  Pop
  Top
  Size
  Clear
} derive(Show, Eq)

///|
fn next_model_size(size : Int, cmd : Command) -> Int {
  match cmd {
    Push(_) => size + 1
    Pop => if size > 0 { size - 1 } else { 0 }
    Clear => 0
    _ => size
  }
}

///|
fn gen_commands() -> Gen[Array[Command]] {
  Gen::sized(fn(size) {
    let count = if size <= 0 { 0 } else { size }
    fn go(remaining : Int, model_size : Int) -> Gen[Array[Command]] {
      if remaining <= 0 {
        Gen::pure([])
      } else {
        let options : Array[Gen[Command]] = []
        let push_gen = Gen::map(Gen::choose_int(-20, 20), fn(v) { Push(v) })
        options.push(push_gen)
        options.push(Gen::pure(Size))
        options.push(Gen::pure(Clear))
        if model_size > 0 {
          options.push(Gen::pure(Pop))
          options.push(Gen::pure(Top))
        }
        Gen::bind(Gen::one_of(options), fn(cmd) {
          let next_size = next_model_size(model_size, cmd)
          Gen::map(go(remaining - 1, next_size), fn(rest) {
            let result = [cmd]
            result.append(rest)
            result
          })
        })
      }
    }

    go(count, 0)
  })
}

///|
fn run_stack_commands(cmds : Array[Command]) -> Result[Unit, String] {
  let sut = Stack::new()
  let model : Array[Int] = []
  for cmd in cmds {
    match cmd {
      Push(v) => {
        sut.push(v)
        model.push(v)
      }
      Pop => {
        let actual = sut.pop()
        let expected = model.pop()
        if actual != expected {
          return Err("pop mismatch: expected \{expected}, got \{actual}")
        }
      }
      Top => {
        let actual = sut.top()
        let expected = if model.length() == 0 {
          None
        } else {
          Some(model[model.length() - 1])
        }
        if actual != expected {
          return Err("top mismatch: expected \{expected}, got \{actual}")
        }
      }
      Size => {
        let actual = sut.size()
        let expected = model.length()
        if actual != expected {
          return Err("size mismatch: expected \{expected}, got \{actual}")
        }
      }
      Clear => {
        sut.clear()
        model.clear()
      }
    }
  }
  Ok(())
}

///|
test "pbt stack state machine" {
  assert_check(
    "stack",
    gen_commands(),
    run_stack_commands,
    config=pbt_config(5),
    shrink=shrink_array,
  )
}

///|
test "shrink int" {
  let shrunk = shrink_int(42).to_array()
  assert_eq(shrunk, [0, 21, 10, 5, 2, 1])
}

///|
test "shrink array" {
  let shrunk = shrink_array([1, 2, 3, 4]).to_array()
  assert_eq(shrunk, [[1, 2], [1], []])
}
