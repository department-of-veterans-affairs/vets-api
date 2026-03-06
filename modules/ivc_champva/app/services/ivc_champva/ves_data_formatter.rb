# frozen_string_literal: true

module IvcChampva
  # rubocop:disable Metrics/ClassLength
  class VesDataFormatter
    CHILDTYPES = %w[ADOPTED STEPCHILD NATURAL].freeze
    RELATIONSHIPS = %w[SPOUSE EX_SPOUSE CAREGIVER CHILD].freeze
    GENDERS = %w[MALE FEMALE].freeze
    VALID_RELATIONSHIPS_LOOKUP = RELATIONSHIPS.index_by(&:downcase).freeze
    VALID_GENDER_LOOKUP = { 'm' => 'MALE', 'male' => 'MALE', 'f' => 'FEMALE', 'female' => 'FEMALE' }.freeze

    MEDICARE_PART_TYPE_MAP = {
      'a' => 'MEDICARE_PART_A',
      'b' => 'MEDICARE_PART_B',
      'd' => 'MEDICARE_PART_D'
    }.freeze

    INSURANCE_PLAN_TYPE_MAP = {
      'hmo' => 'HMO',
      'ppo' => 'PPO',
      'medicare_advantage' => 'MEDICARE_ADVANTAGE',
      'medicaid' => 'MEDICAID',
      'medigap' => 'MEDIGAP_PLAN',
      'medigap_plan' => 'MEDIGAP_PLAN',
      'other' => 'OTHER'
    }.freeze

    SSN_PATTERN = /^\d{9}$/
    MEDICARE_BENE_ID_PATTERN = /^[a-zA-Z0-9]{1,11}$/
    EMAIL_PATTERN = URI::MailTo::EMAIL_REGEXP
    PHONE_PATTERN = /^[0-9+]+$/
    DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/

    # @return [IvcChampva::VesRequest]
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

    # Builds 10-10D request with OHI subforms attached, UUIDs propagated.
    # @return [IvcChampva::VesRequest]
    def self.format_for_extended_request(parsed_form_data)
      ves_request = format_for_request(parsed_form_data)
      ohi_requests = format_for_ohi_request(parsed_form_data)

      ohi_requests.each do |ohi_request|
        ohi_bene = ohi_request.beneficiary_medicare
        matching_beneficiary = find_matching_beneficiary(ves_request.beneficiaries, ohi_bene)
        ohi_request.application_uuid = ves_request.application_uuid
        ohi_bene.person_uuid = matching_beneficiary.person_uuid if matching_beneficiary

        ves_request.add_subform(IvcChampva::VesOhiRequest::FORM_TYPE, ohi_request)
      end

      ves_request
    end

    # @return [Array<IvcChampva::VesOhiRequest>]
    def self.format_for_ohi_request(parsed_form_data)
      applicants = parsed_form_data['applicants'] || []
      ohi_requests = []

      applicants.each do |applicant|
        next unless applicant_has_ohi_data?(applicant)

        ohi_data = transform_ohi_to_ves_format(applicant, parsed_form_data)
        validate_ohi_data(ohi_data)

        ohi_requests << IvcChampva::VesOhiRequest.new(
          application_uuid: ohi_data[:application_uuid],
          beneficiary_medicare: ohi_data[:beneficiary_medicare],
          certification: ohi_data[:certification]
        )
      end

      ohi_requests
    end

    # Finds matching beneficiary by SSN and name for UUID propagation.
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

    # @param applicant_data [Hash] the applicant data
    # @param parsed_form_data [Hash] the full form data (for certification)
    # @return [Hash] the transformed data
    def self.transform_ohi_to_ves_format(applicant_data, parsed_form_data)
      beneficiary_data = map_ohi_beneficiary(applicant_data)
      medicare_array = applicant_data['medicare'] || []

      {
        application_uuid: SecureRandom.uuid,
        beneficiary_medicare: beneficiary_data.merge(
          medicare_bene_id: extract_medicare_bene_id(medicare_array),
          medicare_parts: map_medicare_parts(medicare_array),
          other_insurances: map_ohi_other_insurances(applicant_data)
        ),
        certification: map_ohi_certification(parsed_form_data)
      }
    end

    # Combines health_insurance entries with Medicare Part C (treated as other insurance).
    # @return [Array<Hash>] array of insurance hashes, empty if none found
    def self.map_ohi_other_insurances(applicant_data)
      health_insurance = map_other_insurances(applicant_data['health_insurance'] || [])
      medicare_part_c = extract_medicare_part_c(applicant_data['medicare'] || [])
      health_insurance + medicare_part_c
    end

    # Extracts medicare beneficiary ID (first non-blank medicare_number found).
    def self.extract_medicare_bene_id(medicare_array)
      return nil unless medicare_array.is_a?(Array)

      medicare_array.lazy.map { |m| m['medicare_number'] }.find(&:present?)
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
        ssn: extract_ssn(applicant_data),
        date_of_birth: format_date(applicant_data['applicant_dob']),
        gender: normalize_gender(extract_gender(applicant_data)),
        email_address: applicant_data['applicant_email_address'] || applicant_data['applicant_email'],
        phone_number: format_phone_number(applicant_data['applicant_phone']),
        address: map_address(applicant_data['applicant_address']),
        is_new_address: normalize_yes_no(applicant_data['applicant_new_address'])
      }.compact
    end

    # Handles both nested { 'applicant_gender' => { 'gender' => 'male' } } and flat structures.
    def self.extract_gender(applicant_data)
      gender_field = applicant_data['applicant_gender']
      return nil if gender_field.nil?
      return gender_field['gender'] if gender_field.is_a?(Hash)

      gender_field
    end

    # Handles both nested { 'applicant_ssn' => { 'ssn' => '...' } } and flat structures.
    def self.extract_ssn(applicant_data)
      ssn = applicant_data.dig('applicant_ssn', 'ssn') if applicant_data['applicant_ssn'].is_a?(Hash)
      ssn || applicant_data['ssn_or_tin'] || applicant_data['applicant_ssn']
    end

    def self.normalize_yes_no(value)
      return nil if value.nil?
      return value if [true, false].include?(value)

      case value.to_s.downcase
      when 'yes', 'true', '1' then true
      when 'no', 'false', '0' then false
      end
    end

    # Parts A, B, D go into medicareParts; Part C goes to otherInsurances as MEDICARE_ADVANTAGE
    MEDICARE_PART_CONFIGS = [
      { type: 'MEDICARE_PART_A', date_key: 'medicare_part_a_effective_date' },
      { type: 'MEDICARE_PART_B', date_key: 'medicare_part_b_effective_date' },
      { type: 'MEDICARE_PART_D', date_key: 'medicare_part_d_effective_date', flag_key: 'has_medicare_part_d' }
    ].freeze

    # Maps A, B, D medicare parts. Returns [] if no parts found.
    def self.map_medicare_parts(medicare_array)
      return [] unless medicare_array.is_a?(Array)

      medicare_array.flat_map do |medicare|
        MEDICARE_PART_CONFIGS.filter_map do |config|
          build_medicare_part(medicare, config)
        end
      end
    end

    def self.build_medicare_part(medicare, config)
      has_date = medicare[config[:date_key]].present?
      has_flag = config[:flag_key] && medicare[config[:flag_key]]
      return nil unless has_date || has_flag

      {
        medicare_part_type: config[:type],
        effective_date: format_date(medicare[config[:date_key]])
      }.compact
    end

    # Extracts Medicare Part C entries as other insurances. Returns [] if none found.
    def self.extract_medicare_part_c(medicare_array)
      return [] unless medicare_array.is_a?(Array)

      medicare_array.filter_map do |medicare|
        plan_type = medicare['medicare_plan_type']&.to_s&.downcase
        has_part_c = plan_type&.include?('c') || medicare['medicare_part_c_effective_date'].present?
        next unless has_part_c

        {
          insurance_name: medicare['medicare_part_c_carrier'],
          insurance_plan_type: 'MEDICARE_ADVANTAGE',
          effective_date: format_date(medicare['medicare_part_c_effective_date']),
          comments: medicare['medicare_part_c_description'],
          is_prescription_covered: medicare['has_pharmacy_benefits']
        }.compact
      end
    end

    # Maps health_insurance entries to otherInsurances format. Returns [] if none.
    def self.map_other_insurances(health_insurance_array)
      return [] unless health_insurance_array.is_a?(Array)

      health_insurance_array.map do |insurance|
        plan_type = insurance['insurance_type'] || insurance['insurance_plan_type']
        {
          insurance_name: insurance['provider'] || insurance['insurance_name'],
          effective_date: format_date(insurance['effective_date']),
          termination_date: format_date(insurance['expiration_date'] || insurance['termination_date']),
          insurance_plan_type: normalize_insurance_plan_type(plan_type),
          is_through_employment: insurance['through_employer'] || insurance['is_through_employment'],
          is_prescription_covered: insurance['is_prescription_covered'] || insurance['has_prescription'],
          eob_indicator: normalize_eob_indicator(insurance['eob'] || insurance['eob_indicator']),
          comments: insurance['additional_comments'] || insurance['comments']
        }.compact
      end
    end

    # Normalizes to VES enum: HMO, PPO, MEDICARE_ADVANTAGE, MEDICAID, MEDIGAP_PLAN, OTHER
    def self.normalize_insurance_plan_type(plan_type)
      return nil if plan_type.blank?

      INSURANCE_PLAN_TYPE_MAP[plan_type.to_s.downcase] || 'OTHER'
    end

    # EOB indicator comes in as boolean from frontend form data
    def self.normalize_eob_indicator(value)
      return nil if value.nil?
      return value if [true, false].include?(value)

      normalize_yes_no(value)
    end

    def self.map_ohi_certification(form_data)
      return {} if form_data.nil?

      certification = form_data['certification'] || {}
      {
        signature: form_data['statement_of_truth_signature'],
        signature_date: format_date(certification['date'] || form_data['certification_date']),
        first_name: transliterate_and_strip(certification['first_name']),
        last_name: transliterate_and_strip(certification['last_name']),
        middle_initial: certification['middle_initial'],
        phone_number: format_phone_number(certification['phone_number']),
        relationship: certification['relationship'] || form_data['certifier_role'],
        address: map_address(certification)
      }.compact
    end

    # Validates transformed data against schema requirements. Raises ArgumentError on failure.
    def self.validate_ohi_data(data)
      validate_ohi_application_uuid(data[:application_uuid])
      validate_ohi_beneficiary_medicare(data[:beneficiary_medicare])
      validate_ohi_certification(data[:certification])
      data
    end

    def self.validate_ohi_certification(cert)
      raise ArgumentError, 'certification is required' if cert.blank?

      validate_presence_and_stringiness(cert[:signature], 'certification.signature')
      cert[:signature_date] = validate_date(cert[:signature_date], 'certification.signatureDate')
    end

    def self.validate_ohi_application_uuid(uuid)
      validate_uuid(uuid, 'applicationUUID')
    end

    def self.validate_ohi_beneficiary_medicare(bene)
      raise ArgumentError, 'beneficiaryMedicare is required' if bene.nil?

      validate_uuid(bene[:person_uuid], 'beneficiaryMedicare.personUUID')
      validate_name_fields(bene, 'beneficiaryMedicare')

      validate_ssn(bene[:ssn], 'beneficiaryMedicare.ssn')

      validate_presence_and_stringiness(bene[:gender], 'beneficiaryMedicare.gender')
      validate_enum(bene[:gender], GENDERS, 'beneficiaryMedicare.gender')

      validate_ohi_address(bene[:address], 'beneficiaryMedicare.address')

      # Optional fields: validate format if present
      if bene[:medicare_bene_id].present?
        validate_pattern(bene[:medicare_bene_id], MEDICARE_BENE_ID_PATTERN, 'beneficiaryMedicare.medicareBeneId',
                         'must be 1-11 alphanumeric characters')
      end
      validate_email(bene[:email_address]) if bene[:email_address].present?
      validate_phone(bene, 'beneficiaryMedicare.phoneNumber') if bene[:phone_number].present?
      if bene[:date_of_birth].present?
        bene[:date_of_birth] = validate_date(bene[:date_of_birth], 'beneficiaryMedicare.dateOfBirth')
      end

      validate_ohi_medicare_parts(bene[:medicare_parts] || [])
      validate_ohi_other_insurances(bene[:other_insurances] || [])
    end

    def self.validate_ohi_address(address, field_prefix)
      validate_address(address, field_prefix)
    end

    def self.validate_ohi_medicare_parts(medicare_parts)
      medicare_parts.each_with_index do |part, idx|
        prefix = "beneficiaryMedicare.medicareParts[#{idx}]"

        part[:effective_date] = validate_date(part[:effective_date], "#{prefix}.effectiveDate")

        validate_presence_and_stringiness(part[:medicare_part_type], "#{prefix}.medicarePartType")
        validate_enum(part[:medicare_part_type], MEDICARE_PART_TYPE_MAP.values, "#{prefix}.medicarePartType")

        # Optional field: validate format if present
        if part[:termination_date].present?
          part[:termination_date] = validate_date(part[:termination_date], "#{prefix}.terminationDate")
        end
      end
    end

    def self.validate_ohi_other_insurances(other_insurances)
      other_insurances.each_with_index do |ins, idx|
        prefix = "beneficiaryMedicare.otherInsurances[#{idx}]"

        validate_nonempty_presence_and_stringiness(ins[:insurance_name], "#{prefix}.insuranceName")

        ins[:effective_date] = validate_date(ins[:effective_date], "#{prefix}.effectiveDate")

        validate_presence_and_stringiness(ins[:insurance_plan_type], "#{prefix}.insurancePlanType")
        validate_enum(ins[:insurance_plan_type], INSURANCE_PLAN_TYPE_MAP.values, "#{prefix}.insurancePlanType")

        # Optional field: validate format if present
        if ins[:termination_date].present?
          ins[:termination_date] = validate_date(ins[:termination_date], "#{prefix}.terminationDate")
        end
      end
    end

    def self.validate_pattern(value, pattern, field_name, message)
      return if value.blank?
      raise ArgumentError, "#{field_name} #{message}" unless value.to_s.match?(pattern)
    end

    def self.validate_enum(value, allowed_values, field_name)
      return if value.blank?

      unless allowed_values.include?(value)
        raise ArgumentError, "#{field_name} '#{value}' is invalid. Must be one of: #{allowed_values.join(', ')}"
      end
    end

    def self.validate_date_format(value, field_name)
      return if value.blank?
      raise ArgumentError, "#{field_name} must be in YYYY-MM-DD format" unless value.to_s.match?(DATE_PATTERN)
    end

    # ============================================================================
    # Data formatting methods
    # ============================================================================
    def self.format_phone_number(phone)
      return nil if phone.blank?

      # Strip all non-digit/non-plus characters to match VES PHONE_PATTERN
      phone.to_s.gsub(/[^0-9+]/, '')
    end

    def self.format_ssn(ssn)
      return nil if ssn.blank?

      digits = ssn.to_s.gsub(/\D/, '')
      return ssn unless digits.length == 9

      # regex from VES swagger
      return nil unless digits.match?(/^(?!(000|666|9))\d{3}(?!00)\d{2}(?!0000)\d{4}$/)

      digits
    end

    ##
    # Normalizes date strings to YYYY-MM-DD format.
    # Handles MM-DD-YYYY, MM/DD/YYYY, and already formatted dates.
    #
    # @param date_string [String, nil] the date string to format
    # @return [String, nil] the formatted date or original string if unparseable
    def self.format_date(date_string)
      return nil if date_string.blank?
      return date_string if date_string.match?(DATE_PATTERN)

      # MM-DD-YYYY or MM/DD/YYYY -> YYYY-MM-DD
      if (match = date_string.match(%r{^(\d{2})[-/](\d{2})[-/](\d{4})$}))
        return "#{match[3]}-#{match[1]}-#{match[2]}"
      end

      date_string
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
      date = format_date(date)
      raise ArgumentError, "#{name} is invalid. Must match YYYY-MM-DD" unless date.match?(DATE_PATTERN)

      date
    end

    def self.validate_uuid(uuid, name, length = 36)
      validate_presence_and_stringiness(uuid, name)
      raise ArgumentError, "#{name} is invalid. Must be #{length} characters" unless uuid.length == length

      uuid
    end

    def self.validate_ssn(ssn, name)
      validate_presence_and_stringiness(ssn, name)
      unless ssn.match?(SSN_PATTERN)
        raise ArgumentError,
              "#{name} is invalid. Must be 9 digits (see regex for more detail)"
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

      unless object[:phone_number].match?(PHONE_PATTERN) && object[:phone_number].length >= 10
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
