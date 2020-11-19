# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class ClaimsOverviewErrors
        def parse(error, failed_service)
          {
              service: failed_service,
              errors: defined?(error.details) ? error.details : error.errors.to_json
          }
        end
      end
    end
  end
end
