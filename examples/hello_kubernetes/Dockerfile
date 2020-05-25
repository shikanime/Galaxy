FROM hexpm/elixir:1.10.3-erlang-23.0.1-alpine-3.11.6@sha256:367c6ca84a3056f809af8057616737347c26cd633fedf9f969678ddadbd58dde AS source

WORKDIR /workspace/examples/hello_kubernetes/

RUN apk update && apk add --no-cache git
RUN mix do local.hex --force, local.rebar --force

COPY . /workspace/
RUN mix do deps.get, release --overwrite

ENV PATH=/workspace/examples/hello_kubernetes/_build/dev/rel/hello_kubernetes/bin:$PATH
EXPOSE 7654
CMD ["hello_kubernetes", "start"]