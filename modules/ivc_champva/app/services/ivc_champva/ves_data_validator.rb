# frozen_string_literal: true

module IvcChampva
  class VesDataValidator

    # TODO: remove this class in favor of using the VesDataFormatter class

    CHILDTYPES = %w[ADOPTED STEPCHILD NATURAL].freeze
    RELATIONSHIPS = %w[SPOUSE EX_SPOUSE CAREGIVER CHILD].freeze
    GENDERS = %w[MALE FEMALE].freeze

    # This function will run through all the individual validators
    def self.validate(request_body)
      validate_application_type(request_body)
        .then { |rb| validate_application_uuid(rb) }
        .then { |rb| validate_sponsor(rb) }
        .then { |rb| validate_beneficiaries(rb) }
        .then { |rb| validate_certification(rb) }
    end

    def self.validate_sponsor(request_body)
      sponsor = request_body[:sponsor]
      validate_first_name(sponsor)
        .then { |s| validate_last_name(s) }
        .then { |s| validate_sponsor_address(s) }
        .then { |s| validate_date_of_birth(s) }
        .then { |s| validate_person_uuid(s) }
        .then { |s| validate_ssn(s) }
        .then { |s| validate_sponsor_phone(s) }

      request_body
    end

    def self.validate_beneficiaries(request_body)
      beneficiaries = request_body[:beneficiaries]
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
        .then { |b| validate_beneficiary_relationship(b) }
        .then { |b| validate_beneficiary_gender(b) }
        .then { |b| validate_ssn(b) }

      beneficiary
    end

    def self.validate_certification(request_body)
      certification = request_body[:certification]
      validate_certification_signature(certification)
        .then { |c| validate_certification_signature_date(c) }
        .then { |c| validate_certification_phone(c) }

      request_body
    end

    # ------------------------------------------------------------ #
    # ------------------------------------------------------------ #

    def self.validate_application_type(request_body)
      validate_presence_and_stringiness(request_body[:applicationType], 'application type')
      unless request_body[:applicationType] == 'CHAMPVA'
        raise ArgumentError, 'application type invalid. Must be CHAMPVA'
      end

      request_body
    end

    def self.validate_application_uuid(request_body)
      validate_presence_and_stringiness(request_body[:applicationUUID], 'application UUID')
      validate_uuid_length(request_body[:applicationUUID], 'application UUID')

      request_body
    end

    def self.validate_first_name(object)
      validate_presence_and_stringiness(object[:firstName], 'first name')
      object[:firstName] = transliterate_and_strip(object[:firstName])

      object
    end

    def self.validate_last_name(object)
      validate_presence_and_stringiness(object[:lastName], 'last name')
      object[:lastName] = transliterate_and_strip(object[:lastName])

      object
    end

    def self.transliterate_and_strip(text)
      # Convert any special UTF-8 chars to nearest ASCII equivalents, drop whitespace
      I18n.transliterate(text).gsub(%r{[^a-zA-Z\-\/\s]}, '').strip
    end

    def self.validate_person_uuid(object)
      validate_presence_and_stringiness(object[:personUUID], 'person uuid')
      validate_uuid_length(object[:personUUID], 'person uuid')

      object
    end

    def self.validate_date_of_birth(object)
      validate_date(object[:dateOfBirth], 'date of birth')

      object
    end

    def self.validate_beneficiary_gender(beneficiary)
      title = 'beneficiary gender'
      validate_nonempty_presence_and_stringiness(beneficiary[:gender], title)
      unless VesDataValidator::GENDERS.include?(beneficiary[:gender])
        raise ArgumentError, "#{title} is invalid. Must be in #{VesDataValidator::GENDERS.join(', ')}"
      end

      beneficiary
    end

    def self.validate_beneficiary_address(beneficiary)
      validate_address(beneficiary[:address], 'beneficiary')

      beneficiary
    end

    def self.validate_beneficiary_relationship(beneficiary)
      title = 'beneficiary relationship to sponsor'
      validate_presence_and_stringiness(beneficiary[:relationshipToSponsor], title)
      unless VesDataValidator::RELATIONSHIPS.include?(beneficiary[:relationshipToSponsor])
        raise ArgumentError, "#{title} is invalid. Must be in #{VesDataValidator::RELATIONSHIPS.join(', ')}"
      end

      validate_beneficiary_childtype(beneficiary) if beneficiary[:relationshipToSponsor] == 'CHILD'

      beneficiary
    end

    def self.validate_beneficiary_childtype(beneficiary)
      title = 'beneficiary childtype'
      validate_nonempty_presence_and_stringiness(beneficiary[:childtype], title)
      unless VesDataValidator::CHILDTYPES.include?(beneficiary[:childtype])
        raise ArgumentError, "#{title} is invalid. Must be in #{VesDataValidator::CHILDTYPES.join(', ')}"
      end

      beneficiary
    end

    def self.validate_beneficiary_phone(beneficiary)
      validate_phone(beneficiary, 'beneficiary phone')
    end

    def self.validate_sponsor_phone(sponsor)
      validate_phone(sponsor, 'sponsor phone') if sponsor[:phoneNumber]

      sponsor
    end

    def self.validate_sponsor_address(request_body)
      validate_address(request_body[:address], 'sponsor')

      request_body
    end

    def self.validate_certification_signature_date(certification)
      validate_date(certification[:signatureDate], 'certification signature date')
      certification
    end

    def self.validate_certification_signature(certification)
      validate_presence_and_stringiness(certification[:signature], 'certification signature')
      certification
    end

    def self.validate_certification_phone(certification)
      validate_phone(certification, 'certification phone') if certification[:phoneNumber]

      certification
    end

    def self.validate_address(address, name)
      validate_nonempty_presence_and_stringiness(address[:city], "#{name} city")
      validate_nonempty_presence_and_stringiness(address[:state], "#{name} state")
      validate_nonempty_presence_and_stringiness(address[:zipCode], "#{name} zip code")
      validate_nonempty_presence_and_stringiness(address[:streetAddress], "#{name} street address")
    end

    def self.validate_ssn(request_body)
      # TODO: strip out hyphens here? Or do that further up the chain?
      validate_presence_and_stringiness(request_body[:ssn], 'ssn')
      unless request_body[:ssn].match?(/^(?!(000|666|9))\d{3}(?!00)\d{2}(?!0000)\d{4}$/)
        raise ArgumentError, 'ssn is invalid. Must be 9 digits (see regex for more detail)'
      end

      request_body
    end

    def self.validate_phone(request_body, name)
      validate_presence_and_stringiness(request_body[:phoneNumber], 'ssn')
      unless request_body[:phoneNumber].match?(/^(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}$/)
        raise ArgumentError, "#{name} is invalid. See regex for more detail"
      end

      request_body
    end

    def self.validate_date(date, name)
      validate_presence_and_stringiness(date, name)
      raise ArgumentError, "#{name} is invalid. Must match YYYY-MM-DD" unless date.match?(/^\d{4}-\d{2}-\d{2}$/)

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

    def self.validate_nonempty_presence_and_stringiness(value, error_label)
      validate_presence_and_stringiness(value, error_label)
      raise ArgumentError, "#{error_label} is an empty string" if value.length.zero?
    end
  end
end
