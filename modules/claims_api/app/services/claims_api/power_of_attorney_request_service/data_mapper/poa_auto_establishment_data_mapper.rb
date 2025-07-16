# frozen_string_literal: true

require_relative 'individual_data_mapper'
require_relative 'organization_data_mapper'

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataMapper
      class PoaAutoEstablishmentDataMapper
        include ClaimsApi::V2::PowerOfAttorneyValidation

        DATA_MAPPERS = {
          '2122a' => ClaimsApi::PowerOfAttorneyRequestService::DataMapper::IndividualDataMapper,
          '2122' => ClaimsApi::PowerOfAttorneyRequestService::DataMapper::OrganizationDataMapper
        }.freeze

        def initialize(type:, data:, veteran:)
          @type = type
          @data = data
          @veteran = veteran
        end

        def map_data
          mapper_class = DATA_MAPPERS[@type].new(data: @data)
          return unless mapper_class

          # this name is intentional and needs to be this for the validations
          @json_body = mapper_class.map_data
          return if @json_body.blank?

          # build_auth_headers
          @poa_auto_establish_validation_errors = validate_form_2122_and_2122a_submission_values(
            user_profile: nil, veteran_participant_id: @veteran.participant_id, poa_code: @data[:poa_code],
            base: 'serviceOrganization'
          )

          # validate values
          # validate JSON
          # Save in DB
          # send to sidekiq job
        end

        private

        def form_attributes
          @json_body&.dig('data', 'attributes') || {}
        end

        def build_auth_headers(_data)
          {
            'va_eauth_csid' => 'DSLogon',
            'va_eauth_authenticationmethod' => 'DSLogon',
            'va_eauth_pnidtype' => 'SSN',
            'va_eauth_assurancelevel' => '3',
            'va_eauth_firstName' => 'Jesus',
            'va_eauth_lastName' => 'Barrett',
            'va_eauth_issueinstant' => '2025-03-20T14:32:06Z',
            'va_eauth_dodedipnid' => '1005392639',
            'va_eauth_birlsfilenumber' => '123456',
            'va_eauth_pid' => '600043193',
            'va_eauth_pnid' => '796127587',
            'va_eauth_birthdate' => '1947-06-29T00:00:00+00:00',
            'va_eauth_authorization' => authorization_object,
            'va_eauth_authenticationauthority' => 'eauth',
            # "va_eauth_service_transaction_id"=>"vagov-16572083-2763-4b7d-a45f-71ac2835fd00",
            'va_notify_recipient_identifier' => '1012830305V427401'
          }
        end

        def authorization_object
          { authorizationResponse: { status: 'VETERAN', idType: 'SSN', id: '796127587', edi: '1005392639',
                                     firstName: 'Jesus', lastName: 'Barrett', birthDate: '1947-06-29T00:00:00+00:00',
                                     gender: 'MALE' } }
        end
      end
    end
  end
end
