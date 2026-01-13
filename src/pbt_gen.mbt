///|
pub struct Gen[T] {
  run : (Int, @quickcheck/splitmix.RandomState) -> T
}

///|
pub fn[T] Gen::pure(value : T) -> Gen[T] {
  Gen::{ run: (_, _) => value }
}

///|
pub fn[A, B] Gen::map(self : Gen[A], f : (A) -> B) -> Gen[B] {
  Gen::{ run: (size, rs) => f((self.run)(size, rs)) }
}

///|
pub fn[A, B] Gen::bind(self : Gen[A], f : (A) -> Gen[B]) -> Gen[B] {
  Gen::{ run: (size, rs) => (f((self.run)(size, rs)).run)(size, rs) }
}

///|
pub fn[T] Gen::sized(f : (Int) -> Gen[T]) -> Gen[T] {
  Gen::{ run: (size, rs) => (f(size).run)(size, rs) }
}

///|
pub fn[T] Gen::resize(self : Gen[T], size : Int) -> Gen[T] {
  Gen::{ run: (_, rs) => (self.run)(size, rs) }
}

///|
pub fn Gen::choose_int(min : Int, max : Int) -> Gen[Int] {
  Gen::{
    run: (_, rs) => {
      let lo = if min <= max { min } else { max }
      let hi = if min <= max { max } else { min }
      let span = hi - lo + 1
      if span <= 0 {
        lo
      } else {
        lo + rs.next_positive_int() % span
      }
    },
  }
}

///|
pub fn[T] Gen::one_of(gens : Array[Gen[T]]) -> Gen[T] {
  Gen::{
    run: (size, rs) => {
      let len = gens.length()
      guard len > 0 else { panic() }
      let idx = rs.next_positive_int() % len
      (gens[idx].run)(size, rs)
    },
  }
}

///|
pub fn[T] Gen::frequency(items : Array[(Int, Gen[T])]) -> Gen[T] {
  Gen::{
    run: (size, rs) => {
      let len = items.length()
      guard len > 0 else { panic() }
      let mut total = 0
      for item in items {
        let (weight, _) = item
        if weight > 0 {
          total += weight
        }
      }
      guard total > 0 else { panic() }
      let pick = rs.next_positive_int() % total
      let mut acc = 0
      let (_, first_gen) = items[0]
      let mut chosen = first_gen
      for item in items {
        let (weight, gen) = item
        if weight <= 0 {
          continue
        }
        acc += weight
        if pick < acc {
          chosen = gen
          break
        }
      }
      (chosen.run)(size, rs)
    },
  }
}

///|
pub fn[T] Gen::array_of(gen : Gen[T]) -> Gen[Array[T]] {
  Gen::{
    run: (size, rs) => {
      let max_len = if size <= 0 { 0 } else { size }
      let len = if max_len == 0 {
        0
      } else {
        rs.next_positive_int() % (max_len + 1)
      }
      Array::makei(len, _ => (gen.run)(size, rs))
    },
  }
}

///|
pub fn[T : @quickcheck.Arbitrary] Gen::arbitrary() -> Gen[T] {
  Gen::{ run: (size, rs) => @quickcheck.Arbitrary::arbitrary(size, rs) }
}
