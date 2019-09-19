# frozen_string_literal: true

require 'tiny_tds'

module Facilities
  class SQL52Client
    def initialize
      @client ||= TinyTds::Client.new(connection_config)
    end

    def connection_config
      {
        username: Settings.oit_lighthouse2.sql52.username,
        password: Settings.oit_lighthouse2.sql52.password,
        host: Settings.oit_lighthouse2.sql52.hostname,
        port: Settings.oit_lighthouse2.sql52.port,
        database: database_name
      }
    end

    def database_name
      raise NotImplementedError, 'Child classes of Facilities::SQL52Client require a database_name method'
    end
  end
end
