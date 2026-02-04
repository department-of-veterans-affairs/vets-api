# frozen_string_literal: true

require_relative 'concerns/mapper_utilities'
require 'brd/brd'

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataMapper
      class IndividualDataMapper
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
              'serviceNumber' => @data['registration_number'],
              'serviceBranch' => @data['service_branch']
            },
            'representative' => {
              'poaCode' => @data['poa_code'],
              'type' => representative_type(@data['poa_code']),
              'registrationNumber' => @data['registration_number'],
              'address' => {
                'addressLine1' => @data.dig('representative', 'addrs_one_txt'),
                'addressLine2' => @data.dig('representative', 'addrs_two_txt'),
                'city' => @data.dig('representative', 'city_nm'),
                'stateCode' => @data.dig('representative', 'postal_cd'),
                'countryCode' => ClaimsApi::BRD::COUNTRY_CODES.invert[@data.dig('representative', 'cntry_nm')],
                'zipCode' => @data.dig('representative', 'zip_prefix_nbr'),
                'zipCodeSuffix' => @data.dig('representative', 'zip_first_suffix_nbr')
              }
            },
            'recordConsent' => determine_bool_for_form_field(@data['section_7332_auth']),
            'consentLimits' => determine_consent_limits(@data),
            'consentAddressChange' => determine_bool_for_form_field(@data['change_address_auth'])
          }
        end
        # rubocop:enable Metrics/MethodLength

        def representative_type(poa_code)
          representative = ::Veteran::Service::Representative.where('? = ANY(poa_codes)',
                                                                    poa_code).order(created_at: :desc).first
          validate_representative!(representative, poa_code)

          representative.user_types.first.upcase
        end

        def validate_representative!(representative, poa_code)
          # there must be a representative
          if representative.blank?
            raise ::Common::Exceptions::ResourceNotFound.new(
              detail: "Could not find an Accredited Representative with poa code: #{poa_code}"
            )
          end
        end
      end
    end
  end
end
