# frozen_string_literal: true

module BenefitsClaims
  module Utilities
    module Helpers
      def self.get_tracked_item_display_name(evidence_submission_tracked_item_id, tracked_items)
        return nil if tracked_items.nil?

        tracked_items.each do |item|
          return item['displayName'] if item['id'] == evidence_submission_tracked_item_id
        end

        nil
      end
    end
  end
end
