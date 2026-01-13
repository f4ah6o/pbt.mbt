# fhproper-code

Sample code from the book **"Property-Based Testing with PropEr, Erlang, and Elixir"** by Fred Hebert.

## 📚 Source

- **Book**: [Property-Based Testing with PropEr, Erlang, and Elixir](https://pragprog.com/titles/fhproper/property-based-testing-with-proper-erlang-and-elixir/)
- **Publisher**: The Pragmatic Programmers
- **Author**: Fred Hebert
- **Japanese Edition**: [プロパティベーステスト ― PropErとErlang/Elixirではじめよう](https://www.lambdanote.com/products/proper) (ラムダノート)

## 📁 Directory Structure

```
code/
├── CustomGenerators/             # Custom generator examples
├── Foundations/                  # Foundations
├── PropertiesDrivenDevelopment/  # Properties-driven development
├── ResponsibleTesting/           # Responsible testing
├── StatefulProperties/           # Stateful properties
├── ThinkingInProperties/         # Thinking in properties
└── WritingProperties/            # Writing properties
```

## 📜 License

The code in this directory is licensed under **Apache License 2.0**.

```
Copyright 2017, Fred Hebert <mononcqc@ferd.ca>
Licensed under the Apache License, Version 2.0
```

See [code/CustomGenerators/erlang/pbt/LICENSE](code/CustomGenerators/erlang/pbt/LICENSE) for details.

## 🎯 Purpose

This code is included as a reference for implementing a Property-Based Testing library (pbt.mbt) in MoonBit.

## Property-Based Testing with MoonBit/QuickCheck

This section adapts a few ideas from the book to MoonBit using
`moonbitlang/quickcheck` (alias `@qc` in `moon.pkg.json`). The examples below
are runnable with `moon test` via `mbt check` blocks. Properties should avoid
mutating generated inputs, so the examples copy arrays before sorting or
removing elements.

### Foundations: properties are just functions

The book opens with very small properties. Here is the original PropEr
example, followed by a more meaningful MoonBit property that also records the
distribution of array sizes.

```erlang
-module(prop_foundations).
-include_lib("proper/include/proper.hrl").

prop_test() ->
    ?FORALL(Type, term(),
        begin
            boolean(Type)
        end).

boolean(_) -> true.
```

```mbt check
///|
fn prop_reverse_involutive(arr : Array[Int]) -> @qc.Property {
  let ok = arr.rev().rev() == arr
  let with_size = @qc.collect(ok, arr.length())
  @qc.classify(with_size, arr.length() == 0, "empty")
}

///|
test "quickcheck reverse involutive" {
  @qc.quick_check_fn(prop_reverse_involutive, max_success=60, max_size=40)
}
```

### Thinking in properties (models and invariants)

These properties mirror the "Thinking in properties" chapter: compare against
a simple model and check multiple invariants for sorting.

```mbt check
///|
fn sort_copy(arr : Array[Int]) -> Array[Int] {
  let copy = arr.copy()
  copy.sort()
  copy
}

///|
fn is_ordered(arr : Array[Int]) -> Bool {
  let len = arr.length()
  if len < 2 {
    return true
  }
  let mut prev = arr[0]
  for i in 1..<len {
    let curr = arr[i]
    if prev > curr {
      return false
    }
    prev = curr
  }
  true
}

///|
fn biggest(arr : Array[Int]) -> Int {
  let mut max = arr[0]
  for v in arr {
    if v > max {
      max = v
    }
  }
  max
}

///|
fn model_biggest(arr : Array[Int]) -> Int {
  let sorted = sort_copy(arr)
  sorted[sorted.length() - 1]
}

///|
fn prop_biggest_matches_model(arr : Array[Int]) -> @qc.Property {
  let non_empty = arr.length() > 0
  let ok = if non_empty { biggest(arr) == model_biggest(arr) } else { true }
  @qc.filter(ok, non_empty)
}

///|
fn prop_sort_ordered(arr : Array[Int]) -> Bool {
  is_ordered(sort_copy(arr))
}

///|
fn prop_sort_same_size(arr : Array[Int]) -> Bool {
  sort_copy(arr).length() == arr.length()
}

///|
fn prop_sort_no_added(arr : Array[Int]) -> Bool {
  let sorted = sort_copy(arr)
  sorted.all(fn(v) { arr.contains(v) })
}

///|
fn prop_sort_no_removed(arr : Array[Int]) -> Bool {
  let sorted = sort_copy(arr)
  arr.all(fn(v) { sorted.contains(v) })
}

///|
test "quickcheck biggest matches model" {
  @qc.quick_check_fn(prop_biggest_matches_model, max_success=50, max_size=40)
}

///|
test "quickcheck sort ordered" {
  @qc.quick_check_fn(prop_sort_ordered, max_success=50, max_size=40)
}

///|
test "quickcheck sort same size" {
  @qc.quick_check_fn(prop_sort_same_size, max_success=50, max_size=40)
}

///|
test "quickcheck sort no added" {
  @qc.quick_check_fn(prop_sort_no_added, max_success=50, max_size=40)
}

///|
test "quickcheck sort no removed" {
  @qc.quick_check_fn(prop_sort_no_removed, max_success=50, max_size=40)
}
```

### Custom generators for meaningful cases

This example mirrors the book's emphasis on crafting generators that avoid
vacuous tests. We pick an element from a non-empty array and ensure it is
removed.

```mbt check
///|
fn remove_all(arr : Array[Int], value : Int) -> Array[Int] {
  arr.filter(fn(x) { x != value })
}

///|
fn gen_member_pair() -> @qc.Gen[(Array[Int], Int)] {
  let array_gen : @qc.Gen[Array[Int]] = @qc.Gen::spawn()
  let non_empty = array_gen.such_that(fn(arr) { arr.length() > 0 })
  non_empty.bind(fn(arr) { @qc.one_of_array(arr).fmap(fn(x) { (arr, x) }) })
}

///|
fn prop_remove_all_member(pair : (Array[Int], Int)) -> Bool {
  let (arr, target) = pair
  let cleaned = remove_all(arr, target)
  not(cleaned.contains(target))
}

///|
test "quickcheck remove_all removes chosen member" {
  let prop = @qc.forall(gen_member_pair(), prop_remove_all_member)
  @qc.quick_check(prop, max_success=40, max_size=30)
}
```
