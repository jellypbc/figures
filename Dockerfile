FROM jruby:9.2.9.0

RUN apt-get update -qq && apt-get install -yq --no-install-recommends build-essential

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile* $APP_HOME/

RUN gem update --system && \
    gem install bundler:2.1.2
RUN bundle install

ADD . $APP_HOME

EXPOSE 4567

CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4567"]