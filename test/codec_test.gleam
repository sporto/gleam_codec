import codec.{Codec}
import gleam/should
import gleam/dynamic

pub fn hello_world_test() {
  codec.hello_world()
  |> should.equal("Hello, from gleam_codec!")
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
  let c : Codec(Int) = codec.int()

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