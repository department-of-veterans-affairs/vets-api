# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Builders
        module TrackedItemsBuilder
          # rubocop:disable Metrics/MethodLength
          def self.build(tracked_items_data)
            return nil if tracked_items_data.nil?
            return [] if tracked_items_data.empty?

            tracked_items_data.map do |item_data|
              BenefitsClaims::Responses::TrackedItem.new(
                id: item_data['id'],
                display_name: item_data['displayName'],
                status: item_data['status'],
                suspense_date: item_data['suspenseDate'],
                type: item_data['type'],
                closed_date: item_data['closedDate'],
                description: item_data['description'],
                overdue: item_data['overdue'],
                received_date: item_data['receivedDate'],
                requested_date: item_data['requestedDate'],
                uploads_allowed: item_data['uploadsAllowed'],
                uploaded: item_data['uploaded'],
                friendly_name: item_data['friendlyName'],
                friendly_description: item_data['friendlyDescription'],
                can_upload_file: item_data['canUploadFile'],
                support_aliases: item_data['supportAliases'],
                documents: item_data['documents'],
                date: item_data['date']
              )
            end
          end
          # rubocop:enable Metrics/MethodLength
        end
      end
    end
  end
end
