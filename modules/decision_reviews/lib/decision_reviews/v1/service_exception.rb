# frozen_string_literal: true

require 'common/exceptions/backend_service_exception'

module DecisionReviews
  module V1
    # Custom exception that maps Decision Review errors to error details defined in config/locales/exceptions.en.yml
    #
    class ServiceException < Common::Exceptions::BackendServiceException
      include SentryLogging

      UNMAPPED_KEY = 'unmapped_service_exception'

      def initialize(key: UNMAPPED_KEY, response_values: {}, original_status: nil, original_body: nil)
        super(key, response_values, original_status, original_body)
      end

      private

      def code
        if @key.present? && I18n.exists?("decision_review.exceptions.#{@key}")
          @key
        else
          UNMAPPED_KEY
        end
      end

      def i18n_key
        "decision_review.exceptions.#{code}"
      end
    end
  end
end
