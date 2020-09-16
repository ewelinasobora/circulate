FROM ruby:2.7.1-alpine AS builder

LABEL maintainer="jeanine@littleforestconsulting.com"

RUN apk update && apk upgrade && apk add --update --no-cache \
  build-base \
  curl-dev \
  git \
  nodejs \
  postgresql-dev \
  tzdata \
  vim \
  yarn && rm -rf /var/cache/apk/*

ARG RAILS_ROOT=/usr/src/app/

COPY Gemfile* $RAILS_ROOT
COPY package*.json $RAILS_ROOT
COPY yarn.lock $RAILS_ROOT

WORKDIR $RAILS_ROOT

COPY gems/ $RAILS_ROOT/gems
RUN bundle config --global frozen 1 && bundle install
RUN yarn install --check-files

COPY . .

### BUILD STEP DONE ###

FROM ruby:2.7.1-alpine

ARG RAILS_ROOT=/usr/src/app/

RUN apk update && apk upgrade && apk add --update --no-cache \
  bash \
  imagemagick \
  nodejs \
  postgresql-client \
  tzdata \
  vim \
  yarn && rm -rf /var/cache/apk/*

WORKDIR $RAILS_ROOT

COPY --from=builder $RAILS_ROOT $RAILS_ROOT
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

EXPOSE 3000

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["bin/rails", "s", "-b", "0.0.0.0"]
