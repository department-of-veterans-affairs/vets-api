# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'
require 'roo'

module RepAddresses
  # A Sidekiq job class for processing address and email updates from an Excel file.
  # This job fetches the file content, processes each sheet, and enqueues updates.
  class QueueAddressUpdates
    include Sidekiq::Job
    include SentryLogging

    SHEETS_TO_PROCESS = %w[Attorneys Representatives].freeze
    BATCH_SIZE = 5000

    # Performs the job of fetching and processing the file content.
    def perform
      file_content = RepAddresses::XlsxFileFetcher.new.fetch

      unless file_content
        log_error('Failed to fetch file or file content is empty')
        return
      end

      process_file(file_content)
    rescue => e
      log_error("Error in file fetching process: #{e.message}")
    end

    private

    # Processes the file content by opening the spreadsheet and processing each sheet.
    # @param file_content [String] The content of the file to be processed.
    def process_file(file_content)
      xlsx = Roo::Spreadsheet.open(StringIO.new(file_content), extension: :xlsx)

      SHEETS_TO_PROCESS.each do |sheet_name|
        next unless xlsx.sheet(sheet_name)

        # Build the column index map from the header row
        column_map = build_column_index_map(xlsx.sheet(sheet_name).row(1))

        batch = Sidekiq::Batch.new
        batch.description = "Batching #{sheet_name} sheet records"

        batch.jobs do
          xlsx.sheet(sheet_name).each_row_streaming(header: true, pad_cells: true).each_slice(BATCH_SIZE) do |rows_batch|
            rows_batch.each_with_index do |row, index|
              next if index.zero? || row.length < column_map.length

              json_data = create_json_data(row, sheet_name, column_map)
              RepAddresses::UpdateAddresses.perform_async(json_data)
            end
          end
        end
      rescue => e
        log_error("Error processing sheet '#{sheet_name}': #{e.message}")
      end
    rescue Roo::Error => e
      log_error("Error opening spreadsheet: #{e.message}")
    end

    # Builds a column index map from a header row.
    # @param header_row [Array] The header row of a sheet.
    # @return [Hash] A mapping of column names to their indices.
    def build_column_index_map(header_row)
      header_row.each_with_index.with_object({}) do |(cell, index), map|
        map[cell] = index
      end
    end

    # Creates JSON data for a given row based on the sheet name and column map.
    # @param row [Array] The row data to be transformed into JSON.
    # @param sheet_name [String] The name of the sheet being processed.
    # @param column_map [Hash] The column index map for the sheet.
    # @return [String] The JSON representation of the row data.
    def create_json_data(row, sheet_name, column_map)
      is_vso = sheet_name == 'VSOs'
      zip_code5, zip_code4 = format_zip_code(row, column_map, is_vso)

      {
        id: row[column_map['Number']].value,
        type: 'representative',
        email_address: format_email_address(row, sheet_name, column_map),
        request_address: {
          address_pou: 'RESIDENCE/CHOICE',
          address_line1: format_address_line1(row, column_map, is_vso),
          address_line2: format_address_line2(row, column_map, is_vso),
          address_line3: format_address_line3(row, column_map, is_vso),
          city: format_city(row, column_map, is_vso),
          state_province: { code: format_state_province_code(row, column_map, is_vso) },
          zip_code5:,
          zip_code4:,
          country_code_iso3: 'US'
        }
      }.to_json
    rescue => e
      log_error("Error transforming data to JSON for #{sheet_name}: #{e.message}")
    end

    def format_address_line1(row, column_map, is_vso)
      cell = is_vso ? row[column_map['Organization.AddressLine1']] : row[column_map['WorkAddress1']]
      cell.nil? ? nil : return_value_or_nil(cell.value.to_s)
    end

    def format_address_line2(row, column_map, is_vso)
      cell = is_vso ? row[column_map['Organization.AddressLine2']] : row[column_map['WorkAddress2']]
      cell.nil? ? nil : return_value_or_nil(cell.value.to_s)
    end

    def format_address_line3(row, column_map, is_vso)
      cell = is_vso ? row[column_map['Organization.AddressLine2']] : row[column_map['WorkAddress2']]
      cell.nil? ? nil : return_value_or_nil(cell.value.to_s)
    end

    def format_city(row, column_map, is_vso)
      cell = is_vso ? row[column_map['Organization.City']] : row[column_map['WorkCity']]
      cell.nil? ? nil : return_value_or_nil(cell.value.to_s)
    end

    def format_state_province_code(row, column_map, is_vso)
      cell = is_vso ? row[column_map['Organization.State']] : row[column_map['WorkState']]
      cell.nil? ? nil : return_value_or_nil(cell.value.to_s)
    end

    def format_zip_code(row, column_map, is_vso)
      cell = is_vso ? row[column_map['Organization.ZipCode']] : row[column_map['WorkZip']]

      return [nil, nil] if cell.nil?

      zip_code = cell.value.to_s
      is_zip_plus4 = zip_code.include?('-')
      zip5 = is_zip_plus4 ? format_zip5(zip_code.split('-').first) : format_zip5(zip_code)
      zip4 = is_zip_plus4 ? format_zip4(zip_code.split('-').last) : nil
      [zip5, zip4]
    end

    def format_zip5(zip5)
      zip5.length < 5 ? zip5.rjust(5, '0') : zip5
    end

    def format_zip4(zip4)
      zip4.length < 4 ? zip4.rjust(4, '0') : zip4
    end

    def format_email_address(row, sheet_name, column_map)
      column_name = email_address_column_name(sheet_name)
      email_address_cell = row[column_map[column_name]]
      email?(email_address_cell) ? rstrip_cell_value(email_address_cell.value) : nil
    end

    def email_address_column_name(sheet_name)
      sheet_name == 'Attorneys' ? 'EmailAddress' : 'WorkEmailAddress'
    end

    def email?(email_address_cell)
      return false if email_address_cell.nil?

      email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
      email_regex.match?(rstrip_cell_value(email_address_cell.value))
    end

    def rstrip_cell_value(value)
      value.to_s.rstrip
    end

    def format_vso_poa(vso_poa)
      vso_poa.to_s.rjust(3, '0')
    end

    def return_value_or_nil(value)
      value.blank? || value.empty? || value.downcase == 'null' ? nil : value
    rescue => e
      log_error("Unexpected value: #{e.message}")
    end

    # Logs an error to Sentry.
    # @param message [String] The error message to be logged.
    def log_error(message)
      log_message_to_sentry("QueueAddressUpdates error: #{message}", :error)
    end
  end
end
