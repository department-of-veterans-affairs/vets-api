# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'
require_relative 'response'
require_relative 'authentication_token_service'

module Vye
  module DGIB
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = 'api.vye.dgib'
      configuration Vye::DGIB::Configuration

      def initialize(user)
        @user = user
      end

      def camelize_keys_for_java_service(params)
        local_params = params[0] || params

        local_params.permit!.to_h.deep_transform_keys do |key|
          if key.include?('_')
            split_keys = key.split('_')
            split_keys.collect { |key_part| split_keys[0] == key_part ? key_part : key_part.capitalize }.join
          else
            key
          end
        end
      end

      def claimant_lookup(ssn)
        params = ActionController::Parameters.new({ ssn: })
        with_monitoring do
          headers = request_headers
          options = { timeout: 60 }
          raw_response = perform(:post, claimant_lookup_end_point, camelize_keys_for_java_service(params).to_json,
                                 headers, options)
          response = ClaimantLookupResponse.new(raw_response.status, raw_response)
          track_claimant_id_zero if response&.claimant_id&.zero?
          response
        end
      rescue => e
        log_error(e, __method__)
        raise e
      end

      def get_claimant_status(claimant_id)
        with_monitoring do
          headers = request_headers
          options = { timeout: 60 }
          raw_response = perform(:get, claimant_status_end_point(claimant_id), {}, headers, options)
          ClaimantStatusResponse.new(raw_response.status, raw_response)
        end
      rescue => e
        log_error(e, __method__)
        raise e
      end

      # rubocop:disable Metrics/ParameterLists
      def verify_claimant(
        claimant_id,
        verified_period_begin_date,
        verified_period_end_date,
        verified_through_date,
        verification_method,
        response_type
      )
        params = ActionController::Parameters.new({
                                                    claimant_id:,
                                                    verified_period_begin_date:,
                                                    verified_period_end_date:,
                                                    verified_through_date:,
                                                    verification_method:,
                                                    app_communication: { response_type: }
                                                  })
        # rubocop:enable Metrics/ParameterLists

        with_monitoring do
          headers = request_headers
          options = { timeout: 60 }
          response = perform(:post, verify_claimant_end_point, camelize_keys_for_java_service(params).to_json, headers,
                             options)
          VerifyClaimantResponse.new(response.status, response)
        end
      rescue => e
        log_error(e, __method__)
        raise e
      end

      def get_verification_record(claimant_id)
        with_monitoring do
          headers = request_headers
          options = { timeout: 60 }
          raw_response = perform(:get, verification_record_end_point(claimant_id), {}, headers, options)
          VerificationRecordResponse.new(raw_response.status, raw_response)
        end
      rescue => e
        log_error(e, __method__)
        raise e
      end

      private

      def claimant_lookup_end_point
        'dgi/vye/claimantLookup'
      end

      def claimant_status_end_point(claimant_id)
        "verifications/vye/#{claimant_id}/status"
      end

      def verify_claimant_end_point
        'verifications/vye/verify'
      end

      def verification_record_end_point(claimant_id)
        "verifications/vye/#{claimant_id}/verification-record"
      end

      def json
        nil
      end

      def request_headers
        {
          Authorization: "Bearer #{AuthenticationTokenService.call}"
        }
      end

      def log_error(error, method_name)
        error_context = {
          service: 'DGI/VYE',
          method: method_name,
          error_class: error.class.name,
          error_status: error.try(:status),
          timestamp: Time.current.iso8601
        }

        Rails.logger.error('DGI/VYE service error',
                           error_context,
                           backtrace: error.backtrace)
      end

      def track_claimant_id_zero
        StatsD.increment("#{STATSD_KEY_PREFIX}.claimant_lookup_id_zero")
      end
    end
  end
end
