# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataMapper
      class OrganizationDataMapper
        CONSENT_LIMITS = {
          'limitation_drug_abuse' => 'DRUG_ABUSE',
          'limitation_alcohol' => 'ALCOHOLISM',
          'limitation_hiv' => 'HIV',
          'limitation_sca' => 'SICKLE_CELL'
        }.freeze

        def initialize(data:)
          @data = data
        end

        def map_data
          build_form
        end

        private

        def build_form
          return [] if @data.blank?

          form_data = build_form_data
          claimant_form_data = build_claimant_form_data if @data['claimant'].present?
          form_data.merge!(claimant_form_data) if claimant_form_data.present?

          { 'data' => { 'attributes' => form_data } }
        end

        def build_form_data # rubocop:disable Metrics/MethodLength
          {
            'veteran' => {
              'address' => {
                'addressLine1' => @data['addrs_one_txt'],
                'addressLine2' => @data['addrs_two_txt'],
                'city' => @data['city_nm'],
                'stateCode' => @data['postal_cd'],
                'countryCode' => ClaimsApi::BRD::COUNTRY_CODES.invert[@data['cntry_nm']],
                'zipCode' => @data['zip_prefix_nbr'],
                'zipCodeSuffix' => @data['zip_first_suffix_nbr']
              },
              'phone' => {
                'countryCode' => parse_phone_number(@data['phone_number'])[0],
                'areaCode' => parse_phone_number(@data['phone_number'])[1],
                'phoneNumber' => parse_phone_number(@data['phone_number'])[2]
              },
              'email' => @data['email_addrs_txt'],
              'serviceNumber' => @data['service_number'],
              'insuranceNumber' => @data['insurance_numbers']
            },
            'serviceOrganization' => {
              'poaCode' => @data['poa_code'],
              'registrationNumber' => @data['registration_number'],
              'jobTitle' => @data['representative_title']
              # "email" => @data[']
            },
            'recordConsent' => determine_bool_for_form_field(@data['section_7332_auth']),
            'consentLimits' => determine_consent_limits,
            'consentAddressChange' => determine_bool_for_form_field(@data['change_address_auth'])
          }.compact
        end

        def build_claimant_form_data # rubocop:disable Metrics/MethodLength
          {
            'claimant' => {
              'claimantId' => @data['claimant']['claimant_id'],
              'address' => {
                'addressLine1' => @data['claimant']['addrs_one_txt'],
                'addressLine2' => @data['claimant']['addrs_two_txt'],
                'city' => @data['claimant']['city_nm'],
                'stateCode' => @data['claimant']['postal_cd'],
                'countryCode' => ClaimsApi::BRD::COUNTRY_CODES.invert[@data['claimant']['cntry_nm']],
                'zipCode' => @data['claimant']['zip_prefix_nbr'],
                'zipCodeSuffix' => @data['claimant']['zip_first_suffix_nbr']
              },
              'phone' => {
                'countryCode' => parse_phone_number(@data['claimant']['phone_nbr'])[0],
                'areaCode' => parse_phone_number(@data['claimant']['phone_nbr'])[1],
                'phoneNumber' => parse_phone_number(@data['claimant']['phone_nbr'])[2]
              },
              'email' => @data['claimant']['email_addrs_txt'],
              'relationship' => @data['claimant_relationship']
            }
          }.compact
        end

        def parse_phone_number(number)
          return [] unless number.is_a?(String) && number.length < 12

          if number.length == 10
            area_code = number[0, 3]
            phone_number = number[-7, 7]
            country_code = nil
          elsif number.length == 11
            area_code = number[1, 3]
            phone_number = number[-7, 7]
            country_code = number[0, 1]
          end

          [country_code, area_code, phone_number]
        end

        def determine_bool_for_form_field(val)
          val == 'true'
        end

        def determine_consent_limits
          keys = CONSENT_LIMITS.keys
          limits = []
          keys.each do |key|
            value = @data[key]
            limits << CONSENT_LIMITS[key] if value == 'true'
          end

          limits
        end
      end
    end
  end
end
