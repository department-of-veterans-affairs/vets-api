# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class ClaimsOverviewErrors
        def parse(error, failed_service)
          {
            service: failed_service,
            error_details: error_details(error)
          }
        end

        private

        def error_details(error)
          if error.respond_to?(:details)
            error.details.pluck('text').join('; ')
          elsif error.respond_to?(:errors)
            error.errors.as_json.pluck('detail').join('; ')
          else
            error.message
          end
        rescue => e
          # remove rescue once it's confirmed that plucking does not cause errors
          Rails.logger.error('Claims overview error detail parsing error', syntax_error: e, error_body: error)
          'Unknown Error'
        end
      end
    end
  end
end
