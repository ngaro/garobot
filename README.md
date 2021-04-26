# Garobot

This is yet another IRC bot.
Main difference with others: It runs as docker container

It's licensed under GPLv3 (See file `LICENSE`)

## Functionality
Does similar boring stuff other bots do.

The only nice thing that others don't provide is a command to run shell code:

`!sh for a in 1 2 3 ; do echo "Line $a : This loop is executed in the shell and the output is sent to IRC" ; done`

Some safeguards are implemented in case people want to use this create forkbombs, remove files, ...

See `!help` for other features
