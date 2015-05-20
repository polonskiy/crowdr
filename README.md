# Crowdr

Crowdr is a tool for managing multiple Docker containers.

## Why not bash/make?

* pure bash - too much boilerplate code
* make - even more boilerplate code :trollface:

## Why not docker-compose?

* lack of variables
* options support is always behind actual docker version
* `up` restarts containers in wrong order

### What is wrong with `docker-compose up`?

```yaml
client:
    image: ubuntu
    command: sleep infinity
    links:
        - server

server:
    image: ubuntu
    command: sleep infinity
```

```bash
$ docker-compose up -d
Creating test_server_1...
Creating test_client_1...
```
First start is ok. Server started before a client.

```bash
$ docker-compose up -d
Recreating test_server_1...
Recreating test_client_1...
```
As you can see, server recreated first. It means that client will lost connection.

To avoid that we need to use this order:

* stop client
* stop server
* recreate & start server
* recreate & start client

## Crowdr commands

`crowdr run` - (default) runs all containers

`crowdr build` - builds all images

`crowdr stop` - stops all containers

`crowdr ps` - shows running containers from current config

`crowdr ip` - shows IP addresses of running containers from current config

`crowdr shell foo` - start bash shell inside `foo` container

`crowdr exec foo ls` - run `ls` inside `foo` container

`echo 111 | crowdr pipe foo tr 1 2` - pipe data to `tr 1 2` command inside `foo` container

## Configuration

* crowdr sources `crowdr.cfg.sh` and read stdout
* blank lines are ignored
* lines starting with `#` are ignored.

Sample `crowdr.cfg.sh`:
```bash
#!/bin/bash

HOST="$(tr -d '-' <<< $HOSTNAME)"
PREFIX="foo"

echo "
global project ${USER}_${HOST}_myproject

mysql build docker/mysql
mysql hostname $PREFIX-mysql
mysql volume $PWD/mysql-data:/var/lib/mysql

#comment

apache build docker/apache
apache hostname $PREFIX-apache
apache memory 5g
apache link mysql
apache volume $PWD:/var/www
apache env-file config.env
"
```

Benefits:
* bash support :trollface:
* full `docker run` options support

### Global options

Currently only `project` option is supported.

```
global project myproject
```

### Build options

`build` - path to a directory containing a Dockerfile

```
container build some/path
```

### Run options

Format is following
```
container_name option value
```

[Full reference](https://docs.docker.com/reference/commandline/cli/#run)

### Internal magic

* all container names will silently prefixed with `projectname_`
* dependencies: if `foo` links to `bar`, then `bar` will started before `foo` and stopped after `foo`

## Not supported (yet)

* partial build/run/stop
* build --no-cache
* --volumes-from
* [external links](https://docs.docker.com/compose/yml/#external_links)
* [images support](https://docs.docker.com/compose/yml/#image)
