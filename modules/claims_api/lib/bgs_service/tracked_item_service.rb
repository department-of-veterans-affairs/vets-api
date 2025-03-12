# frozen_string_literal: true

module ClaimsApi
  class TrackedItemService < ClaimsApi::LocalBGS
    def bean_name
      'TrackedItemService/TrackedItemService'
    end

    def find_tracked_items(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <claimId>#{id}</claimId>
      EOXML

      make_request(endpoint: 'TrackedItemService/TrackedItemService', action: 'findTrackedItems', body:,
                   key: 'BenefitClaim')
    end
  end
end
