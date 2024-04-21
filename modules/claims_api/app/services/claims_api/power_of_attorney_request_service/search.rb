# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Search
      class << self
        def perform(**)
          query = Query.build!(**)
          poa_requests = make_request(query)
          poa_requests.map do |data|
            PoaRequest.load(data)
          end
        end

        private

        def make_request(body)
          response =
            LocalBGS.new.make_request(
              endpoint: 'VDC/ManageRepresentativeService',
              namespaces: { 'data' => '/data' },
              action: 'readPOARequest',
              error_handler: ErrorHandler,
              transform_response: false,
              body:,
            )

          # `Array.wrap` to normalize around variable XML sibling cardinality.
          Array.wrap(response.dig(
            'POARequestRespondReturnVO',
            'poaRequestRespondReturnVOList'
          ))
        rescue ErrorHandler::NoRecordFoundError
          []
        end

        module ErrorHandler
          # Nested this constant to indicate that it is just an implementation
          # detail rather than a genuine error that callers interact with.
          NoRecordFoundError = Class.new(RuntimeError)

          class << self
            def handle_errors!(fault)
              # What fault data is the best indicator for this?
              if 'No Record Found'.in?(fault.string)
                raise NoRecordFoundError
              end

              SoapErrorHandler.handle_errors!(
                fault
              )
            end
          end
        end
      end
    end
  end
end
