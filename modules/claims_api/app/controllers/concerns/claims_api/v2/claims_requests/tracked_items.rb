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

        def build_tracked_item(tracked_item, status, item, wwsnfy: false)
          uploads_allowed = uploads_allowed?(status)
          {
            closed_date: date_present(tracked_item[:accept_dt]),
            description: item[:items],
            display_name: tracked_item[:short_nm],
            overdue: overdue?(tracked_item, wwsnfy),
            received_date: date_present(tracked_item[:receive_dt]),
            requested_date: tracked_item_req_date(tracked_item, item),
            status:,
            suspense_date: date_present(tracked_item[:suspns_dt]),
            id: tracked_item[:dvlpmt_item_id].to_i,
            uploads_allowed:
          }
        end
      end
    end
  end
end
