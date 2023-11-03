FROM ruby:3.2.2

RUN gem install bundler

WORKDIR /usr/src/app

COPY Gemfile Gemfile

RUN bundle install

COPY . .

EXPOSE 9090
CMD ["ruby", "rts.rb", "9090"]
