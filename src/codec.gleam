import gleam/dynamic.{Dynamic}
import gleam/map
import gleam/result

type Encoder(a) =
  fn(a) -> Dynamic

type Decoder(a) =
  fn(Dynamic) -> Result(a, String)

pub type Codec(a) {
  Codec(encoder: Encoder(a), decoder: Decoder(a))
}

pub type ObjectCodec(input, output) {
  ObjectCodec(
    field: String,
    encoder: Encoder(input),
    decoder: Decoder(output)
  )
}

// Build codecs
pub fn build(encoder, decoder) {
  Codec(encoder: encoder, decoder: decoder)
}

pub fn bool() -> Codec(Bool) {
  build(dynamic.from, dynamic.bool)
}

pub fn int() -> Codec(Int) {
  build(dynamic.from, dynamic.int)
}

pub fn float() -> Codec(Float) {
  build(dynamic.from, dynamic.float)
}

pub fn string() -> Codec(String) {
  build(dynamic.from, dynamic.string)
}

pub fn list(codec: Codec(a)) -> Codec(List(a)) {
  build(dynamic.from, dynamic.typed_list(_, of: codec.decoder))
}

pub fn field(
    name: String,
    get: fn(record) -> field,
    field_codec: Codec(field),
  ) -> ObjectCodec(record, field) {

  let encoder : Encoder(record) = fn(record) -> Dynamic {
    let field_value = get(record)
    dynamic.from(field_value)
  }

  let decoder: Decoder(field) = fn(record: Dynamic) {
    dynamic.field(record, name)
    |> result.then(field_codec.decoder)
  }

  ObjectCodec(name, encoder, decoder)
}

pub fn map1(
    type_name: String,
    constructor: fn(a) -> final,
    codec1: ObjectCodec(final, a),
  ) -> Codec(final) {

  let encoder = fn(custom: final) -> Dynamic {
    [
      #("__type__", dynamic.from(type_name)),
      #(codec1.field, codec1.encoder(custom))
    ]
    |> map.from_list
    |> dynamic.from
  }

  let decoder: Decoder(final) = fn(value) {
    codec1.decoder(value)
    |> result.map(fn(v1: a) { constructor(v1) })
  }

  build(encoder, decoder)
}

// Process
pub fn encode(codec: Codec(a), a) -> Dynamic {
  codec.encoder(a)
}

pub fn decode(codec: Codec(a), a) -> Result(a, String) {
  codec.decoder(a)
}
