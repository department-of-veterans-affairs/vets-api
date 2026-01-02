# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Serializers
        module TrackedItemsSerializer
          def self.serialize(tracked_items)
            tracked_items.map { |item| serialize_item(item) }
          end

          def self.serialize_item(item)
            core_fields(item).merge(friendly_fields(item))
          end

          def self.core_fields(item)
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
              'activityDescription' => item.activity_description,
              'shortDescription' => item.short_description,
              'canUploadFile' => item.can_upload_file,
              'supportAliases' => item.support_aliases,
              'documents' => item.documents,
              'date' => item.date
            }
          end

          def self.friendly_fields(item)
            {
              'friendlyName' => item.friendly_name,
              'friendlyDescription' => item.friendly_description
            }
          end
        end
      end
    end
  end
end
