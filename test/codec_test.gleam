import codec.{Codec}
import gleam/atom
import gleam/dynamic
import gleam/function
import gleam/map
import gleam/option.{Option,Some,None}
import gleam/should

type Person{
	Person(
		name: String
	)
}

fn person_codec() {
	codec.record1(
		"Person",
		Person,
		codec.record_field(
			"name",
			fn(p: Person) { p.name },
			codec.string()
		),
	)
}

fn person_sam_value() {
	[
		#("__type__", dynamic.from("Person")),
		#("name", dynamic.from("Sam"))
	]
	|> map.from_list
	|> dynamic.from
}

fn person_tess_value() {
	[
		#("__type__", dynamic.from("Person")),
		#("name", dynamic.from("Tess"))
	]
	|> map.from_list
	|> dynamic.from
}

fn person_sam() {
	Person("Sam")
}

fn person_tess() {
	Person("Tess")
}

fn null_value() {
	atom.create_from_string("null")
		|> dynamic.from
}

pub fn bool_test() {
	let c = codec.bool()

	let value = dynamic.from(True)

	codec.decode(c, value)
	|> should.equal(Ok(True))

	codec.encode(c, True)
	|> should.equal(value)
}

pub fn int_test() {
	let c: Codec(Int) = codec.int()

	let value = dynamic.from(22)

	codec.decode(c, value)
	|> should.equal(Ok(22))

	codec.encode(c, 22)
	|> should.equal(value)
}

pub fn float_test() {
	let c = codec.float()

	let value = dynamic.from(22.1)

	codec.decode(c, value)
	|> should.equal(Ok(22.1))

	codec.encode(c, 22.1)
	|> should.equal(value)
}

pub fn string_test() {
	let c = codec.string()

	let value = dynamic.from("Hello")

	codec.decode(c, value)
	|> should.equal(Ok("Hello"))

	codec.encode(c, "Hello")
	|> should.equal(value)
}

pub fn list_test() {
	let c = codec.list(codec.int())

	let value = dynamic.from([1, 2, 3])

	codec.decode(c, value)
	|> should.equal(Ok([1, 2, 3]))

	codec.encode(c, [1, 2, 3])
	|> should.equal(value)
}

pub fn list_complex_test() {
	let c = codec.list(person_codec())

	let sam = person_sam()
	let tess = person_tess()

	let people = [sam, tess]

	let value = [person_sam_value(), person_tess_value()]
	|> dynamic.from

	codec.decode(c, value)
	|> should.equal(Ok(people))

	codec.encode(c, people)
	|> should.equal(value)
}

pub fn map_test() {
	let c = codec.map(
		codec.string(),
		codec.int()
	)

	let dict = [
		#("a", 1),
		#("b", 2),
	]
	|> map.from_list

	let value = dict
	|> dynamic.from

	codec.decode(c, value)
	|> should.equal(Ok(dict))

	codec.encode(c, dict)
	|> should.equal(value)
}

pub fn map_complex_test() {
	let c = codec.map(
		codec.string(),
		person_codec()
	)

	let sam = person_sam()
	let tess = person_tess()

	let dict = [
		#("sam", sam),
		#("tess", tess),
	]
	|> map.from_list

	let value = [
		#("sam", person_sam_value()),
		#("tess", person_tess_value())
	]
	|> map.from_list
	|> dynamic.from

	codec.decode(c, value)
	|> should.equal(Ok(dict))

	codec.encode(c, dict)
	|> should.equal(value)
}

pub fn option_test() {
	let c = codec.option(
		codec.string(),
	)

	let some = Some("Hello")

	let value_some = dynamic.from("Hello")

	let value_none = null_value()

	codec.encode(c, some)
	|> should.equal(value_some)

	codec.decode(c, value_some)
	|> should.equal(Ok(some))

	codec.encode(c, None)
	|> should.equal(value_none)

	codec.decode(c, value_none)
	|> should.equal(Ok(None))
}

pub fn option_complex_test() {
	let c = codec.option(
		person_codec()
	)

	let sam = person_sam()

	let value_some = person_sam_value()

	codec.encode(c, Some(sam))
	|> should.equal(value_some)

	codec.decode(c, value_some)
	|> should.equal(Ok(Some(sam)))
}

// TODO
// tuple3

pub fn tuple2_test() {
	let c = codec.tuple2(
		codec.string(),
		codec.int(),
	)

	let tup = #("Hello", 12)

	let value = tup
	|> dynamic.from

	codec.encode(c, tup)
	|> should.equal(value)

	codec.decode(c, value)
	|> should.equal(Ok(tup))
}

pub fn tuple2_complex_test() {

	let c = codec.tuple2(
		person_codec(),
		person_codec(),
	)

	let sam = person_sam()
	let tess = person_tess()

	let tup = #(sam, tess)

	let value = #(
		person_sam_value(),
		person_tess_value()
	)
	|> dynamic.from

	codec.encode(c, tup)
	|> should.equal(value)

	codec.decode(c, value)
	|> should.equal(Ok(tup))
}

pub fn record1_test() {
	let c = person_codec()
	let value = person_sam_value()
	let person = person_sam()

	codec.decode(c, value)
	|> should.equal(Ok(person))

	codec.encode(c, person)
	|> should.equal(value)
}

type Pet{
	Pet(
		age: Int,
		name: String,
	)
}

pub fn record2_test() {
	let c = codec.record2(
		"Pet",
		Pet,
		codec.record_field(
			"age",
			fn(p: Pet) { p.age },
			codec.int()
		),
		codec.record_field(
			"name",
			fn(p: Pet) { p.name },
			codec.string()
		),
	)

	let value =
		[
			#("__type__", dynamic.from("Pet")),
			#("age", dynamic.from(3)),
			#("name", dynamic.from("Fido")),
		]
		|> map.from_list
		|> dynamic.from

	let pet = Pet(3, "Fido")

	codec.decode(c, value)
	|> should.equal(Ok(pet))

	codec.encode(c, pet)
	|> should.equal(value)
}

type Semaphore {
	Green
	Yellow
	Red
}

pub fn custom_variant0_test() {

	let c = codec.custom(
		fn(
			encode_green,
			encode_yellow,
			encode_red,
			value
			) {
				case value {
					Green ->
						encode_green()
					Yellow ->
						encode_yellow()
					Red ->
						encode_red()
				}
		} |> function.curry4
	)
	|> codec.variant0("Green", Green)
	|> codec.variant0("Yellow", Yellow)
	|> codec.variant0("Red", Red)
	|> codec.finish_custom()

	let value_green =
		[
			#("__type__", dynamic.from("Green")),
		]
		|> map.from_list
		|> dynamic.from

	codec.decode(c, value_green)
	|> should.equal(Ok(Green))

	codec.encode(c, Green)
	|> should.equal(value_green)

	let value_red =
		[
			#("__type__", dynamic.from("Red")),
		]
		|> map.from_list
		|> dynamic.from

	codec.decode(c, value_red)
	|> should.equal(Ok(Red))

	codec.encode(c, Red)
	|> should.equal(value_red)
}

type Process {
	Pending
	Active(Int, String)
	Done(answer: Float)
}


pub fn custom_test() {
	let c = codec.custom(
		fn(
			encode_pending,
			encode_active,
			encode_done,
			value
		) {
			case value {
				Pending ->
					encode_pending()
				Active(i, s) ->
					encode_active(i, s)
				Done(r) ->
					encode_done(r)
			}
		}
		|> function.curry4
	)
	|> codec.variant0("Pending", Pending)
	|> codec.variant2(
		"Active",
		Active,
		codec.variant_field("count", codec.int()),
		codec.variant_field("name", codec.string())
		)
	|> codec.variant1(
		"Done",
		Done,
		codec.variant_field("answer", codec.float())
	)
	|> codec.finish_custom()

	// Pending

	let value_pending =
		[
			#("__type__", dynamic.from("Pending")),
		]
		|> map.from_list
		|> dynamic.from

	codec.decode(c, value_pending)
	|> should.equal(Ok(Pending))

	codec.encode(c, Pending)
	|> should.equal(value_pending)

	// Active

	let value_active =
		[
			#("__type__", dynamic.from("Active")),
			#("count", dynamic.from(99)),
			#("name", dynamic.from("lol")),
		]
		|> map.from_list
		|> dynamic.from

	let active = Active(99, "lol")

	codec.decode(c, value_active)
	|> should.equal(Ok(active))

	codec.encode(c, active)
	|> should.equal(value_active)

	// Done

	let value_done =
		[
			#("__type__", dynamic.from("Done")),
			#("answer", dynamic.from(42.0)),
		]
		|> map.from_list
		|> dynamic.from

	let done = Done(42.0)

	codec.decode(c, value_done)
	|> should.equal(Ok(done))

	codec.encode(c, done)
	|> should.equal(value_done)
}