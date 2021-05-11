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

fn build(encode, decoder) {
  Codec(
    encode: encode,
    decoder: decoder
  )
}

pub fn int() -> Codec(Int) {
  build(
    dynamic.from,
    dynamic.int,
  )
}

pub fn encode(codec: Codec(a), a) -> Dynamic {
  codec.encode(a)
}

pub fn decode(codec: Codec(a), a) -> Result(a, String) {
  codec.decoder(a)
}