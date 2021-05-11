import gleam/dynamic.{Dynamic}

type Decoder(a) =
  fn(Dynamic) -> Result(a, String)

pub type Codec(a){
  Codec(
    encode: fn(a) -> Dynamic,
    decoder: Decoder(a),
  )
}

// Build codecs

pub fn build(encode, decoder) {
  Codec(
    encode: encode,
    decoder: decoder
  )
}

pub fn bool() -> Codec(Bool) {
  build(
    dynamic.from,
    dynamic.bool,
  )
}

pub fn int() -> Codec(Int) {
  build(
    dynamic.from,
    dynamic.int,
  )
}

pub fn float() -> Codec(Float) {
  build(
    dynamic.from,
    dynamic.float,
  )
}

pub fn string() -> Codec(String) {
  build(
    dynamic.from,
    dynamic.string,
  )
}

pub fn list(codec: Codec(a)) -> Codec(List(a)) {
  build(
    dynamic.from,
    dynamic.typed_list(_, of: codec.decoder),
  )
}

// Process

pub fn encode(codec: Codec(a), a) -> Dynamic {
  codec.encode(a)
}

pub fn decode(codec: Codec(a), a) -> Result(a, String) {
  codec.decoder(a)
}