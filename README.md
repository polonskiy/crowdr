# Crowdr

Crowdr is a extremely flexible tool for managing multiple Docker containers.

## Why not bash/make?

* pure bash - too much boilerplate code
* make - even more boilerplate code :trollface:

## Why not docker-compose?

* lack of variables
* options support is always behind actual docker version
* `up` restarts containers in wrong order
* hasslefree replacement for non x86/x86_64 architectures

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
As you can see, server recreated first. It means that client will loose the connection.

To avoid that we need to use this order:

* stop client
* stop server
* recreate & start server
* recreate & start client

## Installation

```
# curl -s https://raw.githubusercontent.com/polonskiy/crowdr/0.10.0/crowdr > /usr/local/bin/crowdr
# curl -s https://raw.githubusercontent.com/polonskiy/crowdr/0.10.0/completion > /etc/bash_completion.d/crowdr
```

## Crowdr commands

`crowdr version` - prints current crowdr version

`crowdr run` - (default) runs all containers

`crowdr build` - builds all images

`crowdr stop` - stops all containers

`crowdr start` - starts all containers

`crowdr restart` - stops all containers and starts them again

`crowdr kill` - kills all containers

`crowdr rm` - removes all stopped containers from current config

`crowdr rmi` - removes all not otherwise used images contained in current config

`crowdr ps` - shows running containers from current config

`crowdr ip` - shows IP addresses of running containers from current config

`crowdr shell foo` - start bash shell inside `foo` container

`crowdr exec foo ls` - run `ls` inside `foo` container

`echo 111 | crowdr pipe foo tr 1 2` - pipe data to `tr 1 2` command inside `foo` container

`crowdr stats` - shows stats

## Configuration

* crowdr sources `.crowdr/config.sh` and read stdout
* blank lines are ignored
* lines starting with `#` are ignored.
* you can override config filename using `CROWDR_CFG` variable (`CROWDR_CFG=~/foo/bar/baz.sh crowdr`)
* you can enable debug mode using `CROWDR_TRACE` variable (`CROWDR_TRACE=1 crowdr |& less`)
* review planned commands without executing them using `CROWDR_DRY` variable (`CROWDR_DRY=1 crowdr |& less`)
* containers run in the order as in config, stop in reversed

Sample `.crowdr/config.sh`:
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
apache after.run sleep 5s
"
```

Benefits:
* bash support :trollface:
* full `docker run` options support

### `project` option (global)

```
global project myproject
```

Global option for name of project. All container names will be silently prefixed with this name and separator char. If it is not set current directory name used.

### `project_sep` option (global)

```
global project_sep "_"
```

Separator string used after project name. If it is not set `_` is used.

For example for following configuration all containers will be prefixed with `myproj-`

```
global project myproj
global project_sep "-"
```

### `build` option

`build` - path to a directory containing a Dockerfile

```
container_name build some/path
```

### `image` option

`image` - image name. If image doesn't exists docker will try to download it.

```
container_name image ubuntu:14.04
```

### `command` option

`command` - overrides `CMD` from Dockerfile/image

```
container_name command tail -f /dev/null
```

### Run options

Format is following
```
container_name option value
```

[Full reference](https://docs.docker.com/reference/commandline/cli/#run)

### Hooks

Every crowdr command can be extended.
Lets say you want to pull in some Dockerfiles from remote repositories *before* running `crowdr build`.

    $ mkdir .crowdr/hooks
    $ echo 'echo pulling repos' > .crowdr/hooks/build.before
    $ echo 'git clone http://github.com/someuser/docker.redis' >> .crowdr/hooks/build.before
    $ echo 'git clone http://github.com/someuser/docker.proxy' >> .crowdr/hooks/build.before
    $ chmod 755 .crowdr/hooks/*
    $ crowdr build
    pulling repos

Crowdr detects both `.before` and `.after`-hooks of each crowdr command.

## Not supported (yet)

* partial build/run/stop
* build --no-cache
* --volumes-from
* [external links](https://docs.docker.com/compose/yml/#external_links)
