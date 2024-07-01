# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Search
      class << self
        def perform(params)
          # This ensures that our data is totally valid. If not, it raises. If
          # it is valid, it gives back a query object with defaults filled out
          # that we can then show back to the client as helpful metadata.
          query = Query.compile!(params)
          total_count, data = PowerOfAttorneyRequest::Summary.search(query)

          {
            metadata: {
              total_count:,
              query:
            },
            data:
          }
        end
      end
    end
  end
end
