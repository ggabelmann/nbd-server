nbd-server
==========

A Network Block Device server written in CoffeeScript. Currently supports reads, but not writes.

Motivation
==========

I've been interested in writing an NBD server for a while.
I've also wanted to learn about node and CoffeeScript.
I think node is a good choice for an NBD server because it's so scalable.

Usage
=====

It depends on your environment.
I googled around quite a bit to set up my environment (but there is nothing special about it).
I am using Lubuntu 13.04 and use a combination of npm, node, and coffeescript to run the server.

coffee nbdserver.coffee 8124 /path/to/image

Caveats
=======

This code is not production ready.

Only supports reads.
