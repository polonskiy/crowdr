# Crowdr

Crowdr is a extremely flexible Docker orchestrator

## Installation

```
# curl -s https://raw.githubusercontent.com/polonskiy/crowdr/master/crowdr > /usr/local/bin/crowdr
# curl -s https://raw.githubusercontent.com/polonskiy/crowdr/master/completion > /etc/bash_completion.d/crowdr
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

crowdr_project="example"
crowdr_name_format="%s_%s"

crowdr_config="
database env DB_NAME=gitlabhq_production
database env DB_USER=gitlab
database env DB_PASS=password
database volume $(crowdr_fullname database):/var/lib/postgresql
database image sameersbn/postgresql:9.4-11
database before.run create_volume database
database after.run wait_port database 5432

redis volume $(crowdr_fullname redis):/var/lib/redis
redis image sameersbn/redis:latest
redis before.run create_volume redis
redis after.run wait_port redis 6379

gitlab before.run create_volume gitlab
gitlab after.run wait_gitlab
gitlab link database:postgresql
gitlab link redis:redisio
gitlab publish 10022:22
gitlab publish 10080:80
gitlab env GITLAB_PORT=10080
gitlab env GITLAB_SSH_PORT=10022
gitlab env GITLAB_SECRETS_DB_KEY_BASE=long-and-random-alpha-numeric-string
gitlab volume $(crowdr_fullname gitlab):/home/git/data
gitlab image sameersbn/gitlab:8.3.2
"

create_volume() {
    docker volume create --name=$(crowdr_fullname $1) > /dev/null
}

wait_port() {
    ip=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(crowdr_fullname $1))
    echo "Waiting for $1"
    while ! nc -q 1 $ip $2 </dev/null >/dev/null; do
        echo -n .
        sleep 1;
    done
    echo
}

wait_gitlab() {
    echo "Waiting for gitlab"
    while ! curl -ILs http://localhost:10080 | grep -q '200 OK'; do
        echo -n .
        sleep 1;
    done
    echo
    xdg-open http://localhost:10080
}
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
