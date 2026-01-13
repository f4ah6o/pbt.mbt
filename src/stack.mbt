///|
pub struct Stack {
  data : Array[Int]
}

///|
pub fn Stack::new() -> Stack {
  Stack::{ data: [] }
}

///|
pub fn Stack::push(self : Stack, value : Int) -> Unit {
  self.data.push(value)
}

///|
pub fn Stack::pop(self : Stack) -> Int? {
  self.data.pop()
}

///|
pub fn Stack::top(self : Stack) -> Int? {
  let len = self.data.length()
  if len == 0 {
    None
  } else {
    Some(self.data[len - 1])
  }
}

///|
pub fn Stack::size(self : Stack) -> Int {
  self.data.length()
}

///|
pub fn Stack::clear(self : Stack) -> Unit {
  self.data.clear()
}
