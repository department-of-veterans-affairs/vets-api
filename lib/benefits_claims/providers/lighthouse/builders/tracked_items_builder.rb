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
                # Core fields from Lighthouse API
                id: item_data['id'],
                display_name: item_data['displayName'],
                status: item_data['status'],
                suspense_date: item_data['suspenseDate'],
                type: item_data['type'],
                # Friendly language fields added by service transformation
                can_upload_file: item_data['canUploadFile'],
                friendly_name: item_data['friendlyName'],
                activity_description: item_data['activityDescription'],
                short_description: item_data['shortDescription'],
                support_aliases: item_data['supportAliases']
              )
            end
          end
        end
      end
    end
  end
end
