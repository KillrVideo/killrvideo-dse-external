# KillrVideo DSE Docker

[![Build Status](https://travis-ci.org/KillrVideo/killrvideo-dse-external.svg?branch=master)](https://travis-ci.org/KillrVideo/killrvideo-dse-external)

Connect KillrVideo to an external [DataStax Enterprise][dse] cluster from a Docker container. 
Contains startup scripts to 
bootstrap the CQL and DSE Search resources needed by the [KillrVideo][killrvideo] app. Based
on this [DSE image][dse-docker].
I kept this in a Docker container loaded with a DSE node because we still need access to DSE node commands
like dsetool and cqlsh in order to run scripts against the cluster. This also allows a simple, containerized way
to hook up to an external cluster, create any keyspaces and content needed, spoof ETCD to "register" the
external cluster with the rest of the micro-services, and provide an easy way to switch between the external (this)
and the original killrvideo-dse-docker image.

I've created this repo as a convenience to make it easy to hook up to an external cluster and create the needed resources.  I don't really recommend this ever being done in a production instance. 

## Builds and Releases

The `./build` folder contains a number of scripts to help with builds and releases. Continuous
integration builds are done by Travis and any commits that are tagged will also automatically
be released to the [Docker Hub][docker-hub] page. We try to follow semantic versioning,
however the version numbering is not related to what version of DSE we're using. For example,
version `1.0.0` uses DSE version `4.8.10`.

[dse]: http://www.datastax.com/products/datastax-enterprise
[killrvideo]: https://killrvideo.github.io/
[dse-docker]: https://github.com/LukeTillman/dse-docker
[docker-hub]: https://hub.docker.com/r/killrvideo/killrvideo-dse/
