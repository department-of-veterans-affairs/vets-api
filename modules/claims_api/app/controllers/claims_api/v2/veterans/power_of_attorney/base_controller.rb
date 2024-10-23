# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'
require 'claims_api/v2/params_validation/power_of_attorney'
require 'claims_api/v2/error/lighthouse_error_handler'
require 'claims_api/v2/json_format_validation'
require 'claims_api/v2/power_of_attorney_validation'

module ClaimsApi
  module V2
    module Veterans
      class PowerOfAttorney::BaseController < ClaimsApi::V2::Veterans::Base
        include ClaimsApi::V2::PowerOfAttorneyValidation
        include ClaimsApi::PoaVerification
        include ClaimsApi::V2::Error::LighthouseErrorHandler
        include ClaimsApi::V2::JsonFormatValidation
        FORM_NUMBER_INDIVIDUAL = '2122A'
        VA_NOTIFY_KEY = 'va_notify_recipient_identifier'

        def show
          poa_code = BGS::PowerOfAttorneyVerifier.new(target_veteran).current_poa_code
          data = poa_code.blank? ? {} : representative(poa_code).merge({ code: poa_code })
          if poa_code.blank?
            render json: { data: }
          else
            render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyBlueprint.render(data, root: :data)
          end
        end

        def status
          poa = ClaimsApi::PowerOfAttorney.find_by(id: params[:id])
          unless poa
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
              detail: "Could not find Power of Attorney with id: #{params[:id]}"
            )
          end

          serialized_response = ClaimsApi::PowerOfAttorneySerializer.new(poa).serializable_hash
          serialized_response[:data][:type] = serialized_response[:data][:type].to_s.camelize(:lower)
          render json: serialized_response.deep_transform_keys! { |key| key.to_s.camelize(:lower).to_sym }
        end

        private

        def shared_form_validation(form_number)
          # validate target veteran exists
          target_veteran

          base = form_number == '2122' ? 'serviceOrganization' : 'representative'
          poa_code = form_attributes.dig(base, 'poaCode')

          @claims_api_forms_validation_errors = validate_form_2122_and_2122a_submission_values(
            user_profile:, veteran_participant_id: target_veteran.participant_id, poa_code:, base:
          )

          validate_json_schema(form_number.upcase)
          @rep_id = validate_registration_number!(base, poa_code)

          add_claimant_data_to_form if user_profile

          if @claims_api_forms_validation_errors
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::JsonFormValidationError,
                  @claims_api_forms_validation_errors
          end
        end

        def feature_enabled_and_claimant_present?
          Flipper.enabled?(:lighthouse_claims_api_poa_dependent_claimants) && form_attributes['claimant'].present?
        end

        def dependent_claimant_poa_assignment_service(poa_code:)
          # Assign the veteranʼs file number
          file_number_check

          claimant = user_profile.profile

          ClaimsApi::DependentClaimantPoaAssignmentService.new(
            poa_code:,
            veteran_participant_id: target_veteran.participant_id,
            dependent_participant_id: claimant.participant_id,
            veteran_file_number: @file_number,
            allow_poa_access: form_attributes[:recordConsent].present? ? 'Y' : nil,
            allow_poa_cadd: form_attributes[:consentAddressChange].present? ? 'Y' : nil,
            claimant_ssn: claimant.ssn
          )
        end

        def validate_registration_number!(base, poa_code)
          rn = form_attributes.dig(base, 'registrationNumber')
          rep = ::Veteran::Service::Representative.where('? = ANY(poa_codes) AND representative_id = ?',
                                                         poa_code,
                                                         rn).order(created_at: :desc).first
          if rep.nil?
            raise ::Common::Exceptions::ResourceNotFound.new(
              detail: "Could not find an Accredited Representative with registration number: #{rn} " \
                      "and poa code: #{poa_code}"
            )
          end
          rep.id
        end

        def attributes
          {
            status: ClaimsApi::PowerOfAttorney::PENDING,
            auth_headers: auth_headers.merge!({ VA_NOTIFY_KEY => icn_for_vanotify }),
            form_data: form_attributes,
            current_poa: current_poa_code,
            header_md5:
          }
        end

        def submit_power_of_attorney(poa_code, form_number)
          attributes.merge!({ source_data: }) unless token.client_credentials_token?

          power_of_attorney = ClaimsApi::PowerOfAttorney.create!(attributes)

          unless Settings.claims_api&.poa_v2&.disable_jobs
            if feature_enabled_and_claimant_present?
              ClaimsApi::PoaAssignDependentClaimantJob.perform_async(
                dependent_claimant_poa_assignment_service(poa_code:)
              )
            else
              ClaimsApi::V2::PoaFormBuilderJob.perform_async(power_of_attorney.id, form_number, @rep_id)
            end
          end

          render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyBlueprint.render(
            representative(poa_code).merge({ id: power_of_attorney.id, code: poa_code }),
            root: :data
          ), status: :accepted, location: url_for(
            controller: 'power_of_attorney/base', action: 'show', id: power_of_attorney.id
          )
        end

        def validation_success(form_number)
          {
            data: {
              type: "form/#{form_number}/validation",
              attributes: {
                status: 'valid'
              }
            }
          }
        end

        def current_poa_code
          current_poa.try(:code)
        end

        def current_poa
          @current_poa ||= BGS::PowerOfAttorneyVerifier.new(target_veteran).current_poa
        end

        def representative(poa_code)
          organization = ::Veteran::Service::Organization.find_by(poa: poa_code)
          return format_organization(organization) if organization.present?

          individuals = ::Veteran::Service::Representative.where('? = ANY(poa_codes)',
                                                                 poa_code).order(created_at: :desc)
          if individuals.blank?
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
              detail: "Could not retrieve Power of Attorney with code: #{poa_code}"
            )
          end

          if individuals.pluck(:representative_id).uniq.count > 1
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity.new(
              detail: "Could not retrieve Power of Attorney due to multiple representatives with code: #{poa_code}"
            )
          end

          format_representative(individuals.first)
        end

        def format_representative(representative)
          {
            name: "#{representative.first_name} #{representative.last_name}",
            phone_number: representative.phone,
            type: 'individual'
          }
        end

        def format_organization(organization)
          {
            name: organization.name,
            phone_number: organization.phone,
            type: 'organization'
          }
        end

        def header_md5
          @header_md5 ||= Digest::MD5.hexdigest(auth_headers.except('va_eauth_authenticationauthority',
                                                                    'va_eauth_service_transaction_id',
                                                                    'va_eauth_issueinstant',
                                                                    'Authorization').to_json)
        end

        def get_poa_code(form_number)
          rep_or_org = form_number.upcase == FORM_NUMBER_INDIVIDUAL ? 'representative' : 'serviceOrganization'
          form_attributes&.dig(rep_or_org, 'poaCode')
        end

        def source_data
          {
            name: source_name,
            icn: nullable_icn,
            email: current_user.email
          }
        end

        def source_name
          return request.headers['X-Consumer-Username'] if token.client_credentials_token?

          "#{current_user.first_name} #{current_user.last_name}"
        end

        def nullable_icn
          current_user.icn
        rescue => e
          log_message_to_sentry('Failed to retrieve icn for consumer',
                                :warning,
                                body: e.message)

          nil
        end

        def user_profile
          @user_profile ||= fetch_claimant
        end

        def icn_for_vanotify
          params[:veteranId]
        end

        def fetch_claimant
          claimant_icn = form_attributes.dig('claimant', 'claimantId')
          if claimant_icn.present?
            mpi_profile = mpi_service.find_profile_by_identifier(identifier: claimant_icn,
                                                                 identifier_type: MPI::Constants::ICN)
          end
        rescue ArgumentError
          mpi_profile
        end

        def add_claimant_data_to_form
          if user_profile&.status == :ok
            first_name = user_profile.profile.given_names.first
            last_name = user_profile.profile.family_name
            form_attributes['claimant'].merge!(firstName: first_name, lastName: last_name)
          end
        end
      end
    end
  end
end
