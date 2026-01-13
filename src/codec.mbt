///|
pub fn encode_int_list(values : Array[Int]) -> String {
  values.map(v => v.to_string()).join(",")
}

///|
pub fn decode_int_list(text : String) -> Result[Array[Int], String] {
  if text == "" {
    return Ok([])
  }
  let values : Array[Int] = []
  for part in text.split(",") {
    let parsed = try @strconv.parse_int(part) catch {
      err => return Err("invalid int: \{part} (\{err})")
    } noraise {
      value => value
    }
    values.push(parsed)
  }
  Ok(values)
}
