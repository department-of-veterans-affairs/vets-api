# frozen_string_literal: true

module IvcChampva
  class VesDataValidator
    # This function will run through all the individual validators
    def self.validate(request_body)
      validate_application_type(request_body)
        .then { |rb| validate_application_uuid(rb) }
        .then { |rb| validate_doc_type(rb) }
        .then { |rb| validate_sponsor(rb) }
        .then { |rb| validate_beneficiaries(rb) }
        .then { |rb| validate_certification(rb) }
    end

    def self.validate_sponsor(request_body)
      sponsor = request_body['sponsor']
      validate_first_name(sponsor)
        .then { |s| validate_last_name(s) }
        .then { |s| validate_sponsor_address(s) }
        .then { |s| validate_date_of_birth(s) }
        .then { |s| validate_person_uuid(s) }
        .then { |s| validate_ssn(s) }

      request_body
    end

    def self.validate_beneficiaries(request_body)
      beneficiaries = request_body['beneficiaries']
      raise ArgumentError, 'beneficiaries is invalid. Must be an array' unless beneficiaries.is_a?(Array)

      beneficiaries.each do |beneficiary|
        validate_beneficiary(beneficiary)
      end

      request_body
    end

    def self.validate_beneficiary(beneficiary)
      validate_first_name(beneficiary)
        .then { |b| validate_last_name(b) }
        .then { |b| validate_date_of_birth(b) }
        .then { |b| validate_person_uuid(b) }
        .then { |b| validate_beneficiary_address(b) }
        .then { |b| validate_ssn(b) }

      beneficiary
    end

    def self.validate_certification(request_body)
      certification = request_body['certifiation']

      validate_presence_and_stringiness(certification['signature'], 'certification signature')
      validate_date(certification['signatureDate'], 'certification signature date')

      request_body
    end

    # ------------------------------------------------------------ #
    # ------------------------------------------------------------ #

    def self.validate_application_type(request_body)
      validate_presence_and_stringiness(request_body['applicationType'], 'application type')

      request_body
    end

    def self.validate_application_uuid(request_body)
      validate_presence_and_stringiness(request_body['applicationUuid'], 'application UUID')
      validate_uuid_length(request_body['applicationUuid'], 'application UUID')

      request_body
    end

    def self.validate_first_name(object)
      validate_presence_and_stringiness(object['firstName'], 'first name')
      object['firstName'] = transliterate_and_strip(object['firstName'])

      object
    end

    def self.validate_last_name(object)
      validate_presence_and_stringiness(object['lastName'], 'last name')
      object['lastName'] = transliterate_and_strip(object['lastName'])

      object
    end

    def self.transliterate_and_strip(text)
      # Convert any special UTF-8 chars to nearest ASCII equivalents, drop whitespace
      I18n.transliterate(text).gsub(%r{[^a-zA-Z\-\/\s]}, '').strip
    end

    def self.validate_person_uuid(object)
      validate_presence_and_stringiness(object['personUuid'], 'person uuid')
      validate_uuid_length(object['personUuid'], 'person uuid')

      object
    end

    def self.validate_date_of_birth(object)
      validate_date(object['dateOfBirth'], 'date of birth')

      object
    end

    def self.validate_beneficiary_address(beneficiary)
      validate_address(beneficiary['address'], 'beneficiary')

      beneficiary
    end

    def self.validate_sponsor_address(request_body)
      validate_address(request_body['address'], 'sponsor')

      request_body
    end

    def self.validate_address(address, name)
      validate_presence_and_stringiness(address['city'], "#{name} city")
      validate_presence_and_stringiness(address['state'], "#{name} state")
      validate_presence_and_stringiness(address['zipCode'], "#{name} zip code")
      validate_presence_and_stringiness(address['streetAddress'], "#{name} street address")
    end

    def self.validate_ssn(request_body)
      validate_presence_and_stringiness(request_body['ssn'], 'ssn')
      unless request_body['ssn'].match?(/^(?!(000|666|9))\d{3}(?!00)\d{2}(?!0000)\d{4}$/)
        raise ArgumentError, 'ssn is invalid. must be 9 digits (see regex for more detail)'
      end

      request_body
    end

    def self.validate_date(date, name)
      validate_presence_and_stringiness(date, name)
      # TODO: once we know the exact date format VES is expecting we can
      # do further checks here.
      date
    end

    def self.validate_uuid_length(uuid, name)
      # TODO: we may want a more sophisticated validation for uuids
      raise ArgumentError, "#{name} is invalid. Must be 36 characters" unless uuid.length == 36
    end

    def self.validate_presence_and_stringiness(value, error_label)
      raise ArgumentError, "#{error_label} is missing" unless value
      raise ArgumentError, "#{error_label} is not a string" if value.class != String
    end
  end
end
