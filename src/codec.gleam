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

/// Create a codec for Bool
///
/// ## Example
///
/// ```
/// let c = codec.bool()
///
/// let value = dynamic.from(True)
///
/// codec.decode(c, value)
/// > Ok(True)
/// ```
///
pub fn bool() -> Codec(Bool) {
	build(dynamic.from, dynamic.bool)
}

/// Create a codec for Int
///
/// ## Example
///
/// ```
/// let c = codec.int()
///
/// let value = dynamic.from(12)
///
/// codec.decode(c, value)
/// > Ok(12)
/// ```
///
pub fn int() -> Codec(Int) {
	build(dynamic.from, dynamic.int)
}

/// Create a codec for Float
///
/// ## Example
///
/// ```
/// let c = codec.float()
///
/// let value = dynamic.from(3.1516)
///
/// codec.decode(c, value)
/// > Ok(3.1516)
/// ```
///
pub fn float() -> Codec(Float) {
	build(dynamic.from, dynamic.float)
}

/// Create a codec for String
///
/// ## Example
///
/// ```
/// let c = codec.string()
///
/// let value = dynamic.from("Hello")
///
/// codec.decode(c, value)
/// > Ok("Hello")
/// ```
///
pub fn string() -> Codec(String) {
	build(dynamic.from, dynamic.string)
}

/// Create a codec for List
///
/// ## Example
///
/// ```
/// let c = codec.list(codec.int())
///
/// let value = dynamic.from([1, 2, 3])
///
/// codec.decode(c, value)
/// > Ok([1, 2, 3])
/// ```
///
pub fn list(codec: Codec(a)) -> Codec(List(a)) {
	let encoder = fn(collection) {
		collection
		|> list.map(codec.encoder)
		|> dynamic.from
	}

	build(
		encoder,
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

	let encoder = fn(dict) {
		dict
		|> gleam_map.to_list
		|> list.map(fn(pair) {
			let #(key, val) = pair
			#(
				codec_key.encoder(key),
				codec_value.encoder(val)
			)
		})
		|> gleam_map.from_list
		|> dynamic.from
	}

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
		encoder,
		decoder
	)
}

/// Create a codec for Option
///
/// A Some is encoded as just the value e.g. Some("Hello") becomes "Hello"
/// A None is encoded as a :null atom in Elixir
///
/// ## Example
///
/// ```
/// let c = codec.option(codec.string())
///
/// let value = codec.encode(c, Some("Hello"))
///
/// codec.decode(c, value)
/// > Ok(Some("Hello"))
/// ```
///
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

/// Create a codec for a tuple of two elements
///
/// ## Example
///
/// ```
/// let c = codec.tuple2(codec.string(), codec.int())
///
/// let value = codec.encode(c, #("a", 1))
///
/// codec.decode(c, value)
/// > Ok(#("a", 1))
/// ```
///
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

/// A codec for a record field
pub type AsymmetricalFieldCodec(input, output) {
	AsymmetricalFieldCodec(
		field: String,
		encoder: Encoder(input),
		decoder: Decoder(output)
	)
}

/// Type used for specifiying a variant field
pub type SymmetricalFieldCodec(field) {
	SymmetricalFieldCodec(
		field: String,
		encoder: Encoder(field),
		decoder: Decoder(field)
	)
}

/// Build a AsymmetricalFieldCodec
/// To be used with record1, record2, ...
///
/// ## Example
///
/// ```
/// codec.record_field(
///   "age",
///   fn(p: Pet) { p.age },
///   codec.int()
/// )
/// ```
///
pub fn record_field(
		name: String,
		get: fn(record) -> field,
		field_codec: Codec(field),
	) -> AsymmetricalFieldCodec(record, field) {

	let encoder : Encoder(record) = fn(record) -> Dynamic {
		let field_value = get(record)
		dynamic.from(field_value)
	}

	let decoder: Decoder(field) = fn(record: Dynamic) {
		dynamic.field(record, name)
		|> result.then(field_codec.decoder)
	}

	AsymmetricalFieldCodec(name, encoder, decoder)
}

/// Create a codec for a record (a custom type with only one constructor) with one field
///
/// ## Example
///
/// ```
/// type Person{
///   Person(name: String)
/// }
///
/// let c = codec.record1(
///   "Person",
///   Person,
///   codec.record_field(
///     "name",
///     fn(p: Person) { p.name },
///     codec.string()
///   ),
/// )
///
/// let sam = Person("Sam")
///
/// let value = codec.encode(c, sam)
/// ```
///
/// The record will be encoded as a map
///
/// ```elixir
/// %{ "__type__" => "Person", "name" => "Sam"}
/// ```
///
/// ```
/// codec.decode(c, value)
/// > Ok(sam)
/// ```
///
pub fn record1(
		type_name: String,
		constructor: fn(a) -> final,
		codec1: AsymmetricalFieldCodec(final, a),
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

/// Create a codec for a record with two fields
///
/// ## Example
///
/// ```
/// type Pet{
///    Pet(age: Int, name: String)
/// }
///
/// let c = codec.record2(
///   "Pet",
///   Pet,
///   codec.record_field(
///     "age",
///     fn(p: Pet) { p.age },
///     codec.int()
///   ),
///   codec.record_field(
///     "name",
///     fn(p: Pet) { p.name },
///     codec.string()
///   ),
/// )
///
/// let pet = Pet(3, "Fido")
///
/// codec.encode(c, pet)
///
pub fn record2(
		type_name: String,
		constructor: fn(a, b) -> final,
		codec1: AsymmetricalFieldCodec(final, a),
		codec2: AsymmetricalFieldCodec(final, b),
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

/// Partial Codec for creating a custom type codec
pub type CustomCodec(match, v) {
	CustomCodec(
		match: match,
		decoders: Map(String, Decoder(v)),
	)
}

/// Create a codec for custom type
///
/// ##Example
///
///```
/// type Process {
///   Pending
///   Active(Int, String)
///   Done(answer: Float)
/// }
///
/// let c = codec.custom(
///   fn(
///     encode_pending,
///     encode_active,
///     encode_done,
///     value
///   ) {
///    case value {
///      Pending ->
///        encode_pending()
///      Active(i, s) ->
///        encode_active(i, s)
///      Done(r) ->
///        encode_done(r)
///     }
///   }
///   |> function.curry4
/// )
/// |> codec.variant0("Pending", Pending)
/// |> codec.variant2(
///   "Active",
///   Active,
///   codec.variant_field("count", codec.int()),
///   codec.variant_field("name", codec.string())
///   )
/// |> codec.variant1(
///   "Done",
///   Done,
///   codec.variant_field("answer", codec.float())
/// )
/// |> codec.finish_custom()
///
/// let active = Active(1, "x")
///
/// let value = codec.encode(c, active)
/// ```
pub fn custom(match) {
	CustomCodec(
		match,
		decoders: gleam_map.new()
	)
}

/// Finish building a custom type codec
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

/// Used when building a custom type codec
/// See documentation for `custom`
pub fn variant_field(
		field_name: String,
		field_codec: Codec(field)
	) -> SymmetricalFieldCodec(field) {

	let decoder: Decoder(field) = fn(record: Dynamic) {
		dynamic.field(record, field_name)
		|> result.then(field_codec.decoder)
	}

	SymmetricalFieldCodec(
		field_name,
		field_codec.encoder,
		decoder
	)
}

/// Create a codec for variant with no fields
/// See documentation for `custom`
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

/// Create a codec for variant with one field
pub fn variant1(
		c: CustomCodec(
			fn(fn(a) -> Dynamic) -> next,
			cons
		),
		type_name: String,
		constructor: fn(a) -> cons,
		codec1: SymmetricalFieldCodec(a)
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

/// Create a codec for variant with two fields
pub fn variant2(
		c: CustomCodec(
			fn(fn(a, b) -> Dynamic) -> next,
			cons
		),
		type_name: String,
		constructor: fn(a, b) -> cons,
		codec1: SymmetricalFieldCodec(a),
		codec2: SymmetricalFieldCodec(b)
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

/// Create a codec for variant with three fields
pub fn variant3(
		c: CustomCodec(
			fn(fn(a, b, c) -> Dynamic) -> next,
			cons
		),
		type_name: String,
		constructor: fn(a, b, c) -> cons,
		codec1: SymmetricalFieldCodec(a),
		codec2: SymmetricalFieldCodec(b),
		codec3: SymmetricalFieldCodec(c),
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
		codec: AsymmetricalFieldCodec(final, a)
	) {
	[ #(codec.field, codec.encoder(custom)), ..fields ]
}

fn dynamic_map_add_type_name(fields, type_name: String) {
	[#(type_key, dynamic.from(type_name)), ..fields]
}

fn variant_map_add_field(
		fields: List(#(String, Dynamic)),
		custom: final,
		codec: SymmetricalFieldCodec(final)
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

/// Encode a type
pub fn encode(codec: Codec(a), a) -> Dynamic {
	codec.encoder(a)
}

/// Decode a dynamic value
pub fn decode(codec: Codec(a), a) -> Result(a, String) {
	codec.decoder(a)
}
