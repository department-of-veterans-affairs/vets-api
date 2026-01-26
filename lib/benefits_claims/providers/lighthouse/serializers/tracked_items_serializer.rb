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
            core_fields(item)
              .merge(date_fields(item))
              .merge(upload_fields(item))
              .merge(display_fields(item))
          end

          def self.core_fields(item)
            {
              'id' => item.id,
              'displayName' => item.display_name,
              'status' => item.status,
              'type' => item.type,
              'description' => item.description,
              'overdue' => item.overdue
            }
          end

          def self.date_fields(item)
            {
              'suspenseDate' => item.suspense_date,
              'closedDate' => item.closed_date,
              'receivedDate' => item.received_date,
              'requestedDate' => item.requested_date,
              'date' => item.date
            }
          end

          def self.upload_fields(item)
            {
              'uploadsAllowed' => item.uploads_allowed,
              'uploaded' => item.uploaded,
              'canUploadFile' => item.can_upload_file,
              'documents' => item.documents
            }
          end

          def self.display_fields(item)
            {
              'friendlyName' => item.friendly_name,
              'friendlyDescription' => item.friendly_description,
              'activityDescription' => item.activity_description,
              'shortDescription' => item.short_description,
              'supportAliases' => item.support_aliases
            }
          end
        end
      end
    end
  end
end
