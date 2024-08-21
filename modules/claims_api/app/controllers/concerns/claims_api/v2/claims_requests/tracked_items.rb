# frozen_string_literal: true

module ClaimsApi
  module V2
    module ClaimsRequests
      module TrackedItems
        extend ActiveSupport::Concern

        def find_tracked_items!(claim_id)
          return if claim_id.blank?

          @tracked_items ||= local_bgs_service.find_tracked_items(claim_id)[:dvlpmt_items] || []
        end

        def find_tracked_item(id)
          [@tracked_items].flatten.compact.find { |item| item[:dvlpmt_item_id] == id }
        end
      end
    end
  end
end
