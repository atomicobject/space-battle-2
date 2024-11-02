# Java AO RTS SDK

Tested with Java 11 and Java 21.

## Running the client

Use your IDEs built-in functions to build and run the java class path.

OR

Build: `javac src/com/atomicobject/rts/*.java -d bin/ -cp lib/json-simple-1.1.1.jar`

`cd bin`

Run: `java -cp ./:../lib/json-simple-1.1.1.jar com.atomicobject.rts.Main 9090`

## Running with Docker

The included Dockerfile will build and run the client on port 9090

To build:

```sh
docker buildx build -f Dockerfile ./ -t client-java
```

To run:

```sh
docker run -p 9090:9090 client-java
```
