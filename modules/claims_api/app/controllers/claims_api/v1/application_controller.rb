# frozen_string_literal: true

require 'evss/error_middleware'
require 'bgs/power_of_attorney_verifier'
require 'token_validation/v2/client'
require 'claims_api/claim_logger'
require 'mpi/errors/errors'
require 'bgs_service/e_benefits_bnft_claim_status_web_service'
require 'bgs_service/intent_to_file_web_service'

module ClaimsApi
  module V1
    class ApplicationController < ::ApplicationController
      include ClaimsApi::MPIVerification
      include ClaimsApi::HeaderValidation
      include ClaimsApi::JsonFormatValidation
      include ClaimsApi::TokenValidation
      include ClaimsApi::CcgTokenValidation
      include ClaimsApi::TargetVeteran
      service_tag 'lighthouse-claims'
      skip_before_action :verify_authenticity_token
      skip_after_action :set_csrf_header
      before_action :authenticate
      before_action :validate_json_format, if: -> { request.post? }
      before_action :validate_header_values_format, if: -> { header_request? }
      before_action :validate_veteran_identifiers

      # fetch_audience: defines the audience used for oauth
      # NOTE: required for oauth through claims_api to function
      def fetch_aud
        Settings.oidc.isolated_audience.claims
      end

      protected

      def validate_veteran_identifiers(require_birls: false) # rubocop:disable Metrics/MethodLength
        ids = target_veteran&.mpi&.participant_ids || []

        if ids.size > 1
          claims_v1_logging('multiple_ids', message: "multiple_ids: #{ids.size},
                                            header_request: #{header_request?}")

          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail:
              'Veteran has multiple active Participant IDs in Master Person Index (MPI). ' \
              'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
          )
        end

        return if !require_birls && target_veteran.participant_id.present?
        return if require_birls && target_veteran.participant_id.present? && target_veteran.birls_id.present?

        if require_birls && target_veteran.participant_id.present? && target_veteran.birls_id.blank?
          claims_v1_logging('unable_to_locate_birls',
                            message: 'unable_to_locate_birls on request in v1 application controller.')

          raise ::Common::Exceptions::UnprocessableEntity.new(detail:
            "Unable to locate Veteran's BIRLS ID in Master Person Index (MPI). " \
            'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end

        if header_request? && !target_veteran.mpi_record?
          claims_v1_logging('unable_to_locate_mpi_record',
                            message: 'unable_to_locate_mpi_record on request in v1 application controller.')

          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail:
              'Unable to locate Veteran in Master Person Index (MPI). ' \
              'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
          )
        end

        claims_v1_logging('validate_identifiers', message: "multiple_ids: #{ids.size}, " \
                                                           "header_request: #{header_request?}, " \
                                                           "require_birls: #{require_birls}, " \
                                                           "birls_id: #{target_veteran&.birls_id.present?}, " \
                                                           "rid: #{request&.request_id}, " \
                                                           "ptcpnt_id: #{target_veteran&.participant_id.present?}")
        if target_veteran.icn.blank?
          claims_v1_logging('unable_to_locate_icn',
                            message: 'unable_to_locate_icn on request in v1 application controller.')

          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail:
              'Veteran missing Integration Control Number (ICN). ' \
              'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
          )
        end
        mpi_add_response = target_veteran.mpi.add_person_proxy

        raise mpi_add_response.error unless mpi_add_response.ok?

        ids = target_veteran&.mpi&.participant_ids
        if ids.nil? || ids.size.zero?
          claims_v1_logging('unable_to_locate_participant_id',
                            message: 'unable_to_locate_participant_id on request in v1 application controller.')

          raise ::Common::Exceptions::UnprocessableEntity.new(detail:
            "Unable to locate Veteran's Participant ID in Master Person Index (MPI). " \
            'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end

        claims_v1_logging('validate_identifiers', message: "multiple_ids: #{ids.size}, " \
                                                           "header_request: #{header_request?}, " \
                                                           "birls_id: #{target_veteran&.birls_id.present?}, " \
                                                           "rid: #{request&.request_id}, " \
                                                           "mpi_res_ok: #{mpi_add_response&.ok?}, " \
                                                           "ptcpnt_id: #{target_veteran&.participant_id.present?}")
      rescue MPI::Errors::ArgumentError
        claims_v1_logging('unable_to_locate_participant_id',
                          message: 'unable_to_locate_participant_id on request in v1 application controller.')

        raise ::Common::Exceptions::UnprocessableEntity.new(detail:
          "Unable to locate Veteran's Participant ID in Master Person Index (MPI). " \
          'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
      rescue ArgumentError
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: 'Required values are missing. Please double check the accuracy of any request header values.'
        )
      end

      def source_name
        if header_request?
          return request.headers['X-Consumer-Username'] if token.client_credentials_token?

          "#{@current_user.first_name} #{@current_user.last_name}"
        else
          "#{target_veteran.first_name} #{target_veteran.last_name}"
        end
      end

      private

      def authenticate
        verify_access!
      end

      def claims_status_service
        edipi_check

        if Flipper.enabled? :claims_status_v1_bgs_enabled
          bgs_claim_status_service
        else
          claims_service
        end
      end

      def bgs_service
        bgs = BGS::Services.new(
          external_uid: target_veteran.participant_id,
          external_key: target_veteran.participant_id
        )
        ClaimsApi::Logger.log('poa', detail: 'bgs-ext service built')
        bgs
      end

      def local_bgs_service
        external_key = target_veteran.participant_id.to_s
        @local_bgs_service ||= ClaimsApi::LocalBGS.new(
          external_uid: external_key,
          external_key:
        )
      end

      def claims_service
        ClaimsApi::UnsynchronizedEVSSClaimService.new(target_veteran)
      end

      def bgs_claim_status_service
        @bgs_claim_status_service ||= ClaimsApi::EbenefitsBnftClaimStatusWebService.new(
          external_uid: target_veteran.participant_id,
          external_key: target_veteran.participant_id
        )
      end

      def bgs_itf_service
        external_key = target_veteran.participant_id.to_s
        @bgs_itf_service ||= ClaimsApi::IntentToFileWebService.new(
          external_uid: external_key,
          external_key:
        )
      end

      def header(key)
        request.headers[key]
      end

      def header_request?
        headers_to_check = %w[HTTP_X_VA_SSN
                              HTTP_X_VA_BIRTH_DATE
                              HTTP_X_VA_FIRST_NAME
                              HTTP_X_VA_LAST_NAME]
        request.headers.to_h.keys.intersect?(headers_to_check)
      end

      def target_veteran(with_gender: false)
        @target ||= if header_request?
                      headers_to_validate = %w[X-VA-SSN X-VA-First-Name X-VA-Last-Name X-VA-Birth-Date]
                      validate_headers(headers_to_validate)
                      validate_ccg_token! if @is_valid_ccg_flow
                      veteran_from_headers(with_gender:)
                    else
                      build_target_veteran(veteran_id: @current_user.icn, loa: { current: 3, highest: 3 })
                    end
      end

      def veteran_from_headers(with_gender: false) # rubocop:disable Metrics/MethodLength
        vet = ClaimsApi::Veteran.new(
          uuid: header('X-VA-SSN')&.gsub(/[^0-9]/, ''),
          ssn: header('X-VA-SSN')&.gsub(/[^0-9]/, ''),
          first_name: header('X-VA-First-Name'),
          last_name: header('X-VA-Last-Name'),
          va_profile: ClaimsApi::Veteran.build_profile(header('X-VA-Birth-Date')),
          last_signed_in: Time.now.utc,
          loa: @is_valid_ccg_flow ? { current: 3, highest: 3 } : @current_user.loa
        )
        # Fail fast if mpi_record can't be found
        unless vet.mpi_record?
          # Intentionally NOT calling the claims_v1_logging method here
          # to avoid the infinite loop that calling target_veteran there can create
          # While we technically can just pass in icn: nil when doing that I felt it was best
          # to avoid it entirely
          ClaimsApi::Logger.log('unable_to_locate_mpi_record',
                                message: 'unable_to_locate_mpi_record on request in v1 application controller.',
                                api_version: 'V1',
                                level: :info)

          raise ::Common::Exceptions::UnprocessableEntity.new(detail:
            'Unable to retrieve a record from Master Person Index (MPI). ' \
            'Please try again later.')
        end
        vet.gender = header('X-VA-Gender') || vet.gender_mpi if with_gender
        vet.edipi = vet.edipi_mpi
        vet.participant_id = vet.participant_id_mpi
        vet.icn = vet&.mpi_icn
        # This will cache using the ICN as the KEY in Redis now if it is present
        vet.recache_mpi_data
        vet
      end

      # This is still called by the ApplicationController even though sentry use has been deprecated
      def set_sentry_tags_and_extra_context
        RequestStore.store['additional_request_attributes'] = { 'source' => 'claims_api' }
      end

      def edipi_check
        if target_veteran.edipi.blank?
          claims_v1_logging('unable_to_locate_edipi',
                            message: 'unable_to_locate_edipi on request in v1 application controller.')

          raise ::Common::Exceptions::UnprocessableEntity.new(detail:
            "Unable to locate Veteran's EDIPI in Master Person Index (MPI). " \
            'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end
      end

      def validate_header_values_format
        errors = []
        errors << 'X-VA-Birth-Date' if header('X-VA-Birth-Date').blank?
        errors << 'X-VA-First-Name' if header('X-VA-First-Name').blank?
        errors << 'X-VA-Last-Name' if header('X-VA-Last-Name').blank?

        if errors.present?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: "The following values are invalid: #{errors.join(', ')}"
          )
        end
      end

      def claims_v1_logging(tag = 'traceability', level: :info, message: nil, icn: target_veteran&.mpi&.icn)
        ClaimsApi::Logger.log(tag,
                              icn:,
                              cid: token&.payload&.[]('cid'),
                              current_user: @current_user&.uuid,
                              message:,
                              api_version: 'V1',
                              level:)
      end
    end
  end
end
