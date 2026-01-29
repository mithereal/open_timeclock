# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20210902-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.13.3-erlang-25.0.3-debian-bullseye-20210902-slim
#

ARG APP_NAME=timeclock
ARG ORGANIZATION="hexpm/elixir"

ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.3
ARG OS=debian
ARG OS_VERSION=bullseye
ARG OS_RELEASE="20250224-slim"
ARG BUILDER_IMAGE="${ORGANIZATION}:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-${OS}-${OS_VERSION}-${OS_RELEASE}"
ARG RUNNER_IMAGE="${OS}:${OS_VERSION}-${OS_RELEASE}"

FROM ${BUILDER_IMAGE} as builder
ENV TZ=US \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
     apt-get install -y \
             build-essential \
             git \
             npm  \
             zstd \
             libvips-dev  \
             webp esbuild && \
     apt-get clean && \
     rm -f /var/lib/apt/lists/*_*

WORKDIR "/app"
# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

# Install / update  JavaScript dependencies
RUN npm install --prefix ./assets

COPY assets assets
#COPY static static

# Compile the release
RUN mix compile
# compile assets
#RUN mix bun install
RUN mix assets.deploy


# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}
ENV TZ=US \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && apt-get install -y  zstd tini curl nano tzdata bash libstdc++6 curl gifsicle libcairo2 libjpeg-turbo-progs openssl libncurses5 locales webp git libvips-dev npm\
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen


ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

ENV TERM="xterm-256color" \
TIME_STYLE="long-iso"

ARG TZ='UTC'
ENV TZ=$TZ

#These params meant to be set by CI
ARG BUILD_DATE=Undefined
ENV BUILD_DATE=$BUILD_DATE
RUN echo $BUILD_DATE
ARG BUILD_FINGERPRINT=Undefined
ENV BUILD_FINGERPRINT=$BUILD_FINGERPRINT
RUN echo $BUILD_FINGERPRINT

ENV LOG_LEVEL="warning"
ENV PORT="8888"
ENV NUM_PROCESSES=0

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/prod/rel/timeclock ./
#HEALTHCHECK --timeout=15s CMD curl --silent --fail http://127.0.0.1:${PORT}/healthcheck

USER nobody
EXPOSE 80
ENV PORT=80

CMD ["/app/bin/server"]

# Appended by flyctl
ENV ECTO_IPV6 true
ENV ERL_AFLAGS "-proto_dist inet6_tcp"

