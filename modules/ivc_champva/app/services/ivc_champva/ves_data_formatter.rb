# frozen_string_literal: true

require_relative '../../models/ves_request'

module IvcChampva
  class VesDataFormatter
    CHILDTYPES = %w[ADOPTED STEPCHILD NATURAL].freeze
    RELATIONSHIPS = %w[SPOUSE EX_SPOUSE CAREGIVER CHILD].freeze
    GENDERS = %w[MALE FEMALE].freeze

    # This function will transform parsed form data from frontend format to VES format
    # while validating the data structure and formats
    def self.format(parsed_form_data)
      # Transform form data to VES format
      ves_data = transform_to_ves_format(parsed_form_data)

      # Run validations on the transformed data
      validate_ves_data(ves_data)

      # Return as VesRequest object
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
        firstName: veteran_data.dig('full_name', 'first'),
        lastName: veteran_data.dig('full_name', 'last'),
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

    def self.map_beneficiary(applicant_data)
      map_beneficiary_basic_info(applicant_data).merge(
        map_beneficiary_contact_info(applicant_data)
      ).merge(
        map_beneficiary_relationships(applicant_data)
      ).merge(
        map_beneficiary_insurance_info(applicant_data)
      )
    end

    def self.map_beneficiary_basic_info(applicant_data)
      {
        personUUID: SecureRandom.uuid,
        firstName: applicant_data.dig('applicant_name', 'first'),
        middleInitial: applicant_data.dig('applicant_name', 'middle'),
        lastName: applicant_data.dig('applicant_name', 'last'),
        suffix: applicant_data.dig('applicant_name', 'suffix'),
        ssn: applicant_data['ssn_or_tin'] || applicant_data.dig('applicant_ssn', 'ssn'),
        dateOfBirth: applicant_data['applicant_dob'],
        gender: normalize_gender(applicant_data.dig('applicant_gender', 'gender'))
      }
    end

    def self.map_beneficiary_contact_info(applicant_data)
      {
        emailAddress: applicant_data['applicant_email_address'],
        phoneNumber: format_phone_number(applicant_data['applicant_phone']),
        address: map_address(applicant_data['applicant_address'])
      }
    end

    def self.map_beneficiary_relationships(applicant_data)
      {
        relationshipToSponsor: convert_relationship(applicant_data['vet_relationship']),
        childtype: applicant_data.dig('childtype', 'relationship_to_veteran') ||
          applicant_data.dig('applicant_relationship_origin', 'relationship_to_veteran')
      }
    end

    def self.map_beneficiary_insurance_info(applicant_data)
      {
        enrolledInMedicare: applicant_data.dig('applicant_medicare_status', 'eligibility') == 'enrolled' ||
          applicant_data['is_enrolled_in_medicare'],
        enrolledInPartD: applicant_data.dig('applicant_medicare_part_d', 'enrollment') == 'enrolled',
        hasOtherInsurance: applicant_data.dig('applicant_has_ohi', 'has_ohi') == 'yes' ||
          applicant_data['has_other_health_insurance'],
        supportingDocuments: format_supporting_documents(applicant_data['applicant_supporting_documents'])
      }
    end

    def self.map_certification(certification_data, signature)
      return {} unless certification_data

      {
        signature:,
        signatureDate: certification_data['date'],
        firstName: certification_data['first_name'],
        lastName: certification_data['last_name'],
        middleInitial: certification_data['middle_initial'],
        phoneNumber: format_phone_number(certification_data['phone_number']),
        relationship: certification_data['relationship']
      }
    end

    def self.map_address(address_data)
      return default_address unless address_data.is_a?(Hash)

      {
        streetAddress: address_data['street_combined'] || address_data['street'] || 'NA',
        city: address_data['city'] || 'NA',
        state: address_data['state'] || 'NA',
        zipCode: address_data['postal_code'] || 'NA'
      }
    end

    def self.default_address
      {
        streetAddress: 'NA',
        city: 'NA',
        state: 'NA',
        zipCode: 'NA'
      }
    end

    def self.format_supporting_documents(documents)
      return [] unless documents.is_a?(Array)

      documents.map do |doc|
        {
          attachmentId: doc['attachment_id'],
          confirmationCode: doc['confirmation_code'],
          name: doc['name']
        }
      end
    end

    def self.validate_sponsor(request_body)
      sponsor = request_body[:sponsor]
      validate_sponsor_basic_info(sponsor)
      validate_sponsor_additional_info(sponsor)
      request_body
    end

    def self.validate_sponsor_basic_info(sponsor)
      validate_first_name(sponsor)
        .then { |s| validate_last_name(s) }
        .then { |s| validate_sponsor_address(s) }
        .then { |s| validate_date_of_birth(s) }
    end

    def self.validate_sponsor_additional_info(sponsor)
      validate_person_uuid(sponsor)
        .then { |s| validate_ssn(s) }
        .then { |s| validate_sponsor_phone(s) }
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
      validate_beneficiary_basic_info(beneficiary)
      validate_beneficiary_additional_info(beneficiary)
      beneficiary
    end

    def self.validate_beneficiary_basic_info(beneficiary)
      validate_first_name(beneficiary)
        .then { |b| validate_last_name(b) }
        .then { |b| validate_date_of_birth(b) }
        .then { |b| validate_person_uuid(b) }
    end

    def self.validate_beneficiary_additional_info(beneficiary)
      validate_beneficiary_address(beneficiary)
        .then { |b| validate_beneficiary_relationship(b) }
        .then { |b| validate_beneficiary_gender(b) }
        .then { |b| validate_ssn(b) }
    end

    def self.validate_certification(request_body)
      certification = request_body[:certification]
      validate_certification_signature(certification)
        .then { |c| validate_certification_signature_date(c) }
        .then { |c| validate_certification_phone(c) }

      request_body
    end

    # Helper methods for transformations
    def self.format_date(date_string)
      return nil if date_string.blank?
      return date_string if date_string.match?(/^\d{4}-\d{2}-\d{2}$/)

      begin
        Date.parse(date_string).strftime('%Y-%m-%d')
      rescue
        date_string
      end
    end

    def self.format_phone_number(phone)
      return nil if phone.blank?
      return phone if phone.match?(/^\(\d{3}\) \d{3}-\d{4}$/)

      # Extract digits only
      digits = phone.to_s.gsub(/\D/, '')
      return phone unless digits.length == 10

      "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}"
    end

    def self.format_ssn(ssn)
      return nil if ssn.blank?

      # Extract digits only
      digits = ssn.to_s.gsub(/\D/, '')
      return ssn unless digits.length == 9

      # Check if valid pattern
      return nil unless digits.match?(/^(?!(000|666|9))\d{3}(?!00)\d{2}(?!0000)\d{4}$/)

      digits
    end

    def self.normalize_gender(gender)
      return nil if gender.blank?

      case gender.to_s.upcase
      when 'M', 'MALE'
        'MALE'
      when 'F', 'FEMALE'
        'FEMALE'
      else
        gender.to_s.upcase
      end
    end

    def self.convert_relationship(relationship)
      return nil if relationship.blank?

      RELATIONSHIPS.each do |r|
        return r if relationship.to_s.downcase.match?(r.downcase)
      end

      raise ArgumentError, "Relationship #{relationship} is invalid. Must be in #{RELATIONSHIPS.join(', ')}"
    end

    # Validation methods
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
      validate_presence_and_stringiness(beneficiary[:gender], title)

      # Try to normalize the gender first
      beneficiary[:gender] = normalize_gender(beneficiary[:gender])

      unless GENDERS.include?(beneficiary[:gender])
        raise ArgumentError, "#{title} is invalid. Must be in #{GENDERS.join(', ')}"
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

      # Try to convert the relationship first if it's not already valid
      unless RELATIONSHIPS.include?(beneficiary[:relationshipToSponsor])
        beneficiary[:relationshipToSponsor] = convert_relationship(beneficiary[:relationshipToSponsor])
      end

      unless RELATIONSHIPS.include?(beneficiary[:relationshipToSponsor])
        raise ArgumentError, "#{title} is invalid. Must be in #{RELATIONSHIPS.join(', ')}"
      end

      validate_beneficiary_childtype(beneficiary) if beneficiary[:relationshipToSponsor] == 'CHILD'

      beneficiary
    end

    def self.validate_beneficiary_childtype(beneficiary)
      title = 'beneficiary childtype'
      validate_nonempty_presence_and_stringiness(beneficiary[:childtype], title)

      case beneficiary[:childtype]
      when 'blood'
        beneficiary[:childtype] = 'NATURAL'
      else
        beneficiary[:childtype] = beneficiary[:childtype].upcase if beneficiary[:childtype]
      end

      unless CHILDTYPES.include?(beneficiary[:childtype])
        raise ArgumentError, "#{title} is invalid. Must be in #{CHILDTYPES.join(', ')}"
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
      validate_presence_and_stringiness(request_body[:ssn], 'ssn')

      # Try to format the SSN first
      formatted_ssn = format_ssn(request_body[:ssn])

      # Update the SSN if formatting was successful
      request_body[:ssn] = formatted_ssn if formatted_ssn

      # Validate the SSN
      unless request_body[:ssn].match?(/^(?!(000|666|9))\d{3}(?!00)\d{2}(?!0000)\d{4}$/)
        raise ArgumentError, 'ssn is invalid. Must be 9 digits (see regex for more detail)'
      end

      request_body
    end

    def self.validate_phone(request_body, name)
      validate_presence_and_stringiness(request_body[:phoneNumber], 'phone number')

      # Try to format the phone number first
      formatted_phone = format_phone_number(request_body[:phoneNumber])

      # Update the phone number if formatting was successful
      request_body[:phoneNumber] = formatted_phone if formatted_phone.present?

      # Validate the phone number
      unless request_body[:phoneNumber].match?(/^(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}$/)
        raise ArgumentError, "#{name} is invalid. See regex for more detail"
      end

      request_body
    end

    def self.validate_date(date, name)
      validate_presence_and_stringiness(date, name)

      # Validate the date
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
