# Python 3 Starter
/Disclaimer: developed with Python 3.5.2, tested with Python 2.7.10 - not guaranteed to work with other versions/

## Instructions
`python client.py [optional port]`

## Recommended Software
* Python 3.5.2
* [Pyenv](https://github.com/pyenv/pyenv)

## Running with Docker

The included Dockerfile will copy and run with `python`

To build:

```sh
docker buildx build -f Dockerfile ./ -t client-python
```

To run:

```sh
docker run -p 9090:9090 client-python
```

