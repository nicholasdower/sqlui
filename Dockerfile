# syntax=docker/dockerfile:1
FROM ruby:3.0
RUN curl -sL https://deb.nodesource.com/setup_19.x | bash -

RUN apt-get update -qq
RUN apt-get install -qq --no-install-recommends nodejs
RUN apt-get upgrade -qq
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

ENV BUNDLE_APP_CONFIG /sqlui/.bundle
