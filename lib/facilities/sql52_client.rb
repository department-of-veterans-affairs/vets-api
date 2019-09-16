 # frozen_string_literal: true
require 'tiny_tds'

module Facilities
  class SQL52Client

    def initialize
      @client ||= TinyTds::Client.new(connection_config)  
    end

    def connection_config
      {
        username: Settings.sql_52.username, 
        password: Settings.sql_52.password,  
        host: Settings.sql_52.hostname, 
        port: Settings.sql_52.port,  
        database: database_name
      }
    end

    def database_name
    	# fill this out in the subclasses
    end

  end
end