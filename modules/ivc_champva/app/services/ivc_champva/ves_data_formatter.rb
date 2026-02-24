# frozen_string_literal: true

module IvcChampva
  # rubocop:disable Metrics/ClassLength
  class VesDataFormatter
    CHILDTYPES = %w[ADOPTED STEPCHILD NATURAL].freeze
    RELATIONSHIPS = %w[SPOUSE EX_SPOUSE CAREGIVER CHILD].freeze
    GENDERS = %w[MALE FEMALE].freeze
    VALID_RELATIONSHIPS_LOOKUP = RELATIONSHIPS.index_by(&:downcase).freeze
    VALID_GENDER_LOOKUP = { 'm' => 'MALE', 'male' => 'MALE', 'f' => 'FEMALE', 'female' => 'FEMALE' }.freeze

    # Transform parsed form data from frontend format to a VES request & validate
    #
    # Use format_for_extended_request for 10-10D-EXTENDED submissions.
    #
    # @param parsed_form_data [Hash] the parsed form data from the frontend
    # @return [IvcChampva::VesRequest] the VES request object
    def self.format_for_request(parsed_form_data)
      ves_data = transform_to_ves_format(parsed_form_data)
      validate_ves_data(ves_data)

      IvcChampva::VesRequest.new(
        application_type: ves_data[:application_type],
        application_uuid: ves_data[:application_uuid],
        sponsor: ves_data[:sponsor],
        beneficiaries: ves_data[:beneficiaries],
        certification: ves_data[:certification]
      )
    end

    ##
    # Formats 10-10D-EXTENDED form data into a VesRequest with OHI subforms attached.
    # Builds the 10-10D request, then builds OHI requests for applicants with health
    # insurance data, propagates UUIDs, and attaches them as subforms.
    #
    # @param parsed_form_data [Hash] the parsed form data from the frontend
    # @return [IvcChampva::VesRequest] the VES request object with OHI subforms
    def self.format_for_extended_request(parsed_form_data)
      # Build the 10-10D request
      ves_request = format_for_request(parsed_form_data)

      # Build standalone OHI requests
      ohi_requests = format_for_ohi_request(parsed_form_data)

      # Propagate UUIDs and attach as subforms
      ohi_requests.each do |ohi_request|
        # Find matching beneficiary by SSN + name
        # TODO: is SSN required?  Is this a good way to match?
        matching_beneficiary = find_matching_beneficiary(ves_request.beneficiaries, ohi_request.beneficiary)

        # Propagate UUIDs from parent
        ohi_request.application_uuid = ves_request.application_uuid
        if matching_beneficiary
          ohi_request.person_uuid = matching_beneficiary.person_uuid
          ohi_request.beneficiary.person_uuid = matching_beneficiary.person_uuid
        end

        ves_request.add_subform(IvcChampva::VesOhiRequest::FORM_TYPE, ohi_request)
      end

      ves_request
    end

    ##
    # Formats OHI (10-7959C) form data into VesOhiRequest(s) for standalone submissions.
    #
    # @param parsed_form_data [Hash] the parsed form data from the frontend
    # @return [Array<IvcChampva::VesOhiRequest>] array of OHI request objects
    def self.format_for_ohi_request(parsed_form_data)
      applicants = parsed_form_data['applicants'] || []
      ohi_requests = []

      applicants.each do |applicant|
        next unless applicant_has_ohi_data?(applicant)

        ohi_data = transform_ohi_to_ves_format(applicant, parsed_form_data)

        # TODO: Enable validation once VES swagger spec is available
        # validate_ohi_data(ohi_data)

        ohi_requests << IvcChampva::VesOhiRequest.new(
          application_uuid: ohi_data[:application_uuid],
          person_uuid: ohi_data[:person_uuid],
          beneficiary: ohi_data[:beneficiary],
          medicare: ohi_data[:medicare],
          health_insurance: ohi_data[:health_insurance],
          certification: ohi_data[:certification]
        )
      end

      ohi_requests
    end

    ##
    # Finds a matching beneficiary by SSN and name.
    # Used to propagate person_uuid from 10-10D beneficiaries to OHI requests.
    #
    # @param beneficiaries [Array<VesRequest::Beneficiary>] the beneficiaries from the VesRequest
    # @param ohi_beneficiary [VesOhiRequest::Beneficiary] the OHI beneficiary to match
    # @return [VesRequest::Beneficiary, nil] the matching beneficiary or nil
    def self.find_matching_beneficiary(beneficiaries, ohi_beneficiary)
      beneficiaries.find do |ben|
        ben.ssn == ohi_beneficiary.ssn &&
          ben.first_name&.downcase == ohi_beneficiary.first_name&.downcase &&
          ben.last_name&.downcase == ohi_beneficiary.last_name&.downcase
      end
    end

    def self.transform_to_ves_format(parsed_form_data)
      {
        application_type: 'CHAMPVA_APPLICATION',
        application_uuid: SecureRandom.uuid,
        sponsor: map_sponsor(parsed_form_data['veteran']),
        beneficiaries: parsed_form_data['applicants'].map { |applicant| map_beneficiary(applicant) },
        certification: map_certification(
          parsed_form_data['certification'],
          parsed_form_data['statement_of_truth_signature']
        ),
        transaction_uuid: SecureRandom.uuid
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
        person_uuid: SecureRandom.uuid,
        first_name: transliterate_and_strip(veteran_data.dig('full_name', 'first')),
        last_name: transliterate_and_strip(veteran_data.dig('full_name', 'last')),
        middle_initial: veteran_data.dig('full_name', 'middle'),
        ssn: veteran_data['ssn_or_tin'],
        va_file_number: veteran_data['va_claim_number'] || veteran_data['va_file_number'] || '',
        date_of_birth: veteran_data['date_of_birth'],
        date_of_marriage: veteran_data['date_of_marriage'] || '',
        is_deceased: veteran_data['sponsor_is_deceased'] || veteran_data['is_deceased'] || false,
        date_of_death: veteran_data['date_of_death'],
        is_death_on_active_service: veteran_data['is_active_service_death'] || false,
        phone_number: format_phone_number(veteran_data['phone_number']),
        address: map_address(veteran_data['address'])
      }
    end

    def self.map_beneficiary(data)
      {
        person_uuid: SecureRandom.uuid,
        first_name: transliterate_and_strip(data.dig('applicant_name', 'first')),
        middle_initial: data.dig('applicant_name', 'middle'),
        last_name: transliterate_and_strip(data.dig('applicant_name', 'last')),
        suffix: data.dig('applicant_name', 'suffix'),
        ssn: data['ssn_or_tin'] || data.dig('applicant_ssn', 'ssn'),
        date_of_birth: data['applicant_dob'],
        gender: normalize_gender(data.dig('applicant_gender', 'gender')),
        email_address: data['applicant_email_address'],
        phone_number: format_phone_number(data['applicant_phone']),
        address: map_address(data['applicant_address']),
        relationship_to_sponsor: convert_relationship(data['vet_relationship']),
        child_type: normalize_childtype(data.dig('childtype', 'relationship_to_veteran') ||
          data.dig('applicant_relationship_origin', 'relationship_to_veteran')),
        enrolled_in_medicare: data.dig('applicant_medicare_status', 'eligibility') == 'enrolled' ||
          data['is_enrolled_in_medicare'],
        has_other_insurance: data.dig('applicant_has_ohi', 'has_ohi') == 'yes' || data['has_other_health_insurance']
      }
    end

    def self.map_certification(certification_data, signature)
      return {} unless certification_data

      {
        signature:,
        signature_date: certification_data['date'],
        first_name: transliterate_and_strip(certification_data['first_name']),
        last_name: transliterate_and_strip(certification_data['last_name']),
        middle_initial: certification_data['middle_initial'],
        phone_number: format_phone_number(certification_data['phone_number']),
        relationship: certification_data['relationship'],
        address: map_address(certification_data)
      }
    end

    def self.map_address(address_data)
      return nil unless address_data.is_a?(Hash)

      country = address_data['country']&.upcase || 'USA'

      address = {
        street_address: address_data['street_combined'] || address_data['street'] ||
                        address_data['street_address']
      }

      # Always required
      address[:city] = address_data['city']

      if country == 'USA'
        # For USA addresses, use state and zip_code (current behavior)
        address[:state] = address_data['state']
        address[:zip_code] = address_data['postal_code']
      else
        # For international addresses, use country, province, and postal_code
        address[:country] = country
        address[:province] = address_data['state'] # Map state data to province
        address[:postal_code] = address_data['postal_code']
      end

      return nil if address.values.all?(&:nil?)

      address
    end

    ##
    # Checks if an applicant has OHI data (health_insurance or medicare).
    #
    # @param applicant [Hash] applicant data
    # @return [Boolean]
    def self.applicant_has_ohi_data?(applicant)
      health_insurance = applicant['health_insurance']
      medicare = applicant['medicare']

      (health_insurance.is_a?(Array) && health_insurance.any?) ||
        (medicare.is_a?(Array) && medicare.any?)
    end

    ##
    # Transforms applicant data to VES OHI format.
    #
    # @param applicant_data [Hash] the applicant data
    # @param parsed_form_data [Hash] the full form data (for certification)
    # @return [Hash] the transformed data
    def self.transform_ohi_to_ves_format(applicant_data, parsed_form_data)
      {
        application_uuid: SecureRandom.uuid,
        person_uuid: SecureRandom.uuid,
        beneficiary: map_ohi_beneficiary(applicant_data),
        medicare: map_medicare(applicant_data['medicare'] || []),
        health_insurance: map_health_insurance(applicant_data['health_insurance'] || []),
        certification: map_ohi_certification(parsed_form_data)
      }
    end

    ##
    # Maps applicant data to OHI beneficiary format.
    # Reuses existing map_beneficiary logic where applicable.
    #
    # @param applicant_data [Hash] the applicant data
    # @param person_uuid [String, nil] optional person UUID to use (for extended form UUID propagation)
    # @return [Hash]
    def self.map_ohi_beneficiary(applicant_data, person_uuid = nil)
      {
        person_uuid: person_uuid || SecureRandom.uuid,
        first_name: transliterate_and_strip(applicant_data.dig('applicant_name', 'first')),
        middle_initial: applicant_data.dig('applicant_name', 'middle'),
        last_name: transliterate_and_strip(applicant_data.dig('applicant_name', 'last')),
        suffix: applicant_data.dig('applicant_name', 'suffix'),
        ssn: applicant_data['ssn_or_tin'] || applicant_data['applicant_ssn'],
        date_of_birth: applicant_data['applicant_dob'],
        gender: normalize_gender(applicant_data.dig('applicant_gender',
                                                    'gender') || applicant_data['applicant_gender']),
        email_address: applicant_data['applicant_email_address'] || applicant_data['applicant_email'],
        phone_number: format_phone_number(applicant_data['applicant_phone']),
        address: map_address(applicant_data['applicant_address'])
      }
    end

    ##
    # Maps medicare data array to VES format.
    #
    # @param medicare_array [Array<Hash>] medicare entries from the form
    # @return [Array<Hash>]
    def self.map_medicare(medicare_array)
      return [] unless medicare_array.is_a?(Array)

      medicare_array.map do |medicare|
        {
          plan_type: medicare['medicare_plan_type'],
          medicare_number: medicare['medicare_number'],
          part_a_effective_date: format_date(medicare['medicare_part_a_effective_date']),
          part_b_effective_date: format_date(medicare['medicare_part_b_effective_date']),
          part_c_carrier: medicare['medicare_part_c_carrier'],
          part_c_effective_date: format_date(medicare['medicare_part_c_effective_date']),
          has_pharmacy_benefits: medicare['has_pharmacy_benefits'],
          has_part_d: medicare['has_medicare_part_d'],
          part_d_carrier: medicare['medicare_part_d_carrier'],
          part_d_effective_date: format_date(medicare['medicare_part_d_effective_date'])
        }.compact
      end
    end

    ##
    # Maps health_insurance data array to VES format.
    #
    # @param health_insurance_array [Array<Hash>] health insurance entries from the form
    # @return [Array<Hash>]
    def self.map_health_insurance(health_insurance_array)
      return [] unless health_insurance_array.is_a?(Array)

      health_insurance_array.map do |insurance|
        {
          insurance_type: insurance['insurance_type'],
          medigap_plan: insurance['medigap_plan'],
          provider: insurance['provider'],
          effective_date: format_date(insurance['effective_date']),
          expiration_date: format_date(insurance['expiration_date']),
          through_employer: insurance['through_employer'],
          eob: insurance['eob'],
          additional_comments: insurance['additional_comments']
        }.compact
      end
    end

    ##
    # Maps certification data for OHI submissions.
    #
    # @param form_data [Hash] the parsed form data containing certification info
    # @return [Hash]
    def self.map_ohi_certification(form_data)
      return {} if form_data.nil?

      certification = form_data['certification'] || {}
      {
        signature: form_data['statement_of_truth_signature'],
        signature_date: certification['date'] || form_data['certification_date'],
        first_name: transliterate_and_strip(certification['first_name']),
        last_name: transliterate_and_strip(certification['last_name']),
        middle_initial: certification['middle_initial'],
        phone_number: format_phone_number(certification['phone_number']),
        relationship: certification['relationship'] || form_data['certifier_role'],
        address: map_address(certification)
      }.compact
    end

    ##
    # Validates OHI data before building request.
    # TODO: Implement validation once VES swagger spec is available
    #
    # @param data [Hash] the transformed OHI data
    def self.validate_ohi_data(data)
      # TODO: Add validation rules based on VES swagger spec
      # For now, just return the data as-is
      data
    end

    # ============================================================================
    # Data formatting methods
    # ============================================================================
    def self.format_phone_number(phone)
      return nil if phone.blank?

      phone = phone.to_s.gsub(/\D/, '')

      # regex from VES swagger
      return phone if phone.match?(/^[0-9+]+$/)

      # TODO: add country code check/formatting
      phone.to_s.gsub(/\D/, '')
    end

    def self.format_ssn(ssn)
      return nil if ssn.blank?

      digits = ssn.to_s.gsub(/\D/, '')
      return ssn unless digits.length == 9

      # regex from VES swagger
      return nil unless digits.match?(/^(?!(000|666|9))\d{3}(?!00)\d{2}(?!0000)\d{4}$/)

      digits
    end

    def self.format_date(date_string)
      return nil if date_string.blank?

      return date_string if date_string.match?(/^\d{4}-\d{2}-\d{2}$/)

      begin
        # parsed_form_data should be correct already
        # TODO: add checks for other delimiters
        "#{date_string[6..]}-#{date_string[0..4]}" if date_string.match?(/^\d{2}-\d{2}-\d{4}$/)
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

      raise ArgumentError, "Relationship #{relationship} is invalid. Must be in #{RELATIONSHIPS.join(', ')}"
    end

    def self.normalize_childtype(childtype)
      return nil if childtype.blank?

      case childtype.to_s.downcase
      when 'blood'
        'NATURAL'
      when 'adoption'
        'ADOPTED'
      when 'step'
        'STEPCHILD'
      else
        childtype.to_s.upcase
      end
    end

    def self.transliterate_and_strip(text)
      return nil if text.blank?

      transliterated = I18n.transliterate(text).gsub(%r{[^a-zA-Z\-/\s]}, '').strip

      return nil if transliterated.blank?

      transliterated
    end

    def self.validate_sponsor(request_body)
      sponsor = request_body[:sponsor]

      validate_name_fields(sponsor, 'sponsor')
      if sponsor[:is_deceased] == true
        sponsor[:address] =
          { street_address: 'NA', city: 'NA', state: 'NA', zip_code: 'NA' }
        sponsor[:date_of_death] = validate_date(sponsor[:date_of_death], 'date of death')
      end
      validate_address(sponsor[:address], 'sponsor')
      sponsor[:date_of_birth] = validate_date(sponsor[:date_of_birth], 'date of birth')
      if sponsor[:date_of_marriage].presence
        sponsor[:date_of_marriage] =
          validate_date(sponsor[:date_of_marriage], 'date of marriage')
      end
      validate_uuid(sponsor[:person_uuid], 'person uuid')
      validate_ssn(sponsor[:ssn], 'ssn')
      validate_phone(sponsor, 'sponsor phone') if sponsor[:phone_number]

      request_body
    end

    def self.validate_beneficiaries(request_body)
      beneficiaries = request_body[:beneficiaries]
      raise ArgumentError, 'beneficiaries is invalid. Must be an array' unless beneficiaries.is_a?(Array)

      beneficiaries.each do |beneficiary|
        validate_name_fields(beneficiary, 'beneficiary')
        beneficiary[:date_of_birth] = validate_date(beneficiary[:date_of_birth], 'date of birth')
        validate_uuid(beneficiary[:person_uuid], 'person uuid')
        validate_address(beneficiary[:address], 'beneficiary')
        validate_ssn(beneficiary[:ssn], 'ssn')

        # not required by VES
        validate_relationship_fields(beneficiary) if beneficiary[:relationship_to_sponsor]
        validate_gender(beneficiary) if beneficiary[:gender]
        validate_email(beneficiary[:email_address]) if beneficiary[:email_address]
      end

      request_body
    end

    def self.validate_certification(request_body)
      certification = request_body[:certification]
      return request_body if certification.blank? || certification.empty?

      # only signature and signature_date are required by VES
      validate_presence_and_stringiness(certification[:signature], 'certification signature')
      certification[:signature_date] = validate_date(certification[:signature_date], 'certification signature date')
      validate_phone(certification, 'certification phone') if certification[:phone_number]

      request_body
    end

    def self.validate_application_type(request_body)
      validate_presence_and_stringiness(request_body[:application_type], 'application type')
      unless request_body[:application_type] == 'CHAMPVA_APPLICATION'
        raise ArgumentError, 'application type invalid. Must be CHAMPVA_APPLICATION'
      end

      request_body
    end

    def self.validate_application_uuid(request_body)
      validate_uuid(request_body[:application_uuid], 'application UUID')
      request_body
    end

    def self.validate_name_fields(object, prefix)
      validate_presence_and_stringiness(object[:first_name], "#{prefix} first name")
      validate_presence_and_stringiness(object[:last_name], "#{prefix} last name")
      object
    end

    def self.validate_relationship_fields(beneficiary)
      # Validate relationship
      validate_presence_and_stringiness(beneficiary[:relationship_to_sponsor], 'beneficiary relationship to sponsor')

      unless RELATIONSHIPS.include?(beneficiary[:relationship_to_sponsor])
        raise ArgumentError, "beneficiary relationship to sponsor #{beneficiary[:relationship_to_sponsor]}" \
                             " is invalid. Must be in #{RELATIONSHIPS.join(', ')}"
      end

      # Validate childtype if relationship is CHILD
      if beneficiary[:relationship_to_sponsor] == 'CHILD'
        validate_nonempty_presence_and_stringiness(beneficiary[:child_type], 'beneficiary childtype')

        unless CHILDTYPES.include?(beneficiary[:child_type])
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
      raise ArgumentError, "#{name} address is missing" if address.nil?

      validate_nonempty_presence_and_stringiness(address[:city], "#{name} city")
      validate_nonempty_presence_and_stringiness(address[:street_address], "#{name} street address")

      # Check if this is an international address
      if address[:country] && address[:country].upcase != 'USA'
        # International address validation
        validate_nonempty_presence_and_stringiness(address[:country], "#{name} country")
        # province and postal_code are optional for international addresses
      else
        # USA address validation (existing behavior)
        validate_nonempty_presence_and_stringiness(address[:state], "#{name} state")
        validate_nonempty_presence_and_stringiness(address[:zip_code], "#{name} zip code")
      end
    end

    def self.validate_date(date, name)
      validate_presence_and_stringiness(date, name)

      # If we can, coerce date into proper format
      date = format_date(date)

      raise ArgumentError, "#{name} is invalid. Must match YYYY-MM-DD#{date}" unless date.match?(/^\d{4}-\d{2}-\d{2}$/)

      date
    end

    def self.validate_uuid(uuid, name, length = 36)
      validate_presence_and_stringiness(uuid, name)
      raise ArgumentError, "#{name} is invalid. Must be #{length} characters" unless uuid.length == length

      uuid
    end

    def self.validate_ssn(ssn, name)
      validate_presence_and_stringiness(ssn, name)
      unless ssn.match?(/^\d{9}$/)
        raise ArgumentError, "#{name} is invalid. Must be 9 digits (see regex for more detail)"
      end

      ssn
    end

    def self.validate_email(email)
      validate_presence_and_stringiness(email, 'email address')
      unless email.match?(URI::MailTo::EMAIL_REGEXP)
        raise ArgumentError, 'email address is invalid. See regex for more detail'
      end
    end

    def self.validate_phone(object, name)
      validate_presence_and_stringiness(object[:phone_number], 'phone number')

      unless object[:phone_number].match?(/^[0-9+]+$/) && object[:phone_number].length >= 10
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
  # rubocop:enable Metrics/ClassLength
end
