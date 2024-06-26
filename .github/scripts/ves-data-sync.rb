# github action - run on push, which executes within the VA network

require 'oci8'
require 'csv'
require 'models/std_state'

# Oracle DB connection parameters
db_username = ENV['VA_INCOME_LIMITS_VES_DB_USERNAME']
db_password = ENV['VA_INCOME_LIMITS_VES_DB_PASSWORD']
db_host = ENV['VA_INCOME_LIMITS_VES_DB_SERVER']
db_port = ENV['VA_INCOME_LIMITS_VES_DB_PORT']
db_sid = ENV['VA_INCOME_LIMITS_VES_DB_SID']
db_connection_string = "//#{db_host}:#{db_port}/#{db_sid}"

# Connect to the Oracle database
conn = OCI8.new(db_username, db_password, db_connection_string)

# Query the data for the table.
sql_query = "SELECT COUNT(*) FROM sdsadm.std_institution"
puts "Running query: " + sql_query
result = conn.exec(sql_query)

puts "Result:"
puts result
puts result.get_col_names
result.fetch_hash do |entry|
  puts entry
end
puts "Result end"
puts "DB check - StdState.count should be ~110: #{StdState.count}"

# Close the database connection
conn.logoff if conn
