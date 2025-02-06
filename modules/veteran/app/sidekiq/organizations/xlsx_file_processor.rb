# frozen_string_literal: true

module Organizations
  class XlsxFileProcessor
    US_STATES_TERRITORIES = [
      'AL',
      'AK',
      'AZ',
      'AR',
      'CA',
      'CO',
      'CT',
      'DE',
      'FL',
      'GA',
      'HI',
      'ID',
      'IL',
      'IN',
      'IA',
      'KS',
      'KY',
      'LA',
      'ME',
      'MD',
      'MA',
      'MI',
      'MN',
      'MS',
      'MO',
      'MT',
      'NE',
      'NV',
      'NH',
      'NJ',
      'NM',
      'NY',
      'NC',
      'ND',
      'OH',
      'OK',
      'OR',
      'PA',
      'RI',
      'SC',
      'SD',
      'TN',
      'TX',
      'UT',
      'VT',
      'VA',
      'WA',
      'WV',
      'WI',
      'WY',
      'AS', # American Samoa
      'DC', # District of Columbia
      'GU', # Guam
      'MP', # Northern Mariana Islands
      'PR', # Puerto Rico
      'VI'  # U.S. Virgin Islands
    ].freeze

    SHEETS_TO_PROCESS = %w[VSOs].freeze

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

        state_code = get_value(row, column_map, 'OrganizationState')

        next unless US_STATES_TERRITORIES.include?(state_code)

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
      row = row.map { |cell| cell.is_a?(Numeric) ? cell.to_i.to_s : cell }
      zip_code5, zip_code4 = get_value(row, column_map, 'OrganizationZipCode')

      {
        id: row[column_map['POA']],
        phone_number: get_value(row, column_map, 'OrganizationPhoneNumber'),
        address: {
          address_pou: 'CORRESPONDENCE',
          address_line1: get_value(row, column_map, 'OrganizationAddressLine1'),
          address_line2: get_value(row, column_map, 'OrganizationAddressLine2'),
          address_line3: get_value(row, column_map, 'OrganizationAddressLine3'),
          city: get_value(row, column_map, 'OrganizationCity'),
          state: { state_code: get_value(row, column_map, 'OrganizationState') },
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
      return [nil, nil] if value.nil? && column_name == 'OrganizationZipCode'
      return nil if value.nil?

      sanitized_value = value.to_s.strip

      case column_name
      when 'OrganizationZipCode'
        get_zip_code(sanitized_value)
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

    def get_value_or_nil(value)
      value.blank? || value.empty? || value.downcase == 'null' ? nil : value
    rescue => e
      log_error("Unexpected value: #{e.message}")
    end

    def log_error(message)
      Rails.logger.error("XlsxFileProcessor error: #{message}")
    end
  end
end
