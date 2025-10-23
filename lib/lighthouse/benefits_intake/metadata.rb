# frozen_string_literal: true

module BenefitsIntake
  # Validate the required metadata which must accompany an upload:
  #
  # {
  #   'veteranFirstName': String,
  #   'veteranLastName': String,
  #   'fileNumber': String, # 8-9 digits
  #   'zipCode': String, # 5 or 9 digits
  #   'source': String,
  #   'docType': String,
  #   'businessLine': String, # optional; enum in BUSINESS_LINE
  # }
  class Metadata
    # collection of expected businessLine values
    BUSINESS_LINE = {
      CMP: 'Compensation requests such as those related to disability, unemployment, and pandemic claims',
      PMC: 'Pension requests including survivor’s pension',
      INS: 'Insurance such as life insurance, disability insurance, and other health insurance',
      EDU: 'Education benefits, programs, and affiliations',
      VRE: 'Veteran Readiness & Employment such as employment questionnaires, ' \
           'employment discrimination, employment verification',
      BVA: 'Board of Veteran Appeals',
      FID: 'Fiduciary / financial appointee, including family member benefits',
      NCA: 'National Cemetery Administration',
      OTH: 'Other (this value if used, will be treated as CMP)'
    }.freeze

    # create a valid metadata structure
    #
    # @return [Hash] valid metadata
    # rubocop:disable Metrics/ParameterLists
    def self.generate(first_name, last_name, file_number, zip_code, source, doc_type, business_line = nil)
      validate({
                 'veteranFirstName' => first_name,
                 'veteranLastName' => last_name,
                 'fileNumber' => file_number,
                 'zipCode' => zip_code,
                 'source' => source,
                 'docType' => doc_type,
                 'businessLine' => business_line
               })
    end
    # rubocop:enable Metrics/ParameterLists

    # conform and validate each provided argument
    def self.validate(metadata)
      validate_first_name(metadata)
        .then { |m| validate_last_name(m) }
        .then { |m| validate_file_number(m) }
        .then { |m| validate_zip_code(m) }
        .then { |m| validate_source(m) }
        .then { |m| validate_doc_type(m) }
        .then { |m| validate_business_line(m) }
    end

    # conform and validate the first_name
    # removes any non alphanumeric character and truncates to 50 characters
    def self.validate_first_name(metadata)
      validate_presence_and_stringiness(metadata['veteranFirstName'], 'veteran first name')

      first_name = I18n.transliterate(metadata['veteranFirstName']).gsub(%r{[^a-zA-Z\-/\s]}, '').strip.first(50)
      validate_nonblank(first_name, 'veteran first name')

      metadata['veteranFirstName'] = first_name
      metadata
    end

    # conform and validate the last_name
    # removes any non alphanumeric character and truncates to 50 characters
    def self.validate_last_name(metadata)
      validate_presence_and_stringiness(metadata['veteranLastName'], 'veteran last name')

      last_name = I18n.transliterate(metadata['veteranLastName']).gsub(%r{[^a-zA-Z\-/\s]}, '').strip.first(50)
      validate_nonblank(last_name, 'veteran last name')

      metadata['veteranLastName'] = last_name
      metadata
    end

    # conform and validate the file_number
    # 8 or 9 digit sequence
    def self.validate_file_number(metadata)
      validate_presence_and_stringiness(metadata['fileNumber'], 'file number')
      unless metadata['fileNumber'].match?(/^\d{8,9}$/)
        raise ArgumentError, 'file number is invalid. It must be 8 or 9 digits'
      end

      metadata
    end

    # conform and validate the zip_code
    # removes non digit characters and checks length is 5 or 9 (with dash)
    # sets to '00000' if invalid
    def self.validate_zip_code(metadata)
      validate_presence_and_stringiness(metadata['zipCode'], 'zip code')

      zip_code = metadata['zipCode'].dup.gsub(/[^0-9]/, '')
      zip_code.insert(5, '-') if zip_code.match?(/\A[0-9]{9}\z/)
      zip_code = '00000' unless zip_code.match?(/\A[0-9]{5}(-[0-9]{4})?\z/)

      metadata['zipCode'] = zip_code

      metadata
    end

    # conform and validate the source
    def self.validate_source(metadata)
      validate_presence_and_stringiness(metadata['source'], 'source')

      metadata
    end

    # conform and validate the doc_type
    def self.validate_doc_type(metadata)
      validate_presence_and_stringiness(metadata['docType'], 'doc type')

      metadata
    end

    # conform and validate the business_line
    def self.validate_business_line(metadata)
      bl = metadata['businessLine']
      if bl
        bl = bl.dup.to_s.upcase.to_sym
        bl = :OTH unless BUSINESS_LINE.key?(bl)
        metadata['businessLine'] = bl.to_s
      else
        metadata.delete('businessLine')
      end

      metadata
    end

    # ensure presence and the value is a String
    def self.validate_presence_and_stringiness(value, error_label)
      raise ArgumentError, "#{error_label} is missing" unless value
      raise ArgumentError, "#{error_label} is not a string" if value.class != String
    end

    # ensure the value is not an empty String
    def self.validate_nonblank(value, error_label)
      raise ArgumentError, "#{error_label} is blank" if value.blank?
    end
  end
end
