FROM debian:jessie
MAINTAINER Tom Noonan II <thomas.noonan@corvisa.com>

RUN apt-get update && apt-get install -y ruby bundler git

COPY ./ /gem_build
RUN cd /gem_build; rm -r pkg; bundle install && rake install

RUN useradd -m flapjackconf
USER flapjackconf
ENTRYPOINT ["/usr/local/bin/flapjack_configurator"]
