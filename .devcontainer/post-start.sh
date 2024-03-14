#!/bin/sh

nohup bash -c '/home/linuxbrew/.linuxbrew/opt/redis@6.2/bin/redis-server /home/linuxbrew/.linuxbrew/etc/redis.conf' >> log/redis.log 2>&1 &

sudo /etc/init.d/postgresql restart
pg_isready -t 60

nohup bash -c 'foreman start -m all=1,clamd=0,freshclam=0' >> log/foreman.log 2>&1 &
