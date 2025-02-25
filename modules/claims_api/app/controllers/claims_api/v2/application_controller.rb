# frozen_string_literal: true

require 'bd/bd'
require 'evss/auth_headers'
require 'bgs_service/local_bgs'
require 'claims_api/claim_logger'
require 'claims_api/form_schemas'
require 'token_validation/v2/client'
require 'claims_api/error/error_handler'
require 'claims_api/v2/benefits_documents/service'
require 'evss/disability_compensation_auth_headers'
require 'bgs_service/e_benefits_bnft_claim_status_web_service'

module ClaimsApi
  module V2
    class ApplicationController < ::ApplicationController
      include ClaimsApi::Error::ErrorHandler
      include ClaimsApi::TokenValidation
      include ClaimsApi::CcgTokenValidation
      include ClaimsApi::TargetVeteran
      service_tag 'lighthouse-claims'
      skip_before_action :verify_authenticity_token
      skip_after_action :set_csrf_header
      before_action :authenticate, except: %i[schema]
      before_action { permit_scopes %w[system/claim.read] if request.get? }
      before_action do
        next if action_name == 'generate_pdf'

        permit_scopes %w[system/claim.write] if request.post? || request.put?
      end

      def schema
        render json: { data: [ClaimsApi::FormSchemas.new(schema_version: 'v2').schemas[self.class::FORM_NUMBER]] }
      end

      protected

      def auth_headers
        evss_headers = EVSS::DisabilityCompensationAuthHeaders
                       .new(target_veteran)
                       .add_headers(
                         EVSS::AuthHeaders.new(target_veteran).to_h
                       )
        evss_headers['va_eauth_pnid'] = target_veteran.mpi.profile.ssn

        if request.headers['Mock-Override'] &&
           Settings.claims_api.disability_claims_mock_override
          evss_headers['Mock-Override'] = request.headers['Mock-Override']
          claims_v2_logging('mock_override', message: 'ClaimsApi: Mock Override Engaged in app_controller_v2')
        end

        evss_headers
      end

      #
      # For validating the incoming request body
      # @param validator_class [any] Class implementing ActiveModel::Validations
      #
      def validate_request!(validator_class)
        data = validator_class.as_json.split('::')[-1] == 'PowerOfAttorney' ? form_attributes : params
        validator = validator_class.validator(data)
        return if validator.valid?

        raise ::Common::Exceptions::ValidationErrorsBadRequest, validator
      end

      private

      def authenticate
        verify_access!

        return if @is_valid_ccg_flow

        raise ::Common::Exceptions::Forbidden
      end

      def benefits_doc_api
        ClaimsApi::BD.new
      end

      def bgs_service
        BGS::Services.new(external_uid: target_veteran.participant_id,
                          external_key: target_veteran.participant_id)
      end

      def local_bgs_service
        @local_bgs_service ||= ClaimsApi::LocalBGS.new(
          external_uid: target_veteran.participant_id,
          external_key: target_veteran.participant_id
        )
      end

      def bgs_claim_status_service
        @e_benefits_bnt_claim_status_service ||= ClaimsApi::EbenefitsBnftClaimStatusWebService.new(
          external_uid: target_veteran.participant_id,
          external_key: target_veteran.participant_id
        )
      end

      # Creates a token OR gets existing one
      def get_benefits_documents_auth_token
        @auth_token ||= ClaimsApi::V2::BenefitsDocuments::Service.new.get_auth_token
      end

      def file_number_check(icn: params[:veteranId])
        if icn.present?
          sponsor = build_target_veteran(veteran_id: icn, loa: { current: 3, highest: 3 })
          @file_number = sponsor&.birls_id || sponsor&.mpi&.birls_id
        elsif target_veteran&.mpi&.birls_id.present?
          @file_number = target_veteran&.birls_id || target_veteran&.mpi&.birls_id
        else
          claims_v2_logging('missing_file_number',
                            message: 'missing_file_number on request in v2 application controller.')

          raise ::Common::Exceptions::UnprocessableEntity.new(detail:
          "Unable to locate Veteran's 'File Number' in Master Person Index (MPI). " \
          'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end
        if @file_number.nil?
          claims_v2_logging('missing_file_number',
                            message: 'missing_file_number on request in v2 application controller.')
          raise ::Common::Exceptions::UnprocessableEntity.new(detail:
          "Unable to locate Veteran's 'File Number' in Master Person Index (MPI). " \
          'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end
      end

      def edipi_check
        if target_veteran.edipi.blank?
          claims_v2_logging('unable_to_locate_edipi',
                            message: 'unable_to_locate_edipi on request in v2 application controller.')

          raise ::Common::Exceptions::UnprocessableEntity.new(detail:
            "Unable to locate Veteran's EDIPI in Master Person Index (MPI). " \
            'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end
      end

      def claims_v2_logging(tag = 'traceability', level: :info, message: nil)
        ClaimsApi::Logger.log(tag,
                              cid: token&.payload&.[]('cid'),
                              current_user: current_user&.uuid,
                              message:,
                              api_version: 'V2',
                              level:)
      end
    end
  end
end
