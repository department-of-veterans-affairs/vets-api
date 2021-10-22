# frozen_string_literal: true

require 'evss/error_middleware'
require 'bgs/power_of_attorney_verifier'

module ClaimsApi
  module V0
    class ApplicationController < ::ApplicationController
      include ClaimsApi::MPIVerification
      include ClaimsApi::HeaderValidation
      include ClaimsApi::JsonFormatValidation

      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate
      before_action :validate_json_format, if: -> { request.post? }
      before_action :verify_mpi

      protected

      def source_name
        request.headers['X-Consumer-Username']
      end

      private

      def claims_service
        ClaimsApi::UnsynchronizedEVSSClaimService.new(target_veteran)
      end

      def header(key)
        request.headers[key]
      end

      def header_request?
        true
      end

      def target_veteran(with_gender: false)
        headers_to_validate = %w[X-VA-SSN X-VA-First-Name X-VA-Last-Name X-VA-Birth-Date X-VA-LOA]
        validate_headers(headers_to_validate)
        check_loa_level
        check_source_user
        veteran_from_headers(with_gender: with_gender)
      end

      def check_source_user
        if !header('X-VA-User') && request.headers['X-Consumer-Username']
          request.headers['X-VA-User'] = request.headers['X-Consumer-Username']
        elsif !request.headers['X-Consumer-Username']
          log_message_to_sentry('Kong no longer sending X-Consumer-Username', :error,
                                body: request.body)
          validate_headers(['X-Consumer-Username'])
        end
      end

      def check_loa_level
        return if header('X-VA-LOA').try(:to_i) == 3

        raise ::Common::Exceptions::Unauthorized
      end

      def veteran_from_headers(with_gender: false)
        vet = ClaimsApi::Veteran.new(
          uuid: header('X-VA-SSN')&.gsub(/[^0-9]/, ''),
          ssn: header('X-VA-SSN')&.gsub(/[^0-9]/, ''),
          first_name: header('X-VA-First-Name'),
          last_name: header('X-VA-Last-Name'),
          va_profile: ClaimsApi::Veteran.build_profile(header('X-VA-Birth-Date')),
          last_signed_in: Time.now.utc
        )
        vet.loa = if @current_user
                    @current_user.loa
                  else
                    { current: header('X-VA-LOA').try(:to_i), highest: header('X-VA-LOA').try(:to_i) }
                  end
        vet.mpi_record?
        vet.gender = header('X-VA-Gender') || vet.gender_mpi if with_gender
        vet.edipi = vet.edipi_mpi
        vet.participant_id = vet.participant_id_mpi
        vet
      end

      def set_tags_and_extra_context
        RequestStore.store['additional_request_attributes'] = { 'source' => 'claims_api' }
        Raven.tags_context(source: 'claims_api')
      end
    end
  end
end
