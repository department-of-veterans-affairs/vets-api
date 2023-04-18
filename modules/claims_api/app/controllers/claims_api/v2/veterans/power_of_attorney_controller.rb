# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'
require 'claims_api/v2/params_validation/power_of_attorney'

module ClaimsApi
  module V2
    module Veterans
      class PowerOfAttorneyController < ClaimsApi::V2::ApplicationController
        include ClaimsApi::PoaVerification
        before_action :verify_access!
        FORM_NUMBER = '2122'

        def show
          poa_code = BGS::PowerOfAttorneyVerifier.new(target_veteran).current_poa_code
          head(:no_content) && return if poa_code.blank?

          render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyBlueprint.render(
            representative(poa_code).merge({ code: poa_code })
          )
        end

        def appoint_organization
          validate_request!(ClaimsApi::V2::ParamsValidation::PowerOfAttorney)
          poa_code = parse_and_validate_poa_code
          unless poa_code_in_organization?(poa_code)
            raise ::Common::Exceptions::UnprocessableEntity.new(detail: 'POA Code must belong to an organization.')
          end

          submit_power_of_attorney(poa_code)
        end

        def appoint_individual
          validate_request!(ClaimsApi::V2::ParamsValidation::PowerOfAttorney)
          poa_code = parse_and_validate_poa_code
          if poa_code_in_organization?(poa_code)
            raise ::Common::Exceptions::UnprocessableEntity.new(detail: 'POA Code must belong to an individual.')
          end

          submit_power_of_attorney(poa_code)
        end

        def submit_power_of_attorney(poa_code)
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_using_identifier_and_source(header_md5:,
                                                                                          source_name:)
          unless power_of_attorney&.status&.in?(%w[submitted pending])
            attributes = {
              status: ClaimsApi::PowerOfAttorney::PENDING,
              auth_headers:,
              form_data: params,
              current_poa: current_poa_code,
              header_md5:
            }
            attributes.merge!({ source_data: }) unless token.client_credentials_token?

            # use .create! so we don't need to check if it's persisted just to call save (compare w/ v1)
            power_of_attorney = ClaimsApi::PowerOfAttorney.create!(attributes)
          end

          ClaimsApi::PoaUpdater.perform_async(power_of_attorney.id)

          ClaimsApi::VBMSUpdater.perform_async(power_of_attorney.id) if enable_vbms_access?

          # This builds the POA form *AND* uploads it to VBMS
          ClaimsApi::PoaFormBuilderJob.perform_async(power_of_attorney.id)

          render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyBlueprint.render(
            representative(poa_code).merge({ code: poa_code })
          )
        end

        private

        def representative(poa_code)
          organization = ::Veteran::Service::Organization.find_by(poa: poa_code)
          if organization.present?
            return {
              name: organization.name,
              phone_number: organization.phone,
              type: 'organization'
            }
          end

          individuals = ::Veteran::Service::Representative.where('? = ANY(poa_codes)', poa_code)
          raise 'Ambiguous representative results' if individuals.count > 1
          return {} if individuals.blank?

          individual = individuals.first
          {
            name: "#{individual.first_name} #{individual.last_name}",
            phone_number: individual.phone,
            type: 'individual'
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

        def parse_and_validate_poa_code
          poa_code = params.dig('serviceOrganization', 'poaCode')
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
