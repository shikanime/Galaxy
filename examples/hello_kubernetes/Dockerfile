# syntax = docker/dockerfile:experimental

FROM hexpm/elixir:1.10.3-erlang-23.0.1-alpine-3.11.6 AS builder

WORKDIR /agonex/src/examples/hello_kubernetes/

RUN --mount=type=cache,id=apk,sharing=locked,target=/var/cache/apk \
  apk add --update git
RUN mix do local.hex --force, local.rebar --force

COPY mix.* /agonex/src/
COPY examples/hello_kubernetes/mix.* ./

RUN --mount=id=hex-cache,type=cache,sharing=locked,target=/root/.hex \
  --mount=id=deps-cache,type=cache,sharing=locked,target=./deps \
  mix do deps.get

COPY lib /agonex/src/lib
COPY examples/hello_kubernetes/lib ./lib
COPY examples/hello_kubernetes/config ./config
COPY examples/hello_kubernetes/rel ./rel

FROM builder AS releaser

RUN --mount=id=deps-cache,type=cache,sharing=locked,target=./deps \
  mix release --overwrite

FROM alpine:3.11.6 AS runner

RUN --mount=type=cache,id=apk,sharing=locked,target=/var/cache/apk \
  ln -vs /var/cache/apk /etc/apk/cache && \
  apk add --update openssl ncurses

ENV RELEASE_TMP=/tmp

COPY --from=releaser /agonex/src/examples/hello_kubernetes/_build/dev/rel/hello_kubernetes /hello_kubernetes

ENV PATH=/hello_kubernetes/bin:$PATH

ENTRYPOINT [ "hello_kubernetes" ]
CMD ["start"]
