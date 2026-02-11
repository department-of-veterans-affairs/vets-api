# frozen_string_literal: true

require_relative 'concerns/mapper_utilities'
require 'brd/brd'

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataMapper
      class OrganizationDataMapper
        include Concerns::MapperUtilities

        def initialize(data:)
          @data = data
        end

        def map_data
          build_form
        end

        private

        def build_form
          return {} if @data.blank?

          form_data = build_form_data
          claimant_form_data = build_claimant_form_data(@data) if @data['claimant'].present?
          form_data.merge!(claimant_form_data) if claimant_form_data.present?

          { 'data' => { 'attributes' => deep_compact(form_data) } }
        end

        # rubocop:disable Metrics/MethodLength
        def build_form_data
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
                'countryCode' => @data['country_code'],
                'areaCode' => @data['area_code'],
                'phoneNumber' => @data['phone_number']
              },
              'email' => @data['email_addrs_txt'],
              'serviceNumber' => @data['service_number'],
              'insuranceNumber' => @data['insurance_numbers']
            },
            'serviceOrganization' => {
              'poaCode' => @data['poa_code'],
              'registrationNumber' => @data['registration_number'],
              'jobTitle' => @data['representative_title']
            },
            'recordConsent' => determine_bool_for_form_field(@data['section_7332_auth']),
            'consentLimits' => determine_consent_limits(@data),
            'consentAddressChange' => determine_bool_for_form_field(@data['change_address_auth'])
          }
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
