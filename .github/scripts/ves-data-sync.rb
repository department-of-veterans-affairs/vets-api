# github action - run on push, which executes within the VA network

require 'csv'
require 'oci8'

# require_relative '../../config/environment.rb'

# Oracle DB connection parameters
db_username = ENV['VA_INCOME_LIMITS_VES_DB_USERNAME']
db_password = ENV['VA_INCOME_LIMITS_VES_DB_PASSWORD']
db_host = ENV['VA_INCOME_LIMITS_VES_DB_SERVER']
db_port = ENV['VA_INCOME_LIMITS_VES_DB_PORT']
db_sid = ENV['VA_INCOME_LIMITS_VES_DB_SID']
db_connection_string = "//#{db_host}:#{db_port}/#{db_sid}"
puts "Connecting to: #{db_connection_string}"

# Define temp directory
temp_directory = ENV['TEMP_FOLDER']

# Connect to the Oracle database
conn = OCI8.new(db_username, db_password, db_connection_string)

# Query the data for the table.
sql_query = "SELECT * FROM sdsadm.std_institution"
puts "Running query: #{sql_query}"
result = conn.exec(sql_query)

puts result.get_col_names

puts "Writing to CSV at #{temp_directory}/std_institution.csv"
CSV.open("#{temp_directory}/std_institution.csv", 'w') do |csv|
  puts "CSV open"
  csv << result.get_col_names
  puts "CSV open, cols written"
  index = 0
  result.fetch do |row|
    csv << row
    index += 1
  end
  puts "CSV closed with #{index} rows"
end

# Close the database connection
conn.logoff if conn
