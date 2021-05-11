import gleam/dynamic.{Dynamic}

pub fn hello_world() -> String {
  "Hello, from gleam_codec!"
}

type Decoder(a) =
  fn(Dynamic) -> Result(a, String)

pub type Codec(a){
  Codec(
    encode: fn(a) -> Dynamic,
    decoder: Decoder(a),
  )
}

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

pub fn encode(codec: Codec(a), a) -> Dynamic {
  codec.encode(a)
}

pub fn decode(codec: Codec(a), a) -> Result(a, String) {
  codec.decoder(a)
}