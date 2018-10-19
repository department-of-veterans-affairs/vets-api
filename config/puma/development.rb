# frozen_string_literal: true

ssl_bind '0.0.0.0',
         '3000',
         key: 'config/certs/localhost.key',
         cert: 'config/certs/localhost.crt'
