require 'mongo'

Mongo::Logger.logger.level = ::Logger::INFO

uri = 'mongodb://admin:changemebro@mongodb-audit-db:27017/mongodb-audit-db?authSource=admin'

client = Mongo::Client.new(uri)

MongoDB = client.database


# Check connection
begin
  client.database_names
  puts "Connected to MongoDB successfully!"
rescue Mongo::Error::NoServerAvailable => e
  puts "Error: Unable to connect to MongoDB - #{e.message}"
end