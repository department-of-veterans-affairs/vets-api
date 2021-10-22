# frozen_string_literal: true

require 'evss/error_middleware'
require 'bgs/power_of_attorney_verifier'

module ClaimsApi
  module V1
    class ApplicationController < ::OpenidApplicationController
      include ClaimsApi::MPIVerification
      include ClaimsApi::HeaderValidation
      include ClaimsApi::JsonFormatValidation

      before_action :validate_json_format, if: -> { request.post? }
      before_action :validate_veteran_identifiers

      # fetch_audience: defines the audience used for oauth
      # NOTE: required for oauth through claims_api to function
      def fetch_aud
        Settings.oidc.isolated_audience.claims
      end

      protected

      def validate_veteran_identifiers(require_birls: false)
        return if !require_birls && target_veteran.participant_id.present?
        return if require_birls && target_veteran.participant_id.present? && target_veteran.birls_id.present?

        if require_birls && target_veteran.participant_id.present? && target_veteran.birls_id.blank?
          raise ::Common::Exceptions::UnprocessableEntity.new(detail: 'No birls_id while participant_id present')
        end

        if header_request? && !target_veteran.mpi_record?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail:
              'Submitting an original claim requires the Veteran to be authenticated with an identity-verified account'
          )
        end

        add_response = @current_user.mpi_add_person
        raise add_response.error unless add_response.ok?
      end

      def source_name
        user = header_request? ? @current_user : target_veteran
        "#{user.first_name} #{user.last_name}"
      end

      private

      def claims_service
        ClaimsApi::UnsynchronizedEVSSClaimService.new(target_veteran)
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
          veteran_from_headers(with_gender: with_gender)
        else
          ClaimsApi::Veteran.from_identity(identity: @current_user)
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
          loa: @current_user.loa
        )
        vet.mpi_record?
        vet.gender = header('X-VA-Gender') || vet.gender_mpi if with_gender
        vet.edipi = vet.edipi_mpi
        vet.participant_id = vet.participant_id_mpi

        vet
      end

      def authenticate_token
        super
      rescue => e
        raise e if e.message == 'Token Validation Error'

        log_message_to_sentry('Authentication Error in claims',
                              :warning,
                              body: e.message)
        message = 'User not a valid or authorized Veteran for this end point.'
        raise ::Common::Exceptions::Unauthorized.new(detail: message)
      end

      def set_tags_and_extra_context
        RequestStore.store['additional_request_attributes'] = { 'source' => 'claims_api' }
        Raven.tags_context(source: 'claims_api')
      end
    end
  end
end
