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
        end
      end
    end
  end
end
