# frozen_string_literal: true

require 'mongo'

Mongo::Logger.logger.level = Logger::INFO

uri = 'mongodb://localhost:27017/mongodb-audit-db'

client = Mongo::Client.new(uri)

MongoDB = client.database

# Check connection
begin
  client.database_names
  Rails.logger.debug 'Connected to MongoDB successfully!'
rescue Mongo::Error::NoServerAvailable => e
  Rails.logger.debug { "Error: Unable to connect to MongoDB - #{e.message}" }
end
