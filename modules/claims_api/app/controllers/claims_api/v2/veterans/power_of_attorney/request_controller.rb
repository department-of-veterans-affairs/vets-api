# frozen_string_literal: true

require 'claims_api/v2/error/lighthouse_error_handler'
require 'claims_api/v2/json_format_validation'

module ClaimsApi
  module V2
    module Veterans
      class PowerOfAttorney::RequestController < ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController
        FORM_NUMBER = 'POA_REQUEST'

        def request_representative
          target_veteran
          @claims_api_forms_validation_errors = validate_form_2122_and_2122a_submission_values(user_profile)
          validate_json_schema(FORM_NUMBER)
          validate_accredited_representative(form_attributes.dig('poa', 'registrationNumber'),
                                             form_attributes.dig('poa', 'poaCode'))
          validate_accredited_organization(form_attributes.dig('poa', 'poaCode'))

          # if we get here, the only errors not raised are form value validation errors
          if @claims_api_forms_validation_errors
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::JsonDisabilityCompensationValidationError,
                  @claims_api_forms_validation_errors
          end

          bgs_form_attributes = build_bgs_attributes(form_attributes)

          # skip the BGS API calls in lower environments to prevent 3rd parties from creating data in external systems
          unless Flipper.enabled?(:lighthouse_claims_v2_poa_requests_skip_bgs)
            ClaimsApi::PowerOfAttorneyRequestService::Orchestrator.new(target_veteran.participant_id,
                                                                       bgs_form_attributes.deep_symbolize_keys,
                                                                       user_profile&.profile&.participant_id,
                                                                       :poa).submit_request
          end

          # return only the form information consumers provided
          render json: { data: { attributes: form_attributes } }, status: :created
        end

        private

        def validate_accredited_representative(registration_number, poa_code)
          @representative = ::Veteran::Service::Representative.where('? = ANY(poa_codes) AND representative_id = ?',
                                                                     poa_code,
                                                                     registration_number).order(created_at: :desc).first
          # there must be a representative to appoint. This representative can be an accredited attorney, claims agent,
          #   or representative.
          if @representative.nil?
            raise ::Common::Exceptions::ResourceNotFound.new(
              detail: "Could not find an Accredited Representative with registration number: #{registration_number} " \
                      "and poa code: #{poa_code}"
            )
          end
        end

        def validate_accredited_organization(poa_code)
          # organization is not required. An attorney or claims agent appointment request would not have an accredited
          #   organization to associate with.
          @organization = ::Veteran::Service::Organization.find_by(poa: poa_code)
        end

        def build_bgs_attributes(form_attributes)
          bgs_form_attributes = form_attributes.deep_merge(veteran_data)
          bgs_form_attributes.deep_merge!(claimant_data) if user_profile&.status == :ok
          bgs_form_attributes.deep_merge!(representative_data)
          bgs_form_attributes.deep_merge!(organization_data) if @organization

          bgs_form_attributes
        end

        def veteran_data
          {
            'veteran' => {
              'firstName' => target_veteran.first_name,
              'lastName' => target_veteran.last_name,
              'ssn' => target_veteran.ssn,
              'birthdate' => target_veteran.birth_date.to_time.iso8601,
              'va_file_number' => target_veteran.birls_id
            }
          }
        end

        def claimant_data
          {
            'claimant' => {
              'firstName' => user_profile.profile.given_names.first,
              'lastName' => user_profile.profile.family_name,
              'ssn' => user_profile.profile.ssn,
              'birthdate' => user_profile.profile.birth_date.to_time.iso8601,
              'va_file_number' => user_profile.profile.birls_id
            }
          }
        end

        def representative_data
          {
            'poa' => {
              'firstName' => @representative.first_name,
              'lastName' => @representative.last_name
            }
          }
        end

        def organization_data
          {
            'poa' => {
              'organizationName' => @organization.name
            }
          }
        end
      end
    end
  end
end
