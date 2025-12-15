# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Builders
        module TrackedItemsBuilder
          def self.build(tracked_items_data)
            return nil if tracked_items_data.nil?
            return [] if tracked_items_data.empty?

            tracked_items_data.map do |item_data|
              BenefitsClaims::Responses::TrackedItem.new(
                id: item_data['id'],
                display_name: item_data['displayName'],
                status: item_data['status'],
                suspense_date: item_data['suspenseDate'],
                type: item_data['type']
              )
            end
          end
        end
      end
    end
  end
end
