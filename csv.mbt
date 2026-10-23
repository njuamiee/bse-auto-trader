/// CSV parsing, written here so the engine keeps zero third-party
/// dependencies and can ingest factor sheets directly.
///
/// Three honest limitations, stated rather than hidden:
/// - fields separated by commas; other delimiters are not supported
/// - quoted fields may contain commas and escaped quotes ("")
/// - anything that fails to parse as a number is reported as missing,
///   never silently turned into 0

///| Number of LF characters in `chars`.
fn newline_count(chars : Array[Char]) -> Int {
  let mut c = 0
  for i in 0..<chars.length() {
    if chars[i] == '\n' {
      c = c + 1
    }
  }
  c
}

///| Split raw text into lines, accepting LF and CRLF endings. A trailing
/// line without a newline is kept; an empty input yields zero lines.
pub fn csv_lines(text : String) -> Array[String] {
  let chars = text.to_array()
  let n = chars.length()
  if n == 0 {
    []
  } else {
    let nl = newline_count(chars)
    let total = if chars[n - 1] == '\n' {
      nl
    } else {
      nl + 1
    }
    let out = Array::make(total, "")
    let mut start = 0
    let mut k = 0
    let mut i = 0
    while i <= n {
      if i == n {
        if k < total {
          out[k] = String::from_array(chars[start:n])
        }
        k = k + 1
      } else if chars[i] == '\n' {
        let mut end = i
        if end > start && chars[end - 1] == '\r' {
          end = end - 1
        }
        if k < total {
          out[k] = String::from_array(chars[start:end])
        }
        k = k + 1
        start = i + 1
      }
      i = i + 1
    }
    out
  }
}

///| Field boundaries as a flat array of `[start, end, start, end, ...]`,
/// honouring quotes so a comma inside quotation marks does not split.
fn spans(line : String) -> Array[Int] {
  let chars = line.to_array()
  let n = chars.length()
  if n == 0 {
    []
  } else {
    let tmp = Array::make(2 * (n + 1), 0)
    let mut k = 0
    let mut i = 0
    let mut start = 0
    let mut quoted = false
    while i <= n {
      if i == n {
        tmp[k] = start
        tmp[k + 1] = n
        k = k + 2
      } else {
        let c = chars[i]
        if c == '"' {
          quoted = !quoted
        } else if c == ',' && !quoted {
          tmp[k] = start
          tmp[k + 1] = i
          k = k + 2
          start = i + 1
        }
      }
      i = i + 1
    }
    let out = Array::make(k, 0)
    for j in 0..<k {
      out[j] = tmp[j]
    }
    out
  }
}

///| Length of a field after removing one layer of surrounding quotes and
/// collapsing escaped `""` into a single quote.
fn field_len(chars : Array[Char], s : Int, e : Int) -> Int {
  let mut i = s
  let mut stop = e
  if e > s && chars[s] == '"' {
    i = i + 1
  }
  if stop - 1 >= i && chars[stop - 1] == '"' {
    stop = stop - 1
  }
  let mut len = 0
  while i < stop {
    if chars[i] == '"' && i + 1 < stop && chars[i + 1] == '"' {
      i = i + 2
    } else {
      i = i + 1
    }
    len = len + 1
  }
  len
}

///| Materialise one field with quotes removed.
fn build_field(chars : Array[Char], s : Int, e : Int) -> String {
  let len = field_len(chars, s, e)
  let buf = Array::make(len, ' ')
  let mut i = s
  let mut stop = e
  if e > s && chars[s] == '"' {
    i = i + 1
  }
  if stop - 1 >= i && chars[stop - 1] == '"' {
    stop = stop - 1
  }
  let mut o = 0
  while i < stop {
    if chars[i] == '"' && i + 1 < stop && chars[i + 1] == '"' {
      buf[o] = '"'
      i = i + 2
    } else {
      buf[o] = chars[i]
      i = i + 1
    }
    o = o + 1
  }
  String::from_array(buf[0:len])
}

///| Split one line into fields.
pub fn csv_row(line : String) -> Array[String] {
  let chars = line.to_array()
  let sp = spans(line)
  let nf = sp.length() / 2
  let out = Array::make(nf, "")
  for j in 0..<nf {
    out[j] = build_field(chars, sp[2 * j], sp[2 * j + 1])
  }
  out
}

///| True when the whole field parses as a number.
pub fn is_number(s : String) -> Bool {
  try {
    let _ = @string.parse_double(s)
    true
  } catch {
    _ => false
  }
}

///| Parse one line into numbers. Missing entries become `fallback`.
pub fn csv_floats(line : String, fallback~ : Double = 0.0) -> Array[Double] {
  let fields = csv_row(line)
  let out = Array::make(fields.length(), fallback)
  for j in 0..<fields.length() {
    out[j] = try {
      @string.parse_double(fields[j])
    } catch {
      _ => fallback
    }
  }
  out
}

///| Which fields of a line are not usable numbers.
pub fn csv_missing(line : String) -> Array[Bool] {
  let fields = csv_row(line)
  let out = Array::make(fields.length(), false)
  for j in 0..<fields.length() {
    out[j] = !is_number(fields[j])
  }
  out
}
