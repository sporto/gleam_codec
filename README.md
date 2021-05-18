# Gleam Codec

A library for encoding and decoding Gleam data structures to Erlang and Elixir via codecs.

- A codec creates both an encoder and decoder that are always in sync.
- A codec has an opinionated serialization format. Custom types are serialized as maps.
- A codec is not appropriate for decoding external data structures. As a codec expects a particular data structure.

## Example

```rust
import codec

type Person{
	Person(
		name: String
	)
}

let c = codec.record1(
    "Person",
    Person,
    codec.record_field(
        "name",
        fn(p: Person) { p.name },
        codec.string()
    ),
)

let sam = Person("Sam")

codec.encode(c, sam)
```

Returns an Elixir map like

```elixir
%{ "__type__" => "Person", "name" => "Sam" }
```

## Installation

This package can be installed by adding `gleam_codec` to your `rebar.config` dependencies:

```erlang
{deps, [
    gleam_codec
]}.
```
