# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Search
      class << self
        def perform
          # `Array.wrap` (the `ActiveSupport` core extension with nicer behavior
          # than Ruby core) because upstream invocation of `Hash.from_xml` has
          # different output depending on the cardinality of sibling XML
          # elements for a given kind:
          #    0 => Absent
          #    1 => Object
          #   >1 => Array
          poa_requests = make_request['poaRequestRespondReturnVOList']
          Array.wrap(poa_requests).map { |data| PoaRequest.new(data) }
        end

        private

        def make_request
          bgs_client =
            ClaimsApi::ManageRepresentativeService.new(
              external_uid: 'xUid',
              external_key: 'xKey'
            )

          bgs_client.read_poa_request(
            poa_codes: ['012'],
            statuses: %w[
              new
              pending
              accepted
              declined
            ]
          )
        end
      end
    end
  end
end
