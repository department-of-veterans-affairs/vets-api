# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Serializers
        module TrackedItemsSerializer
          def self.serialize(tracked_items)
            tracked_items.map do |item|
              {
                'id' => item.id,
                'displayName' => item.display_name,
                'status' => item.status,
                'suspenseDate' => item.suspense_date,
                'type' => item.type
              }.compact
            end
          end
        end
      end
    end
  end
end
