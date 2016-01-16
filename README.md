<p align="center">
<b><a href="#features">Features</a></b>
|
<b><a href="#installation">Installation</a></b>
|
<b><a href="#quickstart">Quick-start guide</a></b>
|
<b><a href="#configuration">Configuration</a></b>
</p>

<br>

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/polonskiy/crowdr/blob/master/LICENSE)
[![Current Version](https://img.shields.io/badge/version-0.10.1-green.svg)](https://github.com/polonskiy/crowdr)

Extremely flexible tool for managing multiple docker containers.

# Features

- Provide commands which operates on collection of containers.
- Uses predefined description of containers from readable configuration file.
- Can use any `docker run` option that is provided by your docker version.
- The order of starting containers is defined in configuration file.
- The order of stopping containers is the reverse of the order of starting.
- Easy to install, it's just bash script.
- Allow to use bash functions (or external scripts) as container hooks for many crowdr commands.

# Installation

Become root (for example with `sudo -i`) and execute:

```
# curl -s https://raw.githubusercontent.com/polonskiy/crowdr/master/crowdr > /usr/local/bin/crowdr
# curl -s https://raw.githubusercontent.com/polonskiy/crowdr/master/completion > /etc/bash_completion.d/crowdr
```

# Quick-start guide

The following example runs simple but complete [Wordpress](https://wordpress.org/) installation on Docker which contains:
- user defined network `example01` used by all containers,
- Docker container for Wordpress MySQL database `example01-wordpress-db`,
- Docker named volume `example01-wordpress-db` for Wordpress database data,
- Docker container for Apache server which runs Wordpress web application `example01-wordpress-web`,
- Docker named volume `example01-wordpress-web` for Wordpress html data.

It uses only official docker containers, so it can be used easily and without fear to play with crowdr.

1. Create empty directory and cd into it.

2. Create crowdr.cfg.sh file (crowdr configuration file) with following content.

  ```sh
  #!/bin/bash

  crowdr_project="example01"
  crowdr_name_format="%s-%s"

  net_name=${crowdr_project}
  wordpress_db_host=$(crowdr_fullname wordpress-db)
  mysql_root_password=secret-pass
  wordpress_db_name=wordpress
  wordpress_db_user=wordpress
  wordpress_db_password=secret-pass
  wordpress_port=8080

  crowdr_config="

  # Wordpress MySQL database.
  wordpress-db image mysql:5.7.10
  wordpress-db before.run create_network
  wordpress-db net ${net_name}
  wordpress-db volume $(crowdr_fullname wordpress-db):/var/lib/mysql
  wordpress-db env MYSQL_ROOT_PASSWORD=${mysql_root_password}
  wordpress-db env MYSQL_DATABASE=${wordpress_db_name}
  wordpress-db env MYSQL_USER=${wordpress_db_user}
  wordpress-db env MYSQL_PASSWORD=${wordpress_db_password}

  # Wordpress web application on Apache webserver.
  wordpress-web image wordpress:4.3.1
  wordpress-web net ${net_name}
  wordpress-web volume $(crowdr_fullname wordpress-web):/var/www/html
  wordpress-web env WORDPRESS_DB_HOST=${wordpress_db_host}
  wordpress-web env WORDPRESS_DB_NAME=${wordpress_db_name}
  wordpress-web env WORDPRESS_DB_USER=${wordpress_db_user}
  wordpress-web env WORDPRESS_DB_PASSWORD=${wordpress_db_password}
  wordpress-web publish ${wordpress_port}:80

  "

  create_network() {
      docker network create ${net_name} &> /dev/null
  }
  ```

  The format of configuration is explained in [Configuration](#configuration) section.

3. Create and run all containers with `crowdr run`.

4. Open your browser and go to [localhost:8080](http://localhost:8080/) to check if it works.

5. Stop containers with `crowdr stop`.

6. Start containers again with `crowdr start`.

7. Check other [commands](#commands)

# Configuration

Crowdr configuration file is bash script. Crowdr require to provide three variables:

- crowdr_project - name which is typically used as prefix for name of every container
- crowdr_config - configuration of containers
- crowdr_name_format - printf format used to combine ${crowdr_project} and container name from configuration of containers into final name of container

# Commands

- `crowdr version` - prints current crowdr version

- `crowdr run` - (default) runs all containers

- `crowdr build` - builds all images

- `crowdr stop` - stops all containers (supports docker options, e.g.: `crowdr stop --time=5`)

- `crowdr start` - starts all containers

- `crowdr restart` - stops all containers and starts them again

- `crowdr kill` - kills all containers (supports docker options, e.g.: `crowdr kill --signal="KILL"`)

- `crowdr rm` - removes all stopped containers from current config (supports docker options, e.g.: `crowdr rm -f`)

- `crowdr rmi` - removes all not otherwise used images contained in current config (supports docker options, e.g.: `crowdr rmi -f`)

- `crowdr ps` - shows running containers from current config (supports docker options, e.g.: `crowdr ps -a -q`)

- `crowdr ip` - shows IP addresses of running containers from current config

- `crowdr shell foo` - start bash shell inside `foo` container

- `crowdr exec foo ls` - run `ls` inside `foo` container

- `echo 111 | crowdr pipe foo tr 1 2` - pipe data to `tr 1 2` command inside `foo` container

- `crowdr stats` - shows stats (supports docker options, e.g.: `crowdr stats --no-stream`)

## Configuration

* crowdr sources `.crowdr/config.sh`
* blank lines and lines starting with `#` are ignored.
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
database after.start wait_port database 5432

redis volume $(crowdr_fullname redis):/var/lib/redis
redis image sameersbn/redis:latest
redis before.run create_volume redis
redis after.start wait_port redis 6379

gitlab before.run create_volume gitlab
gitlab after.start wait_gitlab
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
    while ! nc -q 1 $ip $2 </dev/null &>/dev/null; do
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
