# frozen_string_literal: true

module RepresentationManagement
  # Unified XLSX file processor for all accreditation entity types.
  # Parses the GCLAWS SSRS XLSX file for Agents, Attorneys, Representatives, and VSOs.
  # Returns parsed data keyed by entity type for downstream update jobs.
  class XlsxFileProcessor
    US_STATES_TERRITORIES = {
      'AL' => true, 'AK' => true, 'AZ' => true, 'AR' => true, 'CA' => true,
      'CO' => true, 'CT' => true, 'DE' => true, 'FL' => true, 'GA' => true,
      'HI' => true, 'ID' => true, 'IL' => true, 'IN' => true, 'IA' => true,
      'KS' => true, 'KY' => true, 'LA' => true, 'ME' => true, 'MD' => true,
      'MA' => true, 'MI' => true, 'MN' => true, 'MS' => true, 'MO' => true,
      'MT' => true, 'NE' => true, 'NV' => true, 'NH' => true, 'NJ' => true,
      'NM' => true, 'NY' => true, 'NC' => true, 'ND' => true, 'OH' => true,
      'OK' => true, 'OR' => true, 'PA' => true, 'RI' => true, 'SC' => true,
      'SD' => true, 'TN' => true, 'TX' => true, 'UT' => true, 'VT' => true,
      'VA' => true, 'WA' => true, 'WV' => true, 'WI' => true, 'WY' => true,
      'AS' => true, 'DC' => true, 'GU' => true, 'MP' => true, 'PR' => true,
      'VI' => true
    }.freeze

    # Maps entity types to their sheet names in the XLSX file
    TYPE_TO_SHEET = {
      'attorney' => 'Attorneys',
      'claims_agent' => 'Agents',
      'representative' => 'Representatives',
      'organization' => 'VSOs'
    }.freeze

    # Individual entity types (not organizations)
    INDIVIDUAL_TYPES = %w[attorney claims_agent representative].freeze

    # Column name for state in individual sheets
    INDIVIDUAL_STATE_COLUMN = 'WorkState'

    # Column name for state in organization sheet
    ORG_STATE_COLUMN = 'OrganizationState'

    # @param file_content [String] Binary content of the XLSX file
    # @param types [Array<String>] Entity types to process (defaults to all)
    def initialize(file_content, types = nil)
      @file_content = file_content
      @types = types || TYPE_TO_SHEET.keys
    end

    # Processes the XLSX file and returns parsed data keyed by entity type
    # @return [Hash] { 'attorney' => [...], 'organization' => [...], ... }
    def process
      data = {}

      open_spreadsheet do |xlsx|
        @types.each do |type|
          sheet_name = TYPE_TO_SHEET[type]
          next unless sheet_name

          begin
            sheet = xlsx.sheet(sheet_name)
            data[type] = process_sheet(xlsx, sheet_name, type) if sheet
          rescue RangeError
            log_error("Sheet '#{sheet_name}' not found in XLSX file")
          end
        end
      end

      data
    rescue => e
      log_error("Error processing XLSX file: #{e.message}")
      {}
    end

    private

    def open_spreadsheet
      xlsx = Roo::Spreadsheet.open(StringIO.new(@file_content), extension: :xlsx)
      yield(xlsx)
    rescue Roo::Error => e
      log_error("Error opening spreadsheet: #{e.message}")
    end

    def process_sheet(xlsx, sheet_name, type)
      sheet = xlsx.sheet(sheet_name)
      header_row = sheet.row(1)
      column_map = build_column_index_map(header_row)

      if INDIVIDUAL_TYPES.include?(type)
        process_individual_sheet(sheet, column_map, type, sheet_name)
      else
        process_organization_sheet(sheet, column_map)
      end
    rescue => e
      log_error("Error processing sheet '#{sheet_name}': #{e.message}")
      []
    end

    def process_individual_sheet(sheet, column_map, type, sheet_name)
      processed_ids = {}
      data = []

      sheet.each_with_index do |row, index|
        next if index.zero? || row.length < column_map.length

        registration_number = normalize_numeric(row[column_map['Number']])
        next if registration_number.blank?
        next if processed_ids[registration_number]

        state_code = get_value(row, column_map, INDIVIDUAL_STATE_COLUMN)
        next unless US_STATES_TERRITORIES[state_code]

        data << build_individual_hash(row, column_map, type, sheet_name)
        processed_ids[registration_number] = true
      end

      data
    end

    def process_organization_sheet(sheet, column_map)
      processed_poa_codes = {}
      data = []

      sheet.each_with_index do |row, index|
        next if index.zero?

        row = row.map { |cell| cell.is_a?(Numeric) ? cell.to_i.to_s : cell }

        poa_code = row[column_map['POA']]&.to_s&.strip
        next if poa_code.blank?
        next if processed_poa_codes[poa_code]

        state_code = get_value(row, column_map, ORG_STATE_COLUMN)
        next unless US_STATES_TERRITORIES[state_code]

        data << build_organization_hash(row, column_map)
        processed_poa_codes[poa_code] = true
      end

      data
    end

    def build_individual_hash(row, column_map, type, sheet_name)
      address = build_individual_address(row, column_map)
      {
        registration_number: normalize_numeric(row[column_map['Number']]),
        individual_type: type,
        email: get_value(row, column_map, email_column_name(sheet_name)),
        phone_number: get_value(row, column_map, 'WorkNumber'),
        address: address,
        raw_address: build_raw_address(address)
      }
    end

    def build_organization_hash(row, column_map)
      address = build_organization_address(row, column_map)
      {
        poa_code: row[column_map['POA']]&.to_s&.strip,
        name: get_value(row, column_map, 'OrganizationName'),
        phone: get_value(row, column_map, 'OrganizationPhoneNumber'),
        address: address,
        raw_address: build_raw_address(address)
      }
    end

    def build_individual_address(row, column_map)
      zip_code5, zip_code4 = get_value(row, column_map, 'WorkZip')
      {
        address_pou: 'RESIDENCE',
        address_line1: get_value(row, column_map, 'WorkAddress1'),
        address_line2: get_value(row, column_map, 'WorkAddress2'),
        address_line3: get_value(row, column_map, 'WorkAddress3'),
        city: get_value(row, column_map, 'WorkCity'),
        state: { state_code: get_value(row, column_map, INDIVIDUAL_STATE_COLUMN) },
        zip_code5: zip_code5,
        zip_code4: zip_code4,
        country_code_iso3: 'US'
      }
    end

    def build_organization_address(row, column_map)
      zip_code5, zip_code4 = get_value(row, column_map, 'OrganizationZipCode')
      {
        address_pou: 'CORRESPONDENCE',
        address_line1: get_value(row, column_map, 'OrganizationAddressLine1'),
        address_line2: get_value(row, column_map, 'OrganizationAddressLine2'),
        address_line3: get_value(row, column_map, 'OrganizationAddressLine3'),
        city: get_value(row, column_map, 'OrganizationCity'),
        state: { state_code: get_value(row, column_map, ORG_STATE_COLUMN) },
        zip_code5: zip_code5,
        zip_code4: zip_code4,
        country_code_iso3: 'US'
      }
    end

    # Builds raw_address hash with string keys matching AccreditedIndividual/AccreditedOrganization pattern
    # @param address [Hash] Address hash with symbol keys from build_*_address methods
    # @return [Hash] Raw address with string keys for JSONB storage
    def build_raw_address(address)
      zip_code = format_raw_zip(address[:zip_code5], address[:zip_code4])

      {
        'address_line1' => address[:address_line1],
        'address_line2' => address[:address_line2],
        'address_line3' => address[:address_line3],
        'city' => address[:city],
        'state_code' => address.dig(:state, :state_code),
        'zip_code' => zip_code
      }
    end

    def format_raw_zip(zip5, zip4)
      return nil if zip5.blank?

      zip4.present? ? "#{zip5}-#{zip4}" : zip5
    end

    def build_column_index_map(header_row)
      header_row.each_with_index.with_object({}) do |(cell, index), map|
        map[cell] = index
      end
    end

    def get_value(row, column_map, column_name)
      value = row[column_map[column_name]]
      zip_columns = %w[WorkZip OrganizationZipCode]
      return [nil, nil] if value.nil? && zip_columns.include?(column_name)
      return nil if value.nil?

      sanitized_value = value.to_s.strip

      case column_name
      when *zip_columns
        get_zip_code(sanitized_value)
      when 'EmailAddress', 'WorkEmailAddress'
        get_email_address(sanitized_value)
      else
        get_value_or_nil(sanitized_value)
      end
    end

    # Normalizes numeric values from Roo (which returns Excel integers as floats like 8859.0)
    # @param value [Object] Value from Roo cell
    # @return [String, nil] Normalized string representation
    def normalize_numeric(value)
      return nil if value.nil?

      value.is_a?(Numeric) ? value.to_i.to_s : value.to_s.strip
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

    def email_column_name(sheet_name)
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
      Rails.logger.error("RepresentationManagement::XlsxFileProcessor error: #{message}")
    end
  end
end
