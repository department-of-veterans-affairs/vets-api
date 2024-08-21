# frozen_string_literal: true

module ClaimsApi
  module V2
    module ClaimsRequests
      module TrackedItems
        extend ActiveSupport::Concern

        def find_tracked_items!(claim_id)
          return if claim_id.blank?

          local_bgs_service.find_tracked_items(claim_id)[:dvlpmt_items] || []
        end
      end
    end
  end
end
