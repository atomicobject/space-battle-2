FROM clojure
COPY . /usr/src/app
WORKDIR /usr/src/app

RUN lein deps

EXPOSE 9090
CMD ["lein", "run"]
