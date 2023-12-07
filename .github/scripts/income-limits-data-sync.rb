# query_oracle.rb

require 'oci8'
require 'csv'

# # Oracle DB connection parameters
# db_username = 'your_username'
# db_password = 'your_password'
# db_connection_string = 'your_connection_string'

# # SQL query
# sql_query = 'SELECT * FROM your_table'

# # Output CSV file
# output_csv_file = 'query_result.csv'

# # Connect to the Oracle database
# conn = OCI8.new(db_username, db_password, db_connection_string)

# # Execute the SQL query
# result = conn.exec(sql_query)

# # Write results to a CSV file
# CSV.open(output_csv_file, 'w') do |csv|
#   # Write header
#   csv << result.get_col_names

#   # Write rows
#   result.fetch do |row|
#     csv << row
#   end
# end

# # Close the database connection
# conn.logoff

puts "Hello, World!"