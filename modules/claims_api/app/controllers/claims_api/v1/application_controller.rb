# frozen_string_literal: true

require 'evss/error_middleware'
require 'bgs/power_of_attorney_verifier'
require 'token_validation/v2/client'
require 'claims_api/claim_logger'
require 'mpi/errors/errors'

module ClaimsApi
  module V1
    class ApplicationController < ::ApplicationController
      include ClaimsApi::MPIVerification
      include ClaimsApi::HeaderValidation
      include ClaimsApi::JsonFormatValidation
      include ClaimsApi::TokenValidation
      include ClaimsApi::CcgTokenValidation
      include ClaimsApi::TargetVeteran
      skip_before_action :verify_authenticity_token
      skip_after_action :set_csrf_header
      before_action :authenticate, except: %i[schema] # rubocop:disable Rails/LexicallyScopedActionFilter
      before_action :validate_json_format, if: -> { request.post? }
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
          ClaimsApi::Logger.log('multiple_ids',
                                header_request: header_request?,
                                ptcpnt_ids: ids.size,
                                icn: target_veteran&.mpi_icn)

          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail:
              'Veteran has multiple active Participant IDs in Master Person Index (MPI). ' \
              'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
          )
        end

        return if !require_birls && target_veteran.participant_id.present?
        return if require_birls && target_veteran.participant_id.present? && target_veteran.birls_id.present?

        if require_birls && target_veteran.participant_id.present? && target_veteran.birls_id.blank?
          raise ::Common::Exceptions::UnprocessableEntity.new(detail:
            "Unable to locate Veteran's BIRLS ID in Master Person Index (MPI). " \
            'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end

        if header_request? && !target_veteran.mpi_record?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail:
              'Unable to locate Veteran in Master Person Index (MPI). ' \
              'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
          )
        end

        ClaimsApi::Logger.log('validate_identifiers',
                              rid: request.request_id,
                              require_birls:,
                              header_request: header_request?,
                              ptcpnt_id: target_veteran.participant_id.present?,
                              icn: target_veteran&.mpi_icn,
                              birls_id: target_veteran.birls_id.present?)

        if target_veteran.icn.blank?
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
          raise ::Common::Exceptions::UnprocessableEntity.new(detail:
            "Unable to locate Veteran's Participant ID in Master Person Index (MPI). " \
            'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end

        ClaimsApi::Logger.log('validate_identifiers',
                              rid: request.request_id, mpi_res_ok: mpi_add_response.ok?,
                              ptcpnt_id: target_veteran.participant_id.present?,
                              birls_id: target_veteran.birls_id.present?,
                              icn: target_veteran&.mpi_icn)
      rescue MPI::Errors::ArgumentError
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
          local_bgs_service
        else
          claims_service
        end
      end

      def claims_service
        ClaimsApi::UnsynchronizedEVSSClaimService.new(target_veteran)
      end

      def local_bgs_service
        @local_bgs_service ||= ClaimsApi::LocalBGS.new(
          external_uid: target_veteran.participant_id,
          external_key: target_veteran.participant_id
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
        (request.headers.to_h.keys & headers_to_check).length.positive?
      end

      def target_veteran(with_gender: false)
        if header_request?
          headers_to_validate = %w[X-VA-SSN X-VA-First-Name X-VA-Last-Name X-VA-Birth-Date]
          validate_headers(headers_to_validate)
          validate_ccg_token! if @is_valid_ccg_flow
          veteran_from_headers(with_gender:)
        else
          build_target_veteran(veteran_id: @current_user.icn, loa: { current: 3, highest: 3 })
        end
      end

      def veteran_from_headers(with_gender: false)
        vet = ClaimsApi::Veteran.new(
          uuid: header('X-VA-SSN')&.gsub(/[^0-9]/, ''),
          ssn: header('X-VA-SSN')&.gsub(/[^0-9]/, ''),
          first_name: header('X-VA-First-Name'),
          last_name: header('X-VA-Last-Name'),
          va_profile: ClaimsApi::Veteran.build_profile(header('X-VA-Birth-Date')),
          last_signed_in: Time.now.utc,
          loa: @is_valid_ccg_flow ? { current: 3, highest: 3 } : @current_user.loa
        )
        vet.mpi_record?
        vet.gender = header('X-VA-Gender') || vet.gender_mpi if with_gender
        vet.edipi = vet.edipi_mpi
        vet.participant_id = vet.participant_id_mpi
        vet.icn = vet&.mpi_icn
        vet
      end

      def set_tags_and_extra_context
        RequestStore.store['additional_request_attributes'] = { 'source' => 'claims_api' }
        Raven.tags_context(source: 'claims_api')
      end

      def edipi_check
        if target_veteran.edipi.blank?
          raise ::Common::Exceptions::UnprocessableEntity.new(detail:
            "Unable to locate Veteran's EDIPI in Master Person Index (MPI). " \
            'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end
      end
    end
  end
end
