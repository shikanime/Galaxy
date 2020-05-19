FROM elixir:1.10.0-alpine@sha256:45718ab3fd121b83abe15c087e7fadb45e8498839b9bca37b2260f6333516521 AS source

ARG MIX_ENV=prod

WORKDIR /workspace

RUN apk update && apk add --no-cache git
RUN mix do local.hex --force, local.rebar --force

COPY mix.exs mix.lock ./
ENV MIX_ENV=${MIX_ENV}
RUN mix do deps.get --only ${MIX_ENV}, deps.compile, compile

COPY config config
RUN mix cmd --app cruise_web mix phx.digest

COPY . .
RUN mix release

FROM erlang:22.2.6-alpine@sha256:5bf9d368ffeec3e675eafe9020046f9a24219797d1d5601e43b4af752d39dc9f

WORKDIR /hello_kubernetes

COPY --from=source /workspace/_build/prod/rel/hello_kubernetes .

ENV PATH=/hello_kubernetes/bin:$PATH
EXPOSE 4369
EXPOSE 49200
CMD ["hello_kubernetes", "start"]
