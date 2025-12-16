# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Serializers
        module TrackedItemsSerializer
          def self.serialize(tracked_items)
            tracked_items.map do |item|
              {
                # Core fields
                'id' => item.id,
                'displayName' => item.display_name,
                'status' => item.status,
                'suspenseDate' => item.suspense_date,
                'type' => item.type,
                # Friendly language fields
                'canUploadFile' => item.can_upload_file,
                'friendlyName' => item.friendly_name,
                'activityDescription' => item.activity_description,
                'shortDescription' => item.short_description,
                'supportAliases' => item.support_aliases
              }.compact
            end
          end
        end
      end
    end
  end
end
