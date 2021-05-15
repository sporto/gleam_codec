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

// type Stage {
//   Start
//   InProgress(Int, String)
//   EEnd(result: Float)
// }

type Person{
	Person(
		name: String
	)
}

pub fn record1_test() {
	let c = codec.record1(
		"Person",
		Person,
		codec.field(
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
		codec.field(
			"age",
			fn(p: Pet) { p.age },
			codec.int()
		),
		codec.field(
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
// pub fn type_test() {
//   codec.custom_type(fn(encode_start, encode_in_progress, encode_end, value) {
//     case value {
//       Start -> encode_start
//       InProgress(i) -> encode_in_progress(i)
//       End(s) -> encode_end(s)
//     }
//   })
//   |> codec.variant2("Start", Start)
//   |> codec.variant1("InProgress", InProgress, codec.int())
//   |> codec.variant0("End", End, codec.string())
//   |> codec.finish_custom_type()
// }
