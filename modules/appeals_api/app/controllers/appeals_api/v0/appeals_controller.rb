# frozen_string_literal: true

require 'caseflow/service'
require 'common/exceptions'

module AppealsApi
  module V0
    class AppealsController < ApplicationController
      include AppealsApi::GatewayOriginCheck

      skip_before_action(:authenticate)

      def index
        appeals_response = Caseflow::Service.new.get_appeals(
          target_veteran,
          'Consumer' => consumer,
          'VA-User' => requesting_va_user
        )
        render(json: appeals_response.body)
      end

      private

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
