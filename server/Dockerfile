FROM ruby:3.2.2

RUN apt-get update && apt-get install -y libsdl2-dev

RUN gem install bundler gosu

WORKDIR /usr/src/app

COPY Gemfile Gemfile

RUN bundle install

COPY . .
CMD ["ruby", "src/app.rb", "-nu", "-f", "-p1p", "9090", "-p1", "p1", "-p2p", "9090", "-p2", "p2" ]
