nbd-server
==========

A Network Block Device server written in CoffeeScript. Currently supports reading from a Filesystem or an HTTP server.

Motivation
==========

I've been interested in writing an NBD server for a while.
I've also wanted to learn about node and CoffeeScript.
I think node is a good choice for an NBD server because it's relatively easy to reason about (because it's single-threaded) and it's non-blocking.

Usage
=====

It depends on your environment.
I googled around quite a bit to set up my environment (but there is nothing special about it).
I am using Lubuntu 13.04 and a combination of npm, node, and coffeescript to run the server.

It supports reading from disk images from the filesystem or an http server. I will add more protocols in the future.

coffee nbdserver.coffee 8124 fs   /home/jdoe/disk-image

coffee nbdserver.coffee 8124 http http://example.com:80/disk-image

Caveats
=======

This code is not production ready.

Only supports reads.
