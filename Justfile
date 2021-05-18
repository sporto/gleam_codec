test:
	rebar3 eunit

publish:
	rebar3 hex publish

docs:
	gleam docs build --version 0.2.0

docs-preview:
	sfz -r ./gen/docs/