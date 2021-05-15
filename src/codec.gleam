import gleam/dynamic.{Dynamic}
import gleam/map
import gleam/result
import gleam/function

const type_key = "__type__"

type Encoder(a) =
	fn(a) -> Dynamic

type Decoder(a) =
	fn(Dynamic) -> Result(a, String)

pub type Codec(a) {
	Codec(encoder: Encoder(a), decoder: Decoder(a))
}

pub type RecordCodec(input, output) {
	RecordCodec(
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
	) -> RecordCodec(record, field) {

	let encoder : Encoder(record) = fn(record) -> Dynamic {
		let field_value = get(record)
		dynamic.from(field_value)
	}

	let decoder: Decoder(field) = fn(record: Dynamic) {
		dynamic.field(record, name)
		|> result.then(field_codec.decoder)
	}

	RecordCodec(name, encoder, decoder)
}

pub fn record1(
		type_name: String,
		constructor: fn(a) -> final,
		codec1: RecordCodec(final, a),
	) -> Codec(final) {

	let encoder = fn(custom: final) -> Dynamic {
		[
			#(type_key, dynamic.from(type_name)),
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

pub fn record2(
		type_name: String,
		constructor: fn(a, b) -> final,
		codec1: RecordCodec(final, a),
		codec2: RecordCodec(final, b),
	) {

	let encoder = fn(custom: final) -> Dynamic {
		[
			#(type_key, dynamic.from(type_name)),
			#(codec1.field, codec1.encoder(custom)),
			#(codec2.field, codec2.encoder(custom))
		]
		|> map.from_list
		|> dynamic.from
	}

	let decoder = fn(value) {
		Ok(function.curry2(constructor))
			|> apply_decoded_result(codec1.decoder(value))
			|> apply_decoded_result(codec2.decoder(value))
	}

	build(encoder, decoder)
}

// Process
fn apply_decoded_result(
		accumulator: Result(fn(b) -> next, String),
		decoder_result: Result(b, String),
	) -> Result(next, String) {

		accumulator
		|> result.then(fn(constructor) {
			decoder_result
				|> result.map(fn(decoded_value) {
					constructor(decoded_value)
				})
		})
}

pub fn encode(codec: Codec(a), a) -> Dynamic {
	codec.encoder(a)
}

pub fn decode(codec: Codec(a), a) -> Result(a, String) {
	codec.decoder(a)
}
