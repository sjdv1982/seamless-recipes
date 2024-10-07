# Multiple delegation

## Rationale

In the current Seamless version (0.13), delegation is set up using `seamless-delegate` and
`seamless-delegate-remote`. The hashserver (read_buffer_server) and the database have a static IP address+port. These addresses are used statically by all the assistants in current use
(mini, micro and *-dask), and must be used by the Seamless instance as well.

In a future Seamless version, there will be `seamless-assistant`. This will support
dynamic configuration of the hashserver (read_buffer_server) and the database, obsoleting
`seamless-delegate`. In the meantime, the current document describes how you can set up multiple delegation, so that you can run different Seamless projects in parallel.

## Overall idea

You create a config file that you source with bash, then you call `seamless-delegate`. In another terminal (or the same one), you source the config, and then you call `seamless-ipython` or whatever you use to launch the Seamless instance.

## COMPOSE_PROJECT_NAME

By default, `seamless-delegate` services have project name "delegate". A new `seamless-delegate` command, even with different ports, will shut down the existing services before starting new ones. Choose a unique COMPOSE_PROJECT_NAME to avoid this.

## SEAMLESS_HASHSERVER_DIRECTORY

The directory where buffers will be stored in.
Not needed for `seamless-delegate-remote`.

## HASHSERVER_LAYOUT

The layout of the hashserver directory.
By default, "flat". Set this to "prefix" if you wish to store very many buffers.
Not needed for `seamless-delegate-remote`.

## SEAMLESS_DATABASE_DIRECTORY

The directory where seamless.db will be stored in.
Not needed for `seamless-delegate-remote`.

## SEAMLESS_READ_BUFFER_FOLDERS

This can be empty. Anyway, it doesn't work with a typical assistant (because the assistant is containerized). However, after running `seamless-delegate`, you can set it to SEAMLESS_HASHSERVER_DIRECTORY to save network bandwidth.

## SEAMLESS_WRITE_BUFFER_SERVER, SEAMLESS_READ_BUFFER_SERVERS, SEAMLESS_DATABASE_IP

Define these only if you wish to use `seamless-delegate-remote`. Otherwise, define SEAMLESS_HASHSERVER_PORT and SEAMLESS_DATABASE_PORT.

## SEAMLESS_HASHSERVER_PORT

Define this only if you are not defining SEAMLESS_WRITE_BUFFER_SERVER and SEAMLESS_READ_BUFFER_SERVERS.
Default value is 5577. Choose a different unique value.

## SEAMLESS_DATABASE_PORT

Define this even if you are defining SEAMLESS_DATABASE_IP.
Default value is 5522. Choose a different unique value.

## SEAMLESS_ASSISTANT_PORT

Default value is 5533. Choose a different unique value.
