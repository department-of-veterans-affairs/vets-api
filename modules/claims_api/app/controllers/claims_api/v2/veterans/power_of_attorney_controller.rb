# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'
require 'claims_api/v2/params_validation/power_of_attorney'
require 'claims_api/v2/error/lighthouse_error_handler'
require 'claims_api/v2/json_format_validation'

module ClaimsApi
  module V2
    module Veterans
      class PowerOfAttorneyController < ClaimsApi::V2::Veterans::Base
        include ClaimsApi::PoaVerification
        include ClaimsApi::V2::Error::LighthouseErrorHandler
        include ClaimsApi::V2::JsonFormatValidation
        FORM_NUMBER = '2122'

        def show
          poa_code = BGS::PowerOfAttorneyVerifier.new(target_veteran).current_poa_code
          data = poa_code.blank? ? {} : representative(poa_code).merge({ code: poa_code })
          if poa_code.blank?
            render json: { data: }
          else
            render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyBlueprint.render(data, root: :data)
          end
        end

        def submit2122
          poa_code = parse_and_validate_poa_code('2122')
          unless poa_code_in_organization?(poa_code)
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity.new(
              detail: 'POA Code must belong to an organization.'
            )
          end

          submit_power_of_attorney(poa_code, '2122')
        end

        def submit2122a
          shared_form_validation('2122A')
          poa_code = get_poa_code('2122A')
          validate_individual_poa_code!(poa_code)

          submit_power_of_attorney(poa_code, '2122A')
        end

        def validate2122
          target_veteran
          validate_json_schema

          poa_code = form_attributes.dig('serviceOrganization', 'poaCode')
          validate_org_poa_code!(poa_code)

          render json: validation_success('21-22')
        end

        def validate2122a
          shared_form_validation('2122A')
          poa_code = get_poa_code('2122A')
          validate_individual_poa_code!(poa_code)

          render json: validation_success('21-22a')
        end

        private

        def shared_form_validation(form_number)
          target_veteran
          validate_json_schema(form_number.upcase)
        end

        def submit_power_of_attorney(poa_code, form_number)
          attributes = {
            status: ClaimsApi::PowerOfAttorney::PENDING,
            auth_headers:,
            form_data: form_attributes,
            current_poa: current_poa_code,
            header_md5:
          }
          attributes.merge!({ source_data: }) unless token.client_credentials_token?

          power_of_attorney = ClaimsApi::PowerOfAttorney.create!(attributes)

          ClaimsApi::PoaFormBuilderJob.perform_async(power_of_attorney.id, form_number)

          render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyBlueprint.render(
            representative(poa_code).merge({ id: power_of_attorney.id, code: poa_code }),
            root: :data
          ), status: :accepted, location: url_for(
            controller: 'power_of_attorney', action: 'show', id: power_of_attorney.id
          )
        end

        def representative(poa_code)
          organization = ::Veteran::Service::Organization.find_by(poa: poa_code)
          return format_organization(organization) if organization.present?

          individuals = ::Veteran::Service::Representative.where('? = ANY(poa_codes)',
                                                                 poa_code).order(created_at: :desc)
          return {} if individuals.blank?

          if individuals.pluck(:representative_id).uniq.count > 1
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity.new(
              detail: "Could not retrieve Power of Attorney due to multiple representatives with code: #{poa_code}"
            )
          end

          format_representative(individuals.first)
        end

        def format_organization(organization)
          {
            name: organization.name,
            phone_number: organization.phone,
            type: 'organization'
          }
        end

        def format_representative(representative)
          {
            name: "#{representative.first_name} #{representative.last_name}",
            phone_number: representative.phone,
            type: 'individual'
          }
        end

        def validate_individual_poa_code!(poa_code)
          return if ::Veteran::Service::Representative.where('? = ANY(poa_codes)', poa_code).any?

          raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
            detail: "Could not find an Accredited Representative with code: #{poa_code}"
          )
        end

        def validate_org_poa_code!(poa_code)
          return if ::Veteran::Service::Organization.exists?(poa: poa_code)

          raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
            detail: "Could not find an Organization with code: #{poa_code}"
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

        def enable_vbms_access?
          params[:recordConsent] && params[:consentLimits].blank?
        end

        def current_poa_code
          current_poa.try(:code)
        end

        def current_poa
          @current_poa ||= BGS::PowerOfAttorneyVerifier.new(target_veteran).current_poa
        end

        def header_md5
          @header_md5 ||= Digest::MD5.hexdigest(auth_headers.except('va_eauth_authenticationauthority',
                                                                    'va_eauth_service_transaction_id',
                                                                    'va_eauth_issueinstant',
                                                                    'Authorization').to_json)
        end

        def get_poa_code(form_number)
          rep_or_org = form_number.upcase == '2122A' ? 'representative' : 'serviceOrganization'
          form_attributes&.dig(rep_or_org, 'poaCode')
        end

        def parse_and_validate_poa_code(form_number)
          poa_code = get_poa_code(form_number)
          validate_poa_code!(poa_code)
          validate_poa_code_for_current_user!(poa_code) if user_is_representative?

          poa_code
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
      end
    end
  end
end
