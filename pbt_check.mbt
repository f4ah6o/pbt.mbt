///|
pub struct CheckConfig {
  cases : Int
  max_size : Int
  seed : UInt64
  shrink_limit : Int
}

///|
pub impl Default for CheckConfig with default() {
  CheckConfig::{ cases: 100, max_size: 30, seed: 1, shrink_limit: 100 }
}

///|
pub fn CheckConfig::new(
  cases : Int,
  max_size : Int,
  seed : UInt64,
  shrink_limit : Int,
) -> CheckConfig {
  CheckConfig::{ cases, max_size, seed, shrink_limit }
}

///|
pub struct Failure {
  case_index : Int
  size : Int
  seed : UInt64
  message : String
  original : String
  shrunk : String?
} derive(Show)

///|
pub fn[T : Show] check(
  gen : Gen[T],
  prop : (T) -> Result[Unit, String],
  config? : CheckConfig = CheckConfig::default(),
  shrink? : (T) -> Iter[T],
) -> Result[Unit, Failure] {
  let config = config
  let cases = if config.cases < 0 { 0 } else { config.cases }
  let max_size = if config.max_size < 0 { 0 } else { config.max_size }
  let rs = @quickcheck/splitmix.new(seed=config.seed)
  for i in 0..<cases {
    let size = if i < max_size { i } else { max_size }
    let value = (gen.run)(size, rs)
    match prop(value) {
      Ok(_) => ()
      Err(msg) => {
        let original = "\{value}"
        let mut final_value = value
        let mut final_msg = msg
        let mut shrunk : String? = None
        match shrink {
          None => ()
          Some(shrinker) => {
            let (shrunk_value, shrunk_msg) = shrink_value(
              value,
              final_msg,
              prop,
              shrinker,
              config.shrink_limit,
            )
            final_value = shrunk_value
            final_msg = shrunk_msg
            shrunk = Some("\{final_value}")
          }
        }
        return Err(Failure::{
          case_index: i,
          size,
          seed: config.seed,
          message: final_msg,
          original,
          shrunk,
        })
      }
    }
  }
  Ok(())
}

///|
fn[T] shrink_value(
  value : T,
  message : String,
  prop : (T) -> Result[Unit, String],
  shrinker : (T) -> Iter[T],
  limit : Int,
) -> (T, String) {
  if limit <= 0 {
    return (value, message)
  }
  let mut current = value
  let mut current_msg = message
  let mut rounds = 0
  while rounds < limit {
    let mut found = false
    for candidate in shrinker(current) {
      match prop(candidate) {
        Ok(_) => ()
        Err(msg) => {
          current = candidate
          current_msg = msg
          found = true
          break
        }
      }
    }
    if not(found) {
      break
    }
    rounds += 1
  }
  (current, current_msg)
}
