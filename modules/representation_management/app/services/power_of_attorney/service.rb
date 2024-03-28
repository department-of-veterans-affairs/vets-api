# frozen_string_literal: true

require 'common/client/base'
require 'common/client/errors'
require 'common/exceptions/backend_service_exception'

module RepresentationManagement
  module PowerOfAttorney
    # The class file that we're inheriting from - lib/common/client/base.rb
    class Service < Common::Client::Base
      SETTINGS = Settings.representation_management.power_of_attorney
      BASE_PATH = "https://#{SETTINGS.hostname}/services/claims/v2/veterans".freeze

      def self.breakers_service
        Common::Client::Base.breakers_service
      end

      def initialize(user)
        @user = user
        super
      end

      def get
        begin
          response = perform(
            method,
            path,
            params,
            headers
          )
        rescue => e
          handle_error(e)
        end

        response.body
      end

      private

      def method
        :get
      end

      def path(icn = @user.icn)
        "#{BASE_PATH}/#{icn}/power_of_attorney/"
      end

      def params
        {}
      end

      def headers
        {
          'Content-Type' => 'application/json',
          'apiKey' => SETTINGS.api_key
        }
      end

      def handle_error(e)
        log_error(e)

        raise e unless e.is_a?(Common::Client::Errors::ClientError)

        raise_invalid_body(e, self.class) unless e.body.is_a?(Hash)

        raise Common::Exceptions::BackendServiceException.new(
          'REPRESENTATION_MANAGEMENT_POA_ERROR',
          detail: e.body
        )
      end

      def raise_invalid_body(e, source)
        raise Common::Exceptions::BackendServiceException.new(
          'REPRESENTATION_MANAGEMENT_POA_502',
          { source: source.to_s },
          502,
          e&.body
        )
      end

      def log_error(e)
        Sentry.set_extras(
          message: e.message,
          url: path('user_icn_goes_here'),
          body: e.body
        )

        Sentry.set_tags(representation_management: 'general_client_error')
      end
    end
  end
end
