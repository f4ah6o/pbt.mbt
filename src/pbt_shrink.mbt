///|
pub fn shrink_int(x : Int) -> Iter[Int] {
  if x == 0 {
    return [].iter()
  }
  let candidates : Array[Int] = [0]
  let mut current = x / 2
  while current != 0 {
    candidates.push(current)
    current = current / 2
  }
  candidates.iter()
}

///|
pub fn[T] shrink_array(values : Array[T]) -> Iter[Array[T]] {
  let len = values.length()
  if len == 0 {
    return [].iter()
  }
  let candidates : Array[Array[T]] = []
  let mut n = len / 2
  while n > 0 {
    candidates.push(values[:n].to_array())
    n = n / 2
  }
  candidates.push([])
  candidates.iter()
}
