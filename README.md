# Crowdr [![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/polonskiy/crowdr/blob/master/LICENSE) [![Current Version](https://img.shields.io/badge/version-0.11.0-green.svg)](https://github.com/polonskiy/crowdr)

Extremely flexible tool for managing groups of docker containers.

[Features](#features)

[Installation](#installation)

[Quick-start guide](#quick-start-guide)

[Configuration](#configuration)

[Commands](#commands)

[Hooks](#hooks)

# Features

- Provides commands which operate on collection of containers.
- Uses predefined description of containers from readable configuration file.
- Can use any `docker run` option that is provided by your docker version.
- The order of starting containers is defined in configuration file.
- The order of stopping containers is the reverse of the order of starting.
- Easy to install, it's just bash script. It doesn't require any execution environment or other libraries.
- Allows to use bash functions (or external scripts) as hooks for many crowdr commands.

# Installation

Become root (for example with `sudo -i`) and execute:

```
# curl -s https://raw.githubusercontent.com/polonskiy/crowdr/master/crowdr > /usr/local/bin/crowdr
# curl -s https://raw.githubusercontent.com/polonskiy/crowdr/master/completion > /etc/bash_completion.d/crowdr
```

Yes, that's all. No need for additional libraries or execution environments.

# Quick-start guide

### Example

The following example runs simple but complete [Wordpress](https://wordpress.org/) installation on Docker which contains:
- user defined network `example01` used by all containers,
- container for Wordpress MySQL database `example01-wordpress-db`,
- named volume `example01-wordpress-db` for Wordpress database data,
- container for Apache server which runs Wordpress web application `example01-wordpress-web`,
- named volume `example01-wordpress-web` for Wordpress html data.

It uses only official docker containers, so it can be used easily to play with crowdr.

1. Create empty directory and cd into it.

2. Create `crowdr.cfg.sh` file (crowdr configuration file) with following content.

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

  > NOTE: Please replace the passwords with stronger ones if you are going to use this example for something more serious than exploration of crowdr capabilities.

  The format of configuration file is explained in [Configuration](#configuration) section.

3. Create and start all containers with `crowdr run`.

4. Open your browser and go to [localhost:8080](http://localhost:8080/) to check if it works.

5. Stop containers with `crowdr stop`.

6. Start containers again with `crowdr start`.

7. Check other [commands](#commands).

8. If you want to remove this example entirely from your host OS, execute:

  - `crowdr stop` - to stop all containers used in this example
  - `crowdr rm` - to remove all containers used in this example
  - `crowdr rmi` - to remove all images used by this example
  - `docker volume rm example01-wordpress-db` - to remove named volume with database data
  - `docker volume rm example01-wordpress-web` - to remove named volume with Wordpress html data
  - `docker network rm example01` - to remove user defined network

# Configuration

### Format of configuration file

Crowdr configuration file is bash script. Crowdr require to provide three variables:

- `crowdr_project` - name which is typically used as prefix for name of every container
- `crowdr_name_format` - printf format used to combine ${crowdr_project} and container name from ${crowdr_config} into final name of container
- `crowdr_config` - configuration of containers

The `crowdr_config` value is multi-line string. Blank lines and lines starting with `#` are ignored. Every other lines should have following format:

`container_name option_name option_value`

where:

- `container_name` is arbitrary name of container

  Note that final name of container is determined by crowdr using `crowdr_name_format` as combination of container name and value of `crowdr_project`.

- `option_name` is name of [crowdr option](#crowdr-options) or run option.

  Values of options `image`, `command`, `build`, `after.*` `before.*` are [crowdr option](#crowdr-options) used by various crowdr commands. All other values are run options, they are not interpreted in any way but are blindly passed to `docker run`. Please consult the [Docker run reference](https://docs.docker.com/engine/reference/run/) to know what can be used as run option.

- `option_value` is the value of option

As an example consider following crowdr configuration:

```sh
#!/bin/bash

crowdr_project="example02"
crowdr_name_format="%s-%s"

crowdr_config="
postgresql image postgres:9.4.5
postgresql env POSTGRES_PASSWORD=secret-pass
postgresql volume $(crowdr_fullname postgresql-data):/var/lib/postgresql/data
"
```

After executing `crowdr run` the following command will be run:

```sh
docker run -td \
           --name   example02-postgresql \
           --env    POSTGRES_PASSWORD=secretpass \
           --volume postgresql-data:/var/lib/postgresql/data \
           postgres:9.4.5
```

### Location and name of configuration file

- If `CROWDR_CFG` variable was exported before running crowdr then the value of this variable will be used as filename of crowdr configuration.
- Otherwise if the current directory contains `.crowdr` folder then `.crowdr/config.sh` is used as configuration file.
- Otherwise `crowdr.cfg.sh` from current directory is used.

### Crowdr options

- `build`

  Path to a directory containing a Dockerfile. This path is used during execution of `crowdr build`.

- `image`

  This is image name crowdr use to create container. If it is not provided then container name is used as image name.

- `command`

  Value of this option overrides CMD from Dockerfile/image.

- `before.*` and `after.*` (container hooks)

  Name of hook bash function runned before/after execution of specified command for given container. Container hooks can be used for following crowdr commands: run, build, start, stop, kill, rm and rmi.

  In the below example, after starting redis container, crowdr waits for opening 6379 port.

  ```sh
  #!/bin/bash

  crowdr_project="example03"
  crowdr_name_format="%s_%s"

  redis image redis:3.0.6
  redis after.start wait_port redis 6379

  wait_port() {
      ip=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(crowdr_fullname $1))
      echo "Waiting for $1"
      while ! nc -q 1 $ip $2 </dev/null &>/dev/null; do
          echo -n .
          sleep 1;
      done
      echo
  }
  ```

# Commands

The commands operates only on containers and images specified in configuration.

- `crowdr run`

  Creates and starts all containers. They are started in the order specified in configuration file.

  > NOTE: If any of the containers already exist then they are removed with --force option.

- `crowdr start`

  Starts all containers. They are started in the order specified in configuration file.

- `crowdr stop`

  Stops all containers. They are stopped in the order reversed to specified in configuration file. Command supports docker options, e.g.: `crowdr stop --time=5`).

- `crowdr restart`

  Executes `crowdr stop` and then `crowdr start`.

- `crowdr ps`

  Shows running containers (supports docker options, e.g.: `crowdr ps -a -q`).

- `crowdr ip`

  Shows IP addresses of running containers.

- `crowdr stats`

  Shows stats (supports docker options, e.g.: `crowdr stats --no-stream`).

- `crowdr shell foo`

  Starts bash shell inside `foo` container.

- `crowdr build` - builds all images

  Builds all containers which have specified dockerfile path with `build` crowdr option.

- `crowdr kill`

  Kills all containers (supports docker options, e.g.: `crowdr kill --signal="KILL"`)

- `crowdr rm`

  Removes all containers (supports docker options, e.g.: `crowdr rm -f`).

- `crowdr rmi`

  Removes all not used images (supports docker options, e.g.: `crowdr rmi -f`).

- `crowdr exec foo ls`

  Runs `ls` inside `foo` container.

- `echo 111 | crowdr pipe foo tr 1 2`

  Pipe data to `tr 1 2` command inside `foo` container

- `crowdr version`

  Prints current crowdr version.

> To enable debug mode set `CROWDR_TRACE` variable.
>
> ```sh
> CROWDR_TRACE=1 crowdr run |& less
> ```
>
> To review planned commands without executing them set `CROWDR_DRY` variable.
> ``` sh
> CROWDR_DRY=1 crowdr |& less
> ```

# Hooks & Aliases

Every crowdr command can be extended.
Lets say you want to pull in some Dockerfiles from remote repositories *before* running `crowdr build`.

    $ mkdir .crowdr/hooks
    $ echo 'echo pulling repos' > .crowdr/hooks/before.build
    $ echo 'git clone http://github.com/someuser/docker.redis' >> .crowdr/hooks/before.build
    $ echo 'git clone http://github.com/someuser/docker.proxy' >> .crowdr/hooks/before.build
    $ chmod 755 .crowdr/hooks/*
    $ crowdr build
    pulling repos

Crowdr detects both `before.*` and `after.*` hooks of each crowdr command.

Crowdr supports also hooks executed only for specified containers. See `before.*` and `after.*` in [crowdr options](#crowdr-options).

Aliases are also supported in a similar way, to easily automate manual docker plumbing:

    $ mkdir .crowdr/hooks
    $ echo 'docker kill $(crowdr_fullname mycontainer)' > .crowdr/hooks/cleanup
    $ chmod 755 .crowdr/hooks/cleanup
    $ ./crowdr
    Usage:
      crowdr rm
      crowdr rmi
      ...
      crowdr cleanup                      <--- your alias

    $ ./crowdr cleanup

