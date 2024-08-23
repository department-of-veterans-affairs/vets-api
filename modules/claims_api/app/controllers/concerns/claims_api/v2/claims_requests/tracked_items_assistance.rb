# frozen_string_literal: true

module ClaimsApi
  module V2
    module ClaimsRequests
      module TrackedItemsAssistance
        extend ActiveSupport::Concern

        def format_bgs_date(phase_change_date)
          parsed_date = Date.parse(phase_change_date.to_s)
          parsed_date.strftime('%Y-%m-%d')
        end

        ### called from inside of format_bgs_phase_date & format_bgs_phase_chng_dates
        ### calls format_bgs_date
        def date_present(date)
          return unless date.is_a?(Date) || date.is_a?(String)

          date.present? ? format_bgs_date(date) : nil
        end

        def overdue?(tracked_item, wwsnfy)
          if tracked_item[:suspns_dt].present? && tracked_item[:accept_dt].nil? && wwsnfy
            return tracked_item[:suspns_dt] < Time.zone.now
          end

          false
        end

        def tracked_item_req_date(tracked_item, item)
          date_present(item[:date_open] || tracked_item[:req_dt] || tracked_item[:create_dt])
        end

        def accepted?(status)
          ['Preparation for Decision', 'Pending Decision Approval', 'Preparation for Notification',
           'Complete'].include? status
        end

        def uploads_allowed?(status)
          %w[NEEDED_FROM_YOU NEEDED_FROM_OTHERS SUBMITTED_AWAITING_REVIEW INITIAL_REVIEW_COMPLETE].include? status
        end
      end
    end
  end
end
