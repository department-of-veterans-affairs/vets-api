require 'oci8'
require 'csv'

# Oracle DB connection parameters
db_username = ENV['VA_INCOME_LIMITS_VES_DB_USERNAME']
db_password = ENV['VA_INCOME_LIMITS_VES_DB_PASSWORD']
db_host = ENV['VA_INCOME_LIMITS_VES_DB_SERVER']
db_port = ENV['VA_INCOME_LIMITS_VES_DB_PORT']
db_sid = ENV['VA_INCOME_LIMITS_VES_DB_SID']
db_connection_string = "//#{db_host}:#{db_port}/#{db_sid}"

# Define csv files hash with table names as the index.
files = {
  "sdsadm.std_zipcode": "std_zipcode.csv",
  "sdsadm.std_state": "std_state.csv",
  "sdsadm.std_incomethreshold": "std_incomethreshold.csv",
  "sdsadm.std_gmtthresholds": "std_gmtthresholds.csv",
  "sdsadm.std_county": "std_county.csv",
}

# Define temp directory
temp_directory = ENV['TEMP_FOLDER']

# Connect to the Oracle database
conn = OCI8.new(db_username, db_password, db_connection_string)

files.each do |table, file|
  # Query the data for the table.
  sql_query = "SELECT * FROM #{table}"
  puts "Running query: " + sql_query
  result = conn.exec(sql_query)

  # Create a CSV file from the results in the temp directory.
  CSV.open("#{temp_directory}/#{file}", 'w') do |csv|
    # Write header
    csv << result.get_col_names

    # Write rows
    result.fetch do |row|
      csv << row
    end
  end
end

# Close the database connection
conn.logoff if conn
