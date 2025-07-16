# frozen_string_literal: true

<<<<<<< HEAD
require_relative 'organization_data_mapper'
require 'json_schema/json_api_missing_attribute'
require 'claims_api/form_schemas'
require 'json'
=======
require_relative 'individual_data_mapper'
require_relative 'organization_data_mapper'
>>>>>>> 1255e92ce7 (WIP)

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataMapper
      class PoaAutoEstablishmentDataMapper
        include ClaimsApi::V2::PowerOfAttorneyValidation
<<<<<<< HEAD
        include ClaimsApi::V2::JsonFormatValidation

        LOG_TAG = 'poa_auto_establishment_data_mapper'
        DATA_MAPPERS = {
=======

        DATA_MAPPERS = {
          '2122a' => ClaimsApi::PowerOfAttorneyRequestService::DataMapper::IndividualDataMapper,
>>>>>>> 1255e92ce7 (WIP)
          '2122' => ClaimsApi::PowerOfAttorneyRequestService::DataMapper::OrganizationDataMapper
        }.freeze

        def initialize(type:, data:, veteran:)
          @type = type
          @data = data
          @veteran = veteran
        end

        def map_data
<<<<<<< HEAD
          ClaimsApi::Logger.log(
            LOG_TAG, message: 'Starting poa auto establish data mapping.'
          )

          mapper_class = DATA_MAPPERS[@type].new(data: @data)
          return [] unless mapper_class

          @json_form_data = deep_compact(mapper_class.map_data)
          return [] if @json_form_data.blank?

          validate_data

          @json_form_data
        end

        # validate here instead of returning to the controller since we know the form type
        # and have it available here
        def validate_data
          # custom validations, must come first
          @poa_auto_establish_validation_errors = validate_form_2122_and_2122a_submission_values(
            user_profile: nil, veteran_participant_id: @veteran.participant_id, poa_code: @data[:poa_code],
            base: form_type_name
          )
          # JSON validations, all errors, including errors from the custom validations
          # will be raised here if JSON errors exist
          validate_json_schema(@type.upcase)
          # otherwise we raise the errors from the custom validations if no JSON
          # errors exist
          if @claims_api_forms_validation_errors
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::JsonFormValidationError,
                  @claims_api_forms_validation_errors
          end
=======
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
>>>>>>> 1255e92ce7 (WIP)
        end

        private

<<<<<<< HEAD
        def form_type_name
          @type == '2122' ? 'serviceOrganization' : 'representative'
        end

        def validate_json_schema(form_number = self.class::FORM_NUMBER)
          validator = ClaimsApi::FormSchemas.new(schema_version: 'v2')
          validator.validate!(form_number, form_attributes)
        end

        def form_attributes
          @json_form_data&.dig('data', 'attributes') || {}
        end

        def deep_compact(obj)
          case obj
          when Hash
            obj.each_with_object({}) do |(k, v), result|
              nested = deep_compact(v)
              result[k] = nested unless nested.nil? || nested == {}
            end
          when Array
            array = obj.map { |v| deep_compact(v) }.reject { |v| v.nil? || v == {} }
            array.empty? ? nil : array
          else
            obj.nil? ? nil : obj
          end
=======
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
>>>>>>> 1255e92ce7 (WIP)
        end
      end
    end
  end
end
