# frozen_string_literal: true

module Representatives
  class XlsxFileProcessor
    include SentryLogging

    US_STATES_TERRITORIES = {
      'AL' => true,
      'AK' => true,
      'AZ' => true,
      'AR' => true,
      'CA' => true,
      'CO' => true,
      'CT' => true,
      'DE' => true,
      'FL' => true,
      'GA' => true,
      'HI' => true,
      'ID' => true,
      'IL' => true,
      'IN' => true,
      'IA' => true,
      'KS' => true,
      'KY' => true,
      'LA' => true,
      'ME' => true,
      'MD' => true,
      'MA' => true,
      'MI' => true,
      'MN' => true,
      'MS' => true,
      'MO' => true,
      'MT' => true,
      'NE' => true,
      'NV' => true,
      'NH' => true,
      'NJ' => true,
      'NM' => true,
      'NY' => true,
      'NC' => true,
      'ND' => true,
      'OH' => true,
      'OK' => true,
      'OR' => true,
      'PA' => true,
      'RI' => true,
      'SC' => true,
      'SD' => true,
      'TN' => true,
      'TX' => true,
      'UT' => true,
      'VT' => true,
      'VA' => true,
      'WA' => true,
      'WV' => true,
      'WI' => true,
      'WY' => true,
      'AS' => true, # American Samoa
      'DC' => true, # District of Columbia
      'GU' => true, # Guam
      'MP' => true, # Northern Mariana Islands
      'PR' => true, # Puerto Rico
      'VI' => true  # U.S. Virgin Islands
    }.freeze

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

        state_code = get_value(row, column_map, 'WorkState')

        next unless US_STATES_TERRITORIES[state_code]

        data << process_row(row, sheet_name, column_map)
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

    # Creates a hash for a given row based on the sheet name and column map.
    # @param row [Array] The row data to be transformed into a hash.
    # @param sheet_name [String] The name of the sheet being processed.
    # @param column_map [Hash] The column index map for the sheet.
    # @return [String] The hash representation of the row data.
    def process_row(row, sheet_name, column_map)
      zip_code5, zip_code4 = get_value(row, column_map, 'WorkZip')

      {
        id: row[column_map['Number']],
        email: get_value(row, column_map, email_address_column_name(sheet_name)),
        phone_number: get_value(row, column_map, 'WorkNumber'),
        address: {
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
      }
    rescue => e
      log_error("Error transforming data to hash for #{sheet_name}: #{e.message}")
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
