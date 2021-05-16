import codec.{Codec}
import gleam/should
import gleam/dynamic
import gleam/map

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

type Person{
	Person(
		name: String
	)
}

pub fn record1_test() {
	let c = codec.record1(
		"Person",
		Person,
		codec.record_field(
			"name",
			fn(p: Person) { p.name },
			codec.string()
		),
	)

	let value =
		[
			#("__type__", dynamic.from("Person")),
			#("name", dynamic.from("Sam"))
		]
		|> map.from_list
		|> dynamic.from

	let person = Person("Sam")

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

type Process {
	Pending
	Active(Int, String)
	Done(answer: Float)
}

pub fn custom_test() {
	// let c = codec.custom(fn(encode_pending, encode_active, encode_done, value) {
	// 	case value {
	// 		Pending -> encode_pending()
	// 		Active(i, s) -> encode_active(i, s)
	// 		Done(r) -> encode_done(r)
	// 	}
	// })
	// |> codec.variant0("Pending", Pending)
	// |> codec.variant2(
	// 	"Active",
	// 	Active,
	// 	codec.variant_field("count", codec.int()),
	// 	codec.variant_field("name", codec.string())
	// 	)
	// |> codec.variant1(
	// 	"Done",
	// 	Done,
	// 	codec.variant_field("answer", codec.float())
	// )
	// |> codec.finish_custom_type()

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
	})
	|> codec.variant0("Green", Green)
	|> codec.variant0("Yellow", Yellow)
	|> codec.variant0("Red", Red)
	|> codec.finish_custom()
}
