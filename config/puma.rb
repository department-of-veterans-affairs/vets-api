#!/usr/bin/env puma
# frozen_string_literal: true

if ENV['USE_LOCAL_SSL']
  ssl_bind '127.0.0.1',
           '3000',
           key: 'config/certs/server.key',
           cert: 'config/certs/server.crt'
end
