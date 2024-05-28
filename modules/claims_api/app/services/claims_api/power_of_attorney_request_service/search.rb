# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Search
      class InvalidQueryError < StandardError
        attr_reader :errors, :params

        def initialize(errors, params)
          @errors = errors
          @params = params
          super()
        end
      end

      class << self
        def perform(params)
          # This ensures that our data is totally valid. If not, it raises. If
          # it is valid, it gives back a query object with defaults filled out
          # that we can then show back to the client as helpful metadata.
          query = Query.compile!(params)
          total_count, data = PowerOfAttorneyRequest.search(query)

          {
            metadata: {
              totalCount: total_count,
              query:
            },
            data:
          }
        end
      end
    end
  end
end
