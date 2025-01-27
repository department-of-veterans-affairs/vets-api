# frozen_string_literal: true

require 'bgs_service/tracked_item_service'
module ClaimsApi
  module V2
    module ClaimsRequests
      module TrackedItems
        extend ActiveSupport::Concern

        def find_tracked_items!(claim_id)
          return if claim_id.blank?

          @tracked_items = tracked_item_service.find_tracked_items(claim_id)[:dvlpmt_items] || []
        end

        def find_tracked_item(id)
          [@tracked_items].flatten.compact.find { |item| item[:dvlpmt_item_id] == id }
        end

        def build_wwsnfy_items
          # wwsnfy What We Still Need From You
          wwsnfy = [@ebenefits_details[:wwsnfy]].flatten.compact
          return [] if wwsnfy.empty?

          wwsnfy.map do |item|
            status = map_status(item[:dvlpmt_item_id], 'NEEDED_FROM_YOU')

            build_tracked_item(find_tracked_item(item[:dvlpmt_item_id]), status, item, wwsnfy: true)
          end
        end

        def build_wwd_items
          # wwd What We Still Need From Others
          wwd = [@ebenefits_details[:wwd]].flatten.compact
          return [] if wwd.empty?

          wwd.map do |item|
            status = map_status(item[:dvlpmt_item_id], 'NEEDED_FROM_OTHERS')

            build_tracked_item(find_tracked_item(item[:dvlpmt_item_id]), status, item)
          end
        end

        def build_wwr_items
          # wwr What We Received From You and Others
          wwr = [@ebenefits_details[:wwr]].flatten.compact
          return [] if wwr.empty?

          claim_status_type = [@ebenefits_details[:bnft_claim_lc_status]].flatten.first[:phase_type]

          wwr.map do |item|
            status = accepted?(claim_status_type) ? 'ACCEPTED' : 'INITIAL_REVIEW_COMPLETE'

            build_tracked_item(find_tracked_item(item[:dvlpmt_item_id]), status, item)
          end
        end

        def build_no_longer_needed_items
          no_longer_needed = [@tracked_items].flatten.compact.select do |item|
            item[:accept_dt].present? && item[:dvlpmt_tc] == 'CLMNTRQST'
          end
          return [] if no_longer_needed.empty?

          no_longer_needed.map do |tracked_item|
            status = 'NO_LONGER_REQUIRED'

            build_tracked_item(tracked_item, status, {})
          end
        end

        def map_bgs_tracked_items(bgs_claim)
          return [] if bgs_claim.nil?

          claim_id = bgs_claim.dig(:benefit_claim_details_dto, :benefit_claim_id)
          return [] if claim_id.nil?

          @tracked_items = find_tracked_items!(claim_id)

          return [] if @tracked_items.blank?

          @ebenefits_details = bgs_claim[:benefit_claim_details_dto]

          (build_wwsnfy_items | build_wwd_items | build_wwr_items | build_no_longer_needed_items)
            .sort_by do |list_item|
            list_item[:id]
          end
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

        private

        def tracked_item_service
          @tracked_item_service ||= ClaimsApi::TrackedItemService.new(
            external_uid: target_veteran.participant_id,
            external_key: target_veteran.participant_id
          )
        end
      end
    end
  end
end
