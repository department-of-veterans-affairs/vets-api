# frozen_string_literal: true

module Representatives
  class XlsxFileProcessor
    include SentryLogging

    SHEETS_TO_PROCESS = %w[Agents Attorneys Representatives].freeze

    def initialize(file_content)
      @file_content = file_content
    end

    def process
      data = {}

      open_spreadsheet do |xlsx|
        SHEETS_TO_PROCESS.each do |sheet_name|
          data[sheet_name] = process_sheet(xlsx, sheet_name) if xlsx.sheet(sheet_name)
        end
      end

      data
    rescue => e
      log_error("Error processing XLSX file: #{e.message}")
    end

    private

    def open_spreadsheet
      xlsx = Roo::Spreadsheet.open(StringIO.new(@file_content), extension: :xlsx)
      yield(xlsx)
    rescue Roo::Error => e
      log_error("Error opening spreadsheet: #{e.message}")
    end

    def process_sheet(xlsx, sheet_name)
      data = []
      column_map = build_column_index_map(xlsx.sheet(sheet_name).row(1))

      xlsx.sheet(sheet_name).each_with_index do |row, index|
        next if index.zero? || row.length < column_map.length

        data << create_json_data(row, sheet_name, column_map)
      end

      data
    rescue => e
      log_error("Error processing sheet '#{sheet_name}': #{e.message}")
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
      zip_code5, zip_code4 = get_value(row, column_map, 'WorkZip')

      {
        id: row[column_map['Number']],
        email_address: get_value(row, column_map, email_address_column_name(sheet_name)),
        phone_number: get_value(row, column_map, 'WorkNumber'),
        request_address: {
          address_pou: 'RESIDENCE/CHOICE',
          address_line1: get_value(row, column_map, 'WorkAddress1'),
          address_line2: get_value(row, column_map, 'WorkAddress2'),
          address_line3: get_value(row, column_map, 'WorkAddress3'),
          city: get_value(row, column_map, 'WorkCity'),
          state_province: { code: get_value(row, column_map, 'WorkState') },
          zip_code5:,
          zip_code4:,
          country_code_iso3: 'US'
        }
      }.to_json
    rescue => e
      log_error("Error transforming data to JSON for #{sheet_name}: #{e.message}")
    end

    def get_value(row, column_map, column_name)
      value = row[column_map[column_name]]
      return [nil, nil] if value.nil? && column_name == 'WorkZip'
      return nil if value.nil?

      sanitized_value = value.to_s.strip

      case column_name
      when 'WorkZip'
        get_zip_code(sanitized_value)
      when 'EmailAddress', 'WorkEmailAddress'
        get_email_address(sanitized_value)
      else
        get_value_or_nil(sanitized_value)
      end
    end

    def get_zip_code(value)
      is_zip_plus4 = value.include?('-')
      zip5 = is_zip_plus4 ? format_zip5(value.split('-').first) : format_zip5(value)
      zip4 = is_zip_plus4 ? format_zip4(value.split('-').last) : nil
      [zip5, zip4]
    end

    def format_zip5(zip5)
      zip5.length < 5 ? zip5.rjust(5, '0') : zip5
    end

    def format_zip4(zip4)
      zip4.length < 4 ? zip4.rjust(4, '0') : zip4
    end

    def email_address_column_name(sheet_name)
      sheet_name == 'Attorneys' ? 'EmailAddress' : 'WorkEmailAddress'
    end

    def get_email_address(value)
      email_address?(value) ? value : nil
    end

    def email_address?(email_address)
      email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
      email_regex.match?(email_address)
    end

    def get_value_or_nil(value)
      value.blank? || value.empty? || value.downcase == 'null' ? nil : value
    rescue => e
      log_error("Unexpected value: #{e.message}")
    end

    def log_error(message)
      log_message_to_sentry("XlsxFileProcessor error: #{message}", :error)
    end
  end
end
