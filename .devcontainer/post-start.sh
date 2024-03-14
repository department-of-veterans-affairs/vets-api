#!/bin/sh

sudo /etc/init.d/postgresql restart
pg_isready -t 60
nohup bash -c 'foreman start -m all=1,clamd=0,freshclam=0 >> log/foreman.log 2>&1 &'
