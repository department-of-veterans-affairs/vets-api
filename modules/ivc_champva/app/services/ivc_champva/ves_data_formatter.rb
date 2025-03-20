# frozen_string_literal: true

module IvcChampva
  class VesDataFormatter
    CHILDTYPES = %w[ADOPTED STEPCHILD NATURAL].freeze
    RELATIONSHIPS = %w[SPOUSE EX_SPOUSE CAREGIVER CHILD].freeze
    GENDERS = %w[MALE FEMALE].freeze
    VALID_RELATIONSHIPS_LOOKUP = RELATIONSHIPS.index_by(&:downcase).freeze
    VALID_GENDER_LOOKUP = { 'm' => 'MALE', 'male' => 'MALE', 'f' => 'FEMALE', 'female' => 'FEMALE' }.freeze
    DEFAULT_ADDRESS = { streetAddress: 'NA', city: 'NA', state: 'NA', zipCode: 'NA' }.freeze

    # Transform parsed form data from frontend format to VES format & validate
    def self.format(parsed_form_data)
      ves_data = transform_to_ves_format(parsed_form_data)
      validate_ves_data(ves_data)

      IvcChampva::VesRequest.new(
        application_type: ves_data[:applicationType],
        application_uuid: ves_data[:applicationUUID],
        sponsor: ves_data[:sponsor],
        beneficiaries: ves_data[:beneficiaries],
        certification: ves_data[:certification]
      )
    end

    def self.transform_to_ves_format(parsed_form_data)
      {
        applicationType: 'CHAMPVA',
        applicationUUID: SecureRandom.uuid,
        sponsor: map_sponsor(parsed_form_data['veteran']),
        beneficiaries: parsed_form_data['applicants'].map { |applicant| map_beneficiary(applicant) },
        certification: map_certification(
          parsed_form_data['certification'],
          parsed_form_data['statement_of_truth_signature']
        )
      }
    end

    def self.validate_ves_data(data)
      validate_application_type(data)
        .then { |rb| validate_application_uuid(rb) }
        .then { |rb| validate_sponsor(rb) }
        .then { |rb| validate_beneficiaries(rb) }
        .then { |rb| validate_certification(rb) }
    end

    def self.map_sponsor(veteran_data)
      {
        personUUID: SecureRandom.uuid,
        firstName: transliterate_and_strip(veteran_data.dig('full_name', 'first')),
        lastName: transliterate_and_strip(veteran_data.dig('full_name', 'last')),
        middleInitial: veteran_data.dig('full_name', 'middle'),
        ssn: veteran_data['ssn_or_tin'],
        vaFileNumber: veteran_data['va_claim_number'] || '',
        dateOfBirth: veteran_data['date_of_birth'],
        dateOfMarriage: veteran_data['date_of_marriage'] || '',
        isDeceased: veteran_data['sponsor_is_deceased'],
        dateOfDeath: veteran_data['date_of_death'],
        isDeathOnActiveService: veteran_data['is_active_service_death'] || false,
        phoneNumber: format_phone_number(veteran_data['phone_number']),
        address: map_address(veteran_data['address'])
      }
    end

    def self.map_beneficiary(data)
      {
        personUUID: SecureRandom.uuid,
        firstName: transliterate_and_strip(data.dig('applicant_name', 'first')),
        middleInitial: data.dig('applicant_name', 'middle'),
        lastName: transliterate_and_strip(data.dig('applicant_name', 'last')),
        suffix: data.dig('applicant_name', 'suffix'),
        ssn: data['ssn_or_tin'] || data.dig('applicant_ssn', 'ssn'),
        dateOfBirth: data['applicant_dob'],
        gender: normalize_gender(data.dig('applicant_gender', 'gender')),
        emailAddress: data['applicant_email_address'],
        phoneNumber: format_phone_number(data['applicant_phone']),
        address: map_address(data['applicant_address']),
        relationshipToSponsor: convert_relationship(data['vet_relationship']),
        childtype: normalize_childtype(data.dig('childtype', 'relationship_to_veteran') ||
          data.dig('applicant_relationship_origin', 'relationship_to_veteran')),
        enrolledInMedicare: data.dig('applicant_medicare_status', 'eligibility') == 'enrolled' ||
          data['is_enrolled_in_medicare'],
        enrolledInPartD: data.dig('applicant_medicare_part_d', 'enrollment') == 'enrolled',
        hasOtherInsurance: data.dig('applicant_has_ohi', 'has_ohi') == 'yes' || data['has_other_health_insurance']
      }
    end

    def self.map_certification(certification_data, signature)
      return {} unless certification_data

      {
        signature:,
        signatureDate: certification_data['date'],
        firstName: transliterate_and_strip(certification_data['first_name']),
        lastName: transliterate_and_strip(certification_data['last_name']),
        middleInitial: certification_data['middle_initial'],
        phoneNumber: format_phone_number(certification_data['phone_number']),
        relationship: certification_data['relationship']
      }
    end

    def self.map_address(address_data)
      return DEFAULT_ADDRESS unless address_data.is_a?(Hash)

      {
        streetAddress: address_data['street_combined'] || address_data['street'] || 'NA',
        city: address_data['city'] || 'NA',
        state: address_data['state'] || 'NA',
        zipCode: address_data['postal_code'] || 'NA'
      }
    end

    # Data formatting methods
    def self.format_phone_number(phone)
      return nil if phone.blank?

      # regex from VES swagger
      return phone if phone.match?(/^(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}$/)

      # TODO: add country code check/formatting
      digits = phone.to_s.gsub(/\D/, '')
      return phone unless digits.length == 10

      "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}"
    end

    def self.format_ssn(ssn)
      return nil if ssn.blank?

      digits = ssn.to_s.gsub(/\D/, '')
      return ssn unless digits.length == 9

      # regex from VES swagger
      return nil unless digits.match?(/^(?!(000|666|9))\d{3}(?!00)\d{2}(?!0000)\d{4}$/)

      digits
    end

    def format_date(date_string)
      return nil if date_string.blank?

      return date_string if date_string.match?(/^\d{4}-\d{2}-\d{2}$/)

      begin
        # parsed_form_data should be correct already
        # TODO: add checks for other delimiters
        Date.parse(date_string, '%d-%m-%Y').strftime('%Y-%m-%d')
      rescue
        date_string
      end
    end

    def self.normalize_gender(gender)
      return nil if gender.blank?

      key = gender.to_s.downcase
      VALID_GENDER_LOOKUP[key] || gender.to_s.upcase
    end

    def self.convert_relationship(relationship)
      return nil if relationship.blank?

      key = relationship.to_s.downcase
      return VALID_RELATIONSHIPS_LOOKUP[key] if VALID_RELATIONSHIPS_LOOKUP[key]

      # Try to find a partial match
      RELATIONSHIPS.each do |r|
        return r if key.match?(r.downcase)
      end

      raise ArgumentError, "Relationship #{relationship} is invalid. Must be in #{RELATIONSHIPS.join(', ')}"
    end

    def self.normalize_childtype(childtype)
      return nil if childtype.blank?

      case childtype.to_s.downcase
      when 'blood'
        'NATURAL'
      else
        childtype.to_s.upcase
      end
    end

    def self.transliterate_and_strip(text)
      return nil if text.blank?

      I18n.transliterate(text).gsub(%r{[^a-zA-Z\-\/\s]}, '').strip
    end

    # Validation methods - consolidated
    def self.validate_sponsor(request_body)
      sponsor = request_body[:sponsor]

      # Basic validation
      validate_name_fields(sponsor, 'sponsor')
      validate_address(sponsor[:address], 'sponsor')
      validate_date(sponsor[:dateOfBirth], 'date of birth')
      validate_uuid(sponsor[:personUUID], 'person uuid')
      validate_ssn(sponsor[:ssn], 'ssn')
      validate_phone(sponsor, 'sponsor phone') if sponsor[:phoneNumber]

      request_body
    end

    def self.validate_beneficiaries(request_body)
      beneficiaries = request_body[:beneficiaries]
      raise ArgumentError, 'beneficiaries is invalid. Must be an array' unless beneficiaries.is_a?(Array)

      beneficiaries.each do |beneficiary|
        # Basic validation
        validate_name_fields(beneficiary, 'beneficiary')
        validate_date(beneficiary[:dateOfBirth], 'date of birth')
        validate_uuid(beneficiary[:personUUID], 'person uuid')
        validate_address(beneficiary[:address], 'beneficiary')
        validate_relationship_fields(beneficiary)
        validate_gender(beneficiary)
        validate_ssn(beneficiary[:ssn], 'ssn')
      end

      request_body
    end

    def self.validate_certification(request_body)
      certification = request_body[:certification]
      return request_body if certification.blank? || certification.empty?

      validate_presence_and_stringiness(certification[:signature], 'certification signature')
      validate_date(certification[:signatureDate], 'certification signature date')
      validate_phone(certification, 'certification phone') if certification[:phoneNumber]

      request_body
    end

    def self.validate_application_type(request_body)
      validate_presence_and_stringiness(request_body[:applicationType], 'application type')
      unless request_body[:applicationType] == 'CHAMPVA'
        raise ArgumentError, 'application type invalid. Must be CHAMPVA'
      end

      request_body
    end

    def self.validate_application_uuid(request_body)
      validate_uuid(request_body[:applicationUUID], 'application UUID')
      request_body
    end

    def self.validate_name_fields(object, prefix)
      validate_presence_and_stringiness(object[:firstName], "#{prefix} first name")
      validate_presence_and_stringiness(object[:lastName], "#{prefix} last name")
      object
    end

    def self.validate_relationship_fields(beneficiary)
      # Validate relationship
      validate_presence_and_stringiness(beneficiary[:relationshipToSponsor], 'beneficiary relationship to sponsor')

      unless RELATIONSHIPS.include?(beneficiary[:relationshipToSponsor])
        raise ArgumentError, "beneficiary relationship to sponsor is invalid. Must be in #{RELATIONSHIPS.join(', ')}"
      end

      # Validate childtype if relationship is CHILD
      if beneficiary[:relationshipToSponsor] == 'CHILD'
        validate_nonempty_presence_and_stringiness(beneficiary[:childtype], 'beneficiary childtype')

        unless CHILDTYPES.include?(beneficiary[:childtype])
          raise ArgumentError, "beneficiary childtype is invalid. Must be in #{CHILDTYPES.join(', ')}"
        end
      end

      beneficiary
    end

    def self.validate_gender(beneficiary)
      validate_presence_and_stringiness(beneficiary[:gender], 'beneficiary gender')

      unless GENDERS.include?(beneficiary[:gender])
        raise ArgumentError, "beneficiary gender is invalid. Must be in #{GENDERS.join(', ')}"
      end

      beneficiary
    end

    def self.validate_address(address, name)
      validate_nonempty_presence_and_stringiness(address[:city], "#{name} city")
      validate_nonempty_presence_and_stringiness(address[:state], "#{name} state")
      validate_nonempty_presence_and_stringiness(address[:zipCode], "#{name} zip code")
      validate_nonempty_presence_and_stringiness(address[:streetAddress], "#{name} street address")
    end

    def self.validate_date(date, name)
      validate_presence_and_stringiness(date, name)
      raise ArgumentError, "#{name} is invalid. Must match YYYY-MM-DD" unless date.match?(/^\d{4}-\d{2}-\d{2}$/)

      date
    end

    def self.validate_uuid(uuid, name, length = 36)
      validate_presence_and_stringiness(uuid, name)
      raise ArgumentError, "#{name} is invalid. Must be #{length} characters" unless uuid.length == length

      uuid
    end

    def self.validate_ssn(ssn, name)
      validate_presence_and_stringiness(ssn, name)
      unless ssn.match?(/^(?!(000|666|9))\d{3}(?!00)\d{2}(?!0000)\d{4}$/)
        raise ArgumentError, "#{name} is invalid. Must be 9 digits (see regex for more detail)"
      end

      ssn
    end

    def self.validate_phone(object, name)
      validate_presence_and_stringiness(object[:phoneNumber], 'phone number')
      unless object[:phoneNumber].match?(/^(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}$/)
        raise ArgumentError, "#{name} is invalid. See regex for more detail"
      end

      object
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
