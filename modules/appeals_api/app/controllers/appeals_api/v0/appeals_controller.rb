# frozen_string_literal: true

require 'caseflow/service'
require 'decision_review/service'
require 'common/exceptions'

module AppealsApi
  module V0
    class AppealsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        log_request
        appeals_response = Caseflow::Service.new.get_appeals(
          target_veteran,
          'Consumer' => consumer,
          'VA-User' => requesting_va_user
        )
        log_response(appeals_response)
        render(
          json: appeals_response.body
        )
      end

      private

      def log_request
        hashed_ssn = Digest::SHA2.hexdigest ssn
        Rails.logger.info('Caseflow Request',
                          'va_user' => requesting_va_user,
                          'lookup_identifier' => hashed_ssn)
      end

      def log_response(appeals_response)
        first_appeal_id = appeals_response.body.dig('data', 0, 'id')
        count = appeals_response.body['data'].length
        Rails.logger.info('Caseflow Response',
                          'va_user' => requesting_va_user,
                          'first_appeal_id' => first_appeal_id,
                          'appeal_count' => count)
      end

      def consumer
        request.headers['X-Consumer-Username']
      end

      def ssn
        header('X-VA-SSN')
      end

      def requesting_va_user
        header('X-VA-User')
      end

      def header(key)
        value = request.headers[key]
        raise Common::Exceptions::ParameterMissing, key if value.blank?

        value
      end

      def target_veteran
        OpenStruct.new(ssn:)
      end
    end
  end
end
