# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Serializers
        module TrackedItemsSerializer
          # rubocop:disable Metrics/MethodLength
          def self.serialize(tracked_items)
            tracked_items.map do |item|
              {
                'id' => item.id,
                'displayName' => item.display_name,
                'status' => item.status,
                'suspenseDate' => item.suspense_date,
                'type' => item.type,
                'closedDate' => item.closed_date,
                'description' => item.description,
                'overdue' => item.overdue,
                'receivedDate' => item.received_date,
                'requestedDate' => item.requested_date,
                'uploadsAllowed' => item.uploads_allowed,
                'uploaded' => item.uploaded,
                'friendlyName' => item.friendly_name,
                'friendlyDescription' => item.friendly_description,
                'canUploadFile' => item.can_upload_file,
                'supportAliases' => item.support_aliases,
                'documents' => item.documents,
                'date' => item.date
              }.compact
            end
          end
          # rubocop:enable Metrics/MethodLength
        end
      end
    end
  end
end