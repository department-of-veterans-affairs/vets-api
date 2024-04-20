# frozen_string_literal: true

require 'bgs_service/manage_representative_service'

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Search
      class << self
        def perform
          response =
            ManageRepresentativeService::ReadPoaRequest.call(
              statuses: PoaRequest::Statuses::ALL,
              poa_codes: ['012']
            )

          # `Array.wrap` (the `ActiveSupport` core extension with nicer behavior
          # than Ruby core) because upstream invocation of `Hash.from_xml` has
          # different output depending on the cardinality of sibling XML
          # elements for a given kind:
          #    0 => Absent
          #    1 => Object
          #   >1 => Array
          poa_requests = response['poaRequestRespondReturnVOList']
          Array.wrap(poa_requests).map { |data| PoaRequest.new(data) }
        end
      end
    end
  end
end
