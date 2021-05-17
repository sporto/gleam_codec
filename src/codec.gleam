import gleam/atom
import gleam/dynamic.{Dynamic}
import gleam/function
import gleam/list
import gleam/map.{Map} as gleam_map
import gleam/option.{Option,Some,None}
import gleam/result
import gleam/string

const type_key = "__type__"

type Encoder(a) =
	fn(a) -> Dynamic

type Decoder(a) =
	fn(Dynamic) -> Result(a, String)

pub type Codec(a) {
	Codec(encoder: Encoder(a), decoder: Decoder(a))
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
	build(
		dynamic.from,
		dynamic.typed_list(_, of: codec.decoder)
	)
}

/// Create a codec for a Map
///
/// # Example
///
/// ```
/// let c = codec.map(
///   codec.string(),
///   codec.int(),
/// )
///
/// let dict = [ #("a", 1) ] |> map.from_list
///
/// codec.encode(c, dict)
/// ```
///
pub fn map(
		codec_key: Codec(a),
		codec_value: Codec(b)
	) -> Codec(Map(a, b)) {

	let decoder = fn(value) {
		dynamic.map(value)
		|> result.then(fn(dict: Map(Dynamic, Dynamic)) {
			dict
			|> gleam_map.to_list
			|> list.map(fn(pair) {
				let #(dkey, dval) = pair
				case codec_key.decoder(dkey), codec_value.decoder(dval) {
					Ok(key), Ok(val) ->
						Ok(#(key, val))
					_, _ ->
						Error("")
				}
			})
			|> result.all
			|> result.map(gleam_map.from_list)
		})
	}

	build(
		dynamic.from,
		decoder
	)
}

pub fn option(codec: Codec(a)) -> Codec(Option(a)) {

	let encoder = fn(op) {
		case op {
			Some(v) -> codec.encoder(v)
			None ->
				atom.create_from_string("null")
				|> dynamic.from
		}
	}

	let decoder = fn(value: Dynamic) {
		dynamic.option(
			from: value,
			of: codec.decoder
		)
	}

	build(
		encoder,
		decoder
	)
}

pub fn tuple2(
		codec_a: Codec(a),
		codec_b: Codec(b),
	) -> Codec(#(a, b)) {

	let encoder = fn(tup) {
		let #(a, b) = tup

		#(codec_a.encoder(a), codec_b.encoder(b))
		|> dynamic.from
	}

	let decoder = fn(value) {
		dynamic.typed_tuple2(
			from: value,
			first: codec_a.decoder,
			second: codec_b.decoder
		)
	}

	build(
		encoder,
		decoder
	)
}

pub type RecordCodec(input, output) {
	RecordCodec(
		field: String,
		encoder: Encoder(input),
		decoder: Decoder(output)
	)
}

pub fn record_field(
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
		[]
		|> dynamic_map_add_field(custom, codec1)
		|> dynamic_map_add_type_name(type_name)
		|> dynamic_map_finish
	}

	let decoder = fn(value) {
		Ok(constructor)
			|> apply_decoded_result(codec1.decoder(value))
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
		[]
		|> dynamic_map_add_field(custom, codec1)
		|> dynamic_map_add_field(custom, codec2)
		|> dynamic_map_add_type_name(type_name)
		|> dynamic_map_finish
	}

	let decoder = fn(value) {
		Ok(function.curry2(constructor))
			|> apply_decoded_result(codec1.decoder(value))
			|> apply_decoded_result(codec2.decoder(value))
	}

	build(encoder, decoder)
}

pub type CustomCodec(match, v) {
	CustomCodec(
		match: match,
		decoders: Map(String, Decoder(v)),
	)
}

pub fn custom(match) {
	CustomCodec(
		match,
		decoders: gleam_map.new()
	)
}

pub fn finish_custom(
		c: CustomCodec(Encoder(final), final)
	) -> Codec(final) {

	let encoder: Encoder(final) = c.match

	let decoder = fn(value: Dynamic) -> Result(final, String) {
		try tag_field = dynamic
			.field(from: value, named: type_key)

		try tag : String = dynamic
			.string(tag_field)

		// Find the decoder for this tag
		try decoder = gleam_map
			.get(c.decoders, tag)
			|> result.replace_error(
				string.append("Couldn't find tag ", tag)
			)

		decoder(value)
	}

	Codec(
		encoder: encoder,
		decoder: decoder,
	)
}

pub type VariantCodec(field) {
	VariantCodec(
		field: String,
		encoder: Encoder(field),
		decoder: Decoder(field)
	)
}

pub fn variant_field(
		field_name: String,
		field_codec: Codec(field)
	) -> VariantCodec(field) {

	let decoder: Decoder(field) = fn(record: Dynamic) {
		dynamic.field(record, field_name)
		|> result.then(field_codec.decoder)
	}

	VariantCodec(
		field_name,
		field_codec.encoder,
		decoder
	)
}

pub fn variant0(
		c: CustomCodec(
			fn(fn() -> Dynamic) -> a,
			cons
		),
		type_name: String,
		constructor: cons,
	) -> CustomCodec(a, cons) {

	let encoder = fn() {
		[#(type_key, type_name)]
		|> gleam_map.from_list
		|> dynamic.from
	}

	let decoder = fn(value: Dynamic) {
		Ok(constructor)
	}

	let decoders = gleam_map.insert(
		c.decoders,
		type_name,
		decoder
	)

	CustomCodec(
		match: c.match(encoder),
		decoders: decoders
	)
}

pub fn variant1(
		c: CustomCodec(
			fn(fn(a) -> Dynamic) -> next,
			cons
		),
		type_name: String,
		constructor: fn(a) -> cons,
		codec1: VariantCodec(a)
	) -> CustomCodec(next, cons) {

	let encoder = fn(a) {
		[]
		|> dynamic_map_add_type_name(type_name)
		|> variant_map_add_field(a, codec1)
		|> dynamic_map_finish
	}

	let decoder = fn(value: Dynamic) {
		codec1.decoder(value)
		|> result.map(constructor)
	}

	let decoders = gleam_map.insert(
		c.decoders,
		type_name,
		decoder
	)

	CustomCodec(
		match: c.match(encoder),
		decoders: decoders
	)
}

pub fn variant2(
		c: CustomCodec(
			fn(fn(a, b) -> Dynamic) -> next,
			cons
		),
		type_name: String,
		constructor: fn(a, b) -> cons,
		codec1: VariantCodec(a),
		codec2: VariantCodec(b)
	) -> CustomCodec(next, cons) {

	let encoder = fn(a, b) {
		[]
		|> dynamic_map_add_type_name(type_name)
		|> variant_map_add_field(a, codec1)
		|> variant_map_add_field(b, codec2)
		|> dynamic_map_finish
	}

	let decoder = fn(value: Dynamic) {
		Ok(function.curry2(constructor))
		|> apply_decoded_result(codec1.decoder(value))
		|> apply_decoded_result(codec2.decoder(value))
	}

	let decoders = gleam_map.insert(
		c.decoders,
		type_name,
		decoder
	)

	CustomCodec(
		match: c.match(encoder),
		decoders: decoders
	)
}

pub fn variant3(
		c: CustomCodec(
			fn(fn(a, b, c) -> Dynamic) -> next,
			cons
		),
		type_name: String,
		constructor: fn(a, b, c) -> cons,
		codec1: VariantCodec(a),
		codec2: VariantCodec(b),
		codec3: VariantCodec(c),
	) -> CustomCodec(next, cons) {

	let encoder = fn(a, b, c) {
		[]
		|> dynamic_map_add_type_name(type_name)
		|> variant_map_add_field(a, codec1)
		|> variant_map_add_field(b, codec2)
		|> variant_map_add_field(c, codec3)
		|> dynamic_map_finish
	}

	let decoder = fn(value: Dynamic) {
		Ok(function.curry3(constructor))
		|> apply_decoded_result(codec1.decoder(value))
		|> apply_decoded_result(codec2.decoder(value))
		|> apply_decoded_result(codec3.decoder(value))
	}

	let decoders = gleam_map.insert(
		c.decoders,
		type_name,
		decoder
	)

	CustomCodec(
		match: c.match(encoder),
		decoders: decoders
	)
}

// Process
fn dynamic_map_add_field(
		fields: List(#(String, Dynamic)),
		custom: final,
		codec: RecordCodec(final, a)
	) {
	[ #(codec.field, codec.encoder(custom)), ..fields ]
}

fn dynamic_map_add_type_name(fields, type_name: String) {
	[#(type_key, dynamic.from(type_name)), ..fields]
}

fn variant_map_add_field(
		fields: List(#(String, Dynamic)),
		custom: final,
		codec: VariantCodec(final)
	) {
	[ #(codec.field, codec.encoder(custom)), ..fields ]
}

fn dynamic_map_finish(fields) {
	fields
	|> gleam_map.from_list
	|> dynamic.from
}

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
